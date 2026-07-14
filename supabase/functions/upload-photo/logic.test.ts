import { assertEquals } from "jsr:@std/assert@1";
import { Image } from "https://deno.land/x/imagescript@1.2.17/mod.ts";
import {
  buildStoragePath,
  cacheControlForPhotoVariant,
  createBlurredJpeg,
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

Deno.test("createBlurredJpeg resizes to the given width and returns a decodable JPEG", async () => {
  const source = new Image(64, 64);
  source.fill(0xff0000ff);
  const originalBytes = await source.encodeJPEG(90);

  const blurredBytes = await createBlurredJpeg(originalBytes, 32, 12, 60);

  const decoded = await Image.decode(blurredBytes);
  assertEquals(decoded.width, 32);
  assertEquals(decoded.height, 32);
});

Deno.test("createBlurredJpeg blends a hard black/white edge so it can't be reconstructed", async () => {
  const source = new Image(64, 64);
  for (let y = 0; y < 64; y++) {
    for (let x = 0; x < 64; x++) {
      source.setPixelAt(x + 1, y + 1, x < 32 ? 0x000000ff : 0xffffffff);
    }
  }
  const originalBytes = await source.encodeJPEG(90);

  const blurredBytes = await createBlurredJpeg(originalBytes, 32, 12, 60);

  const decoded = await Image.decode(blurredBytes);
  const boundaryPixel = decoded.getPixelAt(16, 16);
  const r = (boundaryPixel >> 24) & 0xff;
  // 境界のピクセルは純粋な黒(0x00)にも白(0xff)にもならず、周囲と混ざっているはず
  assertEquals(r > 0x10 && r < 0xf0, true);
});
