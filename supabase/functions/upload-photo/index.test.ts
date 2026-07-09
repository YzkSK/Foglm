import { assertEquals } from "jsr:@std/assert@1";
import {
  buildStoragePaths,
  isAllowedPhotoType,
  isDailyLimitError,
  parseUploadForm,
} from "./index.ts";

function photoFile(
  name: string,
  type: string,
  bytes: Uint8Array = new Uint8Array([1, 2, 3]),
): File {
  return new File([bytes], name, { type });
}

Deno.test("isAllowedPhotoType accepts jpeg/png/webp", () => {
  assertEquals(isAllowedPhotoType("image/jpeg"), true);
  assertEquals(isAllowedPhotoType("image/png"), true);
  assertEquals(isAllowedPhotoType("image/webp"), true);
});

Deno.test("isAllowedPhotoType rejects other formats", () => {
  assertEquals(isAllowedPhotoType("image/gif"), false);
  assertEquals(isAllowedPhotoType("application/pdf"), false);
  assertEquals(isAllowedPhotoType(""), false);
});

Deno.test("parseUploadForm accepts a valid group_id + photo", () => {
  const form = new FormData();
  form.set("group_id", "10000000-0000-0000-0000-000000000001");
  form.set("photo", photoFile("photo.jpg", "image/jpeg"));

  const result = parseUploadForm(form);

  assertEquals(result.ok, true);
});

Deno.test("parseUploadForm rejects a missing group_id", () => {
  const form = new FormData();
  form.set("photo", photoFile("photo.jpg", "image/jpeg"));

  const result = parseUploadForm(form);

  assertEquals(result, { ok: false, error: "invalid_group_id" });
});

Deno.test("parseUploadForm rejects an empty group_id", () => {
  const form = new FormData();
  form.set("group_id", "");
  form.set("photo", photoFile("photo.jpg", "image/jpeg"));

  const result = parseUploadForm(form);

  assertEquals(result, { ok: false, error: "invalid_group_id" });
});

Deno.test("parseUploadForm rejects a missing photo", () => {
  const form = new FormData();
  form.set("group_id", "10000000-0000-0000-0000-000000000001");

  const result = parseUploadForm(form);

  assertEquals(result, { ok: false, error: "invalid_photo" });
});

Deno.test("parseUploadForm rejects an empty photo file", () => {
  const form = new FormData();
  form.set("group_id", "10000000-0000-0000-0000-000000000001");
  form.set("photo", photoFile("empty.jpg", "image/jpeg", new Uint8Array()));

  const result = parseUploadForm(form);

  assertEquals(result, { ok: false, error: "invalid_photo" });
});

Deno.test("parseUploadForm rejects an unsupported media type", () => {
  const form = new FormData();
  form.set("group_id", "10000000-0000-0000-0000-000000000001");
  form.set("photo", photoFile("photo.gif", "image/gif"));

  const result = parseUploadForm(form);

  assertEquals(result, { ok: false, error: "unsupported_media_type" });
});

Deno.test("isDailyLimitError matches the check_photo_daily_limit trigger's exception", () => {
  assertEquals(
    isDailyLimitError({
      code: "P0001",
      message:
        "photos: group 10000000-0000-0000-0000-000000000001 already has 10 photos on 2026-07-09 (max 10)",
    }),
    true,
  );
});

Deno.test("isDailyLimitError rejects unrelated errors", () => {
  assertEquals(isDailyLimitError(null), false);
  assertEquals(isDailyLimitError({ code: "23505", message: "duplicate key" }), false);
  assertEquals(isDailyLimitError({ code: "P0001", message: "some other exception" }), false);
});

Deno.test("buildStoragePaths namespaces paths by group and file id", () => {
  const result = buildStoragePaths(
    "10000000-0000-0000-0000-000000000001",
    "20000000-0000-0000-0000-000000000002",
    "png",
  );

  assertEquals(result, {
    originalPath:
      "10000000-0000-0000-0000-000000000001/20000000-0000-0000-0000-000000000002-original.png",
    blurredPath:
      "10000000-0000-0000-0000-000000000001/20000000-0000-0000-0000-000000000002-blurred.jpg",
  });
});
