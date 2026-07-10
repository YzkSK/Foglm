import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import { getFcmAccessToken, sendFcmMessage } from "./fcm.ts";

async function generateServiceAccountJson(clientEmail: string): Promise<string> {
  const keyPair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const pkcs8 = await crypto.subtle.exportKey("pkcs8", keyPair.privateKey);
  const base64 = btoa(String.fromCharCode(...new Uint8Array(pkcs8)));
  const pem = `-----BEGIN PRIVATE KEY-----\n${
    base64.match(/.{1,64}/g)!.join("\n")
  }\n-----END PRIVATE KEY-----\n`;
  return JSON.stringify({ client_email: clientEmail, private_key: pem });
}

Deno.test("getFcmAccessToken exchanges a signed JWT for an access token", async () => {
  const serviceAccountJson = await generateServiceAccountJson(
    "test@example-project.iam.gserviceaccount.com",
  );

  const originalFetch = globalThis.fetch;
  let capturedUrl = "";
  let capturedBody = "";
  globalThis.fetch = ((input: string | URL | Request, init?: RequestInit) => {
    capturedUrl = input.toString();
    capturedBody = init?.body?.toString() ?? "";
    return Promise.resolve(
      new Response(JSON.stringify({ access_token: "test-access-token" }), { status: 200 }),
    );
  }) as typeof fetch;

  try {
    const token = await getFcmAccessToken(serviceAccountJson);

    assertEquals(token, "test-access-token");
    assertEquals(capturedUrl, "https://oauth2.googleapis.com/token");
    assert(
      capturedBody.includes("grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer"),
    );
    assert(capturedBody.includes("assertion="));
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("getFcmAccessToken throws when the token endpoint returns an error", async () => {
  const serviceAccountJson = await generateServiceAccountJson(
    "test@example-project.iam.gserviceaccount.com",
  );

  const originalFetch = globalThis.fetch;
  globalThis.fetch = (() =>
    Promise.resolve(
      new Response(JSON.stringify({ error: "invalid_grant" }), { status: 400 }),
    )) as typeof fetch;

  try {
    await assertRejects(() => getFcmAccessToken(serviceAccountJson));
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("sendFcmMessage posts the notification to the FCM v1 endpoint and reports success", async () => {
  const originalFetch = globalThis.fetch;
  let capturedUrl = "";
  let capturedHeaders: Record<string, string> = {};
  let capturedBody: unknown;
  globalThis.fetch = ((input: string | URL | Request, init?: RequestInit) => {
    capturedUrl = input.toString();
    capturedHeaders = Object.fromEntries(new Headers(init?.headers).entries());
    capturedBody = JSON.parse(init?.body?.toString() ?? "{}");
    return Promise.resolve(
      new Response(JSON.stringify({ name: "projects/p/messages/1" }), { status: 200 }),
    );
  }) as typeof fetch;

  try {
    const result = await sendFcmMessage("test-access-token", "example-project", "device-token", {
      title: "今日の1枚が現像されました",
      body: "アプリを開いて確認しよう",
      imageUrl: "https://example.com/thumb.jpg",
    });

    assertEquals(result, { ok: true });
    assertEquals(
      capturedUrl,
      "https://fcm.googleapis.com/v1/projects/example-project/messages:send",
    );
    assertEquals(capturedHeaders["authorization"], "Bearer test-access-token");
    assertEquals(capturedHeaders["content-type"], "application/json");
    assertEquals(capturedBody, {
      message: {
        token: "device-token",
        notification: {
          title: "今日の1枚が現像されました",
          body: "アプリを開いて確認しよう",
          image: "https://example.com/thumb.jpg",
        },
      },
    });
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("sendFcmMessage reports failure without throwing when FCM rejects the token", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = (() =>
    Promise.resolve(
      new Response(
        JSON.stringify({
          error: { status: "NOT_FOUND", message: "Requested entity was not found." },
        }),
        {
          status: 404,
        },
      ),
    )) as typeof fetch;

  try {
    const result = await sendFcmMessage("test-access-token", "example-project", "stale-token", {
      title: "title",
      body: "body",
    });

    assertEquals(result.ok, false);
    assert(result.error?.includes("NOT_FOUND"));
  } finally {
    globalThis.fetch = originalFetch;
  }
});
