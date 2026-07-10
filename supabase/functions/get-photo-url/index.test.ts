import { assertEquals } from "jsr:@std/assert@1";
import { assertSpyCallArg, assertSpyCalls, stub } from "jsr:@std/testing@1/mock";
import { getPhotoUrl } from "./index.ts";

Deno.test("getPhotoUrl logs cache read errors and still issues a signed URL", async () => {
  const cacheReadError = new Error("cache read failed");
  const consoleErrorStub = stub(console, "error", () => {});
  try {
    const callerClient = {
      auth: {
        getUser: () => Promise.resolve({ data: { user: { id: "user-1" } }, error: null }),
      },
      from: (table: string) => {
        assertEquals(table, "photos");
        return {
          select: () => ({
            eq: () => ({
              single: () =>
                Promise.resolve({
                  data: {
                    status: "pending_vote",
                    original_storage_path: "original/path.jpg",
                    blurred_storage_path: "blurred/path.jpg",
                  },
                  error: null,
                }),
            }),
          }),
        };
      },
    };

    const adminClient = {
      from: (table: string) => {
        assertEquals(table, "signed_url_cache");
        return {
          select: () => ({
            eq: () => ({
              eq: () => ({
                maybeSingle: () => Promise.resolve({ data: null, error: cacheReadError }),
              }),
            }),
          }),
          upsert: () => Promise.resolve({ error: null }),
        };
      },
      storage: {
        from: (bucket: string) => {
          assertEquals(bucket, "photo-blurred");
          return {
            createSignedUrl: (path: string, expiresIn: number) => {
              assertEquals(path, "blurred/path.jpg");
              assertEquals(expiresIn, 300);
              return Promise.resolve({
                data: { signedUrl: "https://example.test/signed" },
                error: null,
              });
            },
          };
        },
      },
    };

    const result = await getPhotoUrl(
      callerClient as never,
      adminClient as never,
      "00000000-0000-0000-0000-000000000001",
      new Date("2026-07-11T00:00:00.000Z"),
    );

    assertEquals(result, {
      status: 200,
      body: { url: "https://example.test/signed", expires_in: 300 },
    });
    assertSpyCalls(consoleErrorStub, 1);
    assertSpyCallArg(consoleErrorStub, 0, 0, "[get-photo-url] signed_url_cache read failed:");
    assertSpyCallArg(consoleErrorStub, 0, 1, cacheReadError);
  } finally {
    consoleErrorStub.restore();
  }
});
