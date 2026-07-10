const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token";

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64UrlEncodeString(value: string): string {
  return base64UrlEncode(new TextEncoder().encode(value));
}

function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemBody = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const binary = atob(pemBody);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return crypto.subtle.importKey(
    "pkcs8",
    bytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function signJwt(clientEmail: string, privateKeyPem: string): Promise<string> {
  const nowSeconds = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: clientEmail,
    scope: FCM_SCOPE,
    aud: TOKEN_ENDPOINT,
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  };

  const unsignedToken = `${base64UrlEncodeString(JSON.stringify(header))}.${
    base64UrlEncodeString(JSON.stringify(claims))
  }`;

  const key = await importPrivateKey(privateKeyPem);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsignedToken),
  );

  return `${unsignedToken}.${base64UrlEncode(new Uint8Array(signature))}`;
}

/** サービスアカウントJSONからRS256 JWTを自前で署名し、FCM送信用のOAuth2アクセストークンに交換する。 */
export async function getFcmAccessToken(serviceAccountJson: string): Promise<string> {
  const serviceAccount: { client_email: string; private_key: string } = JSON.parse(
    serviceAccountJson,
  );
  const jwt = await signJwt(serviceAccount.client_email, serviceAccount.private_key);

  const response = await fetch(TOKEN_ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!response.ok) {
    throw new Error(`FCMアクセストークンの取得に失敗しました: ${response.status}`);
  }

  const body: { access_token: string } = await response.json();
  return body.access_token;
}

export interface FcmNotification {
  title: string;
  body: string;
  imageUrl?: string;
}

export interface FcmSendResult {
  ok: boolean;
  error?: string;
}

/** FCM HTTP v1 APIで1トークン宛に通知を送信する。送信失敗は例外を投げず結果として返す。 */
export async function sendFcmMessage(
  accessToken: string,
  projectId: string,
  token: string,
  notification: FcmNotification,
): Promise<FcmSendResult> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title: notification.title,
            body: notification.body,
            ...(notification.imageUrl ? { image: notification.imageUrl } : {}),
          },
        },
      }),
    },
  );

  if (response.ok) {
    return { ok: true };
  }

  const errorBody: { error?: { status?: string; message?: string } } = await response.json().catch(
    () => ({}),
  );
  return {
    ok: false,
    error: `${errorBody.error?.status ?? response.status}: ${
      errorBody.error?.message ?? "unknown error"
    }`,
  };
}
