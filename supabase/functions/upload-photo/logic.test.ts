import { assertEquals } from "jsr:@std/assert@1";
import { Image } from "https://deno.land/x/imagescript@1.3.0/mod.ts";
import {
  boxBlur,
  buildStoragePath,
  cacheControlForPhotoVariant,
  extensionForImageType,
  isSupportedImageType,
  mapPhotoInsertError,
  takenDateInAsiaTokyo,
} from "./logic.ts";

Deno.test("isSupportedImageType accepts jpeg/png", () => {
  assertEquals(isSupportedImageType("image/jpeg"), true);
  assertEquals(isSupportedImageType("image/png"), true);
});

Deno.test("isSupportedImageType rejects other content types", () => {
  // imagescript(Image.decode)がWebPをデコードできないため対応形式から
  // 外している(issue #202参照)。
  assertEquals(isSupportedImageType("image/webp"), false);
  assertEquals(isSupportedImageType("image/gif"), false);
  assertEquals(isSupportedImageType("application/pdf"), false);
  assertEquals(isSupportedImageType(""), false);
});

Deno.test("extensionForImageType maps known types", () => {
  assertEquals(extensionForImageType("image/jpeg"), "jpg");
  assertEquals(extensionForImageType("image/png"), "png");
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

Deno.test("boxBlur preserves image dimensions", () => {
  const image = new Image(8, 8);
  image.fill(Image.rgbaToColor(255, 0, 0, 255));

  const blurred = boxBlur(image, 1);

  assertEquals(blurred.width, 8);
  assertEquals(blurred.height, 8);
});

Deno.test("boxBlur leaves a uniform-color image unchanged", () => {
  // 全ピクセルが同色なら、周辺画素の平均を取っても同じ色のままのはず。
  const image = new Image(8, 8);
  image.fill(Image.rgbaToColor(10, 20, 30, 255));

  const blurred = boxBlur(image, 2);
  const [r, g, b, a] = Image.colorToRGBA(blurred.getPixelAt(4, 4));

  assertEquals([r, g, b, a], [10, 20, 30, 255]);
});

Deno.test("boxBlur smooths a sharp color boundary between neighboring pixels", () => {
  // 左半分を黒、右半分を白にした画像をぼかすと、境界付近の画素が
  // 中間色(グレー)になり、原本の鮮明な境界が失われることを確認する。
  const image = new Image(8, 8);
  for (let y = 1; y <= 8; y++) {
    for (let x = 1; x <= 8; x++) {
      const color = x <= 4
        ? Image.rgbaToColor(0, 0, 0, 255)
        : Image.rgbaToColor(255, 255, 255, 255);
      image.setPixelAt(x, y, color);
    }
  }

  const blurred = boxBlur(image, 2);
  const [r, g, b] = Image.colorToRGBA(blurred.getPixelAt(4, 4));

  // 境界の画素(x=4)は元は黒(0)だったが、ぼかし後は白画素の影響で
  // 明るくなっているはず(完全な黒0でも完全な白255でもない中間値)。
  assertEquals(r > 0 && r < 255, true);
  assertEquals(r, g);
  assertEquals(g, b);
});
