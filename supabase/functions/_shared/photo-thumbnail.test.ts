import { assertEquals } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { createPhotoThumbnailUrl } from "./photo-thumbnail.ts";

function fakeSupabaseClient(
  result: { data: { signedUrl: string } | null; error: { message: string } | null },
  capture: { bucket?: string; path?: string; expiresIn?: number },
): SupabaseClient {
  return {
    storage: {
      from: (bucket: string) => {
        capture.bucket = bucket;
        return {
          createSignedUrl: (path: string, expiresIn: number) => {
            capture.path = path;
            capture.expiresIn = expiresIn;
            return Promise.resolve(result);
          },
        };
      },
    },
  } as unknown as SupabaseClient;
}

Deno.test("createPhotoThumbnailUrl issues a signed URL for the photo-originals bucket", async () => {
  const capture: { bucket?: string; path?: string; expiresIn?: number } = {};
  const client = fakeSupabaseClient(
    { data: { signedUrl: "https://storage.example.com/signed" }, error: null },
    capture,
  );

  const url = await createPhotoThumbnailUrl(client, "group-1/photo-1.jpg");

  assertEquals(url, "https://storage.example.com/signed");
  assertEquals(capture.bucket, "photo-originals");
  assertEquals(capture.path, "group-1/photo-1.jpg");
  assertEquals(capture.expiresIn, 3600);
});

Deno.test("createPhotoThumbnailUrl throws when signing fails", async () => {
  const client = fakeSupabaseClient({ data: null, error: { message: "not found" } }, {});

  let threw = false;
  try {
    await createPhotoThumbnailUrl(client, "group-1/missing.jpg");
  } catch {
    threw = true;
  }
  assertEquals(threw, true);
});
