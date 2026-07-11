import { Image } from "https://deno.land/x/imagescript@1.3.0/mod.ts";
import { CACHE_REFRESH_BUFFER_SECONDS } from "../_shared/photo-cache.ts";

// imagescript(Image.decode)がPNG・JPEG・TIFFのみ対応でWebPをデコードできない
// ため、対応形式からimage/webpを外している(issue #202参照。カメラ撮影画面
// (S06)はJPEGのみ送信するため実運用上の影響はない)。
const SUPPORTED_IMAGE_TYPES: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
};

export type PhotoVariant = "original" | "blurred";

// 原本のCDN TTLはget-photo-urlのCACHE_REFRESH_BUFFER_SECONDSと同じ値にする(issue #166参照)。
// 署名付きURLはこのバッファ秒数を切ると再発行されるため、TTLをこれと揃えておけば
// CDNキャッシュが署名の実効期限を超えて原本レスポンスを生かし続けることはない。
const ORIGINAL_CACHE_CONTROL_SECONDS = String(CACHE_REFRESH_BUFFER_SECONDS);
const BLURRED_CACHE_CONTROL_SECONDS = "31536000";

export function isSupportedImageType(contentType: string): boolean {
  return contentType in SUPPORTED_IMAGE_TYPES;
}

export function extensionForImageType(contentType: string): string {
  return SUPPORTED_IMAGE_TYPES[contentType] ?? "jpg";
}

export function buildStoragePath(
  groupId: string,
  takenDate: string,
  photoId: string,
  ext: string,
): string {
  return `${groupId}/${takenDate}/${photoId}.${ext}`;
}

export function cacheControlForPhotoVariant(variant: PhotoVariant): string {
  if (variant === "original") {
    return ORIGINAL_CACHE_CONTROL_SECONDS;
  }
  return BLURRED_CACHE_CONTROL_SECONDS;
}

export interface PhotoInsertErrorMapping {
  status: number;
  error: string;
}

// photos への INSERT が失敗した際、Postgresのエラーコードから返すべきHTTPレスポンスを判定する。
// - 23503 (foreign_key_violation): group_id が存在しない
// - P0001 (raise_exception): trg_check_photo_daily_limit による上限超過(仕様書 5.2.2参照)
export function mapPhotoInsertError(code: string | undefined): PhotoInsertErrorMapping {
  if (code === "23503") {
    return { status: 400, error: "invalid_group_id" };
  }
  if (code === "P0001") {
    return { status: 409, error: "daily_limit_reached" };
  }
  return { status: 500, error: "unknown" };
}

// 単純なボックスブラー。ボヤけ版生成の最終ステップとして、原本を復元
// 不可能な程度まで細部を潰す(仕様書 8.1参照)。imagescriptにはブラー機能が
// ないため、resize後の極小画像(BLURRED_WIDTH参照)に対して自前で実装する。
// 画像が小さいため、O(width*height*radius^2)の素朴な実装でも十分高速。
export function boxBlur(image: Image, radius: number): Image {
  const { width, height } = image;
  const source = image.clone();
  const blurred = new Image(width, height);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      let r = 0;
      let g = 0;
      let b = 0;
      let a = 0;
      let count = 0;
      for (let dy = -radius; dy <= radius; dy++) {
        const sy = y + dy;
        if (sy < 0 || sy >= height) continue;
        for (let dx = -radius; dx <= radius; dx++) {
          const sx = x + dx;
          if (sx < 0 || sx >= width) continue;
          const [pr, pg, pb, pa] = Image.colorToRGBA(
            source.getPixelAt(sx + 1, sy + 1),
          );
          r += pr;
          g += pg;
          b += pb;
          a += pa;
          count++;
        }
      }
      blurred.setPixelAt(
        x + 1,
        y + 1,
        Image.rgbaToColor(
          Math.round(r / count),
          Math.round(g / count),
          Math.round(b / count),
          Math.round(a / count),
        ),
      );
    }
  }
  return blurred;
}

// taken_at を日本時間(Asia/Tokyo)に変換した日付(YYYY-MM-DD)を求める。
// trg_check_photo_daily_limit(DB側)と同じ変換ルールで、Storageパス採番に使う(仕様書 5.2.1参照)。
export function takenDateInAsiaTokyo(takenAt: string): string {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  return formatter.format(new Date(takenAt));
}
