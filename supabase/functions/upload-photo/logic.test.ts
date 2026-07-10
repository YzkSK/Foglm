import { assertEquals } from "jsr:@std/assert@1";
import {
  buildStoragePath,
  cacheControlForPhotoVariant,
  extensionForImageType,
  isSupportedImageType,
  mapPhotoInsertError,
  takenDateInAsiaTokyo,
} from "./logic.ts";

Deno.test("isSupportedImageType accepts jpeg/png/webp", () => {
  assertEquals(isSupportedImageType("image/jpeg"), true);
  assertEquals(isSupportedImageType("image/png"), true);
  assertEquals(isSupportedImageType("image/webp"), true);
});

Deno.test("isSupportedImageType rejects other content types", () => {
  assertEquals(isSupportedImageType("image/gif"), false);
  assertEquals(isSupportedImageType("application/pdf"), false);
  assertEquals(isSupportedImageType(""), false);
});

Deno.test("extensionForImageType maps known types", () => {
  assertEquals(extensionForImageType("image/jpeg"), "jpg");
  assertEquals(extensionForImageType("image/png"), "png");
  assertEquals(extensionForImageType("image/webp"), "webp");
});

Deno.test("buildStoragePath composes group/date/id.ext", () => {
  assertEquals(
    buildStoragePath("g1", "2026-07-10", "p1", "jpg"),
    "g1/2026-07-10/p1.jpg",
  );
});

Deno.test("cacheControlForPhotoVariant gives originals a short CDN TTL", () => {
  assertEquals(cacheControlForPhotoVariant("original"), "30");
});

Deno.test("cacheControlForPhotoVariant gives blurred images an immutable CDN TTL", () => {
  assertEquals(cacheControlForPhotoVariant("blurred"), "31536000");
});

Deno.test("mapPhotoInsertError maps foreign_key_violation to invalid_group_id", () => {
  assertEquals(mapPhotoInsertError("23503"), {
    status: 400,
    error: "invalid_group_id",
  });
});

Deno.test("mapPhotoInsertError maps raise_exception to daily_limit_reached", () => {
  assertEquals(mapPhotoInsertError("P0001"), {
    status: 409,
    error: "daily_limit_reached",
  });
});

Deno.test("mapPhotoInsertError falls back to unknown for other codes", () => {
  assertEquals(mapPhotoInsertError("23505"), { status: 500, error: "unknown" });
  assertEquals(mapPhotoInsertError(undefined), {
    status: 500,
    error: "unknown",
  });
});

Deno.test("takenDateInAsiaTokyo converts UTC midnight to the same JST day", () => {
  // 2026-07-10T00:00:00Z は JST では 2026-07-10T09:00:00 (同日)
  assertEquals(takenDateInAsiaTokyo("2026-07-10T00:00:00Z"), "2026-07-10");
});

Deno.test("takenDateInAsiaTokyo rolls over to the next JST day near midnight UTC", () => {
  // 2026-07-10T15:30:00Z は JST では 2026-07-11T00:30:00 (翌日)
  assertEquals(takenDateInAsiaTokyo("2026-07-10T15:30:00Z"), "2026-07-11");
});
