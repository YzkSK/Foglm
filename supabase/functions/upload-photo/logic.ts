import { Image } from "https://deno.land/x/imagescript@1.2.17/mod.ts";
import { CACHE_REFRESH_BUFFER_SECONDS } from "../_shared/photo-cache.ts";

const SUPPORTED_IMAGE_TYPES: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
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

// 単純なボックスブラー(水平・垂直の2パス)。imagescriptにblur APIが無いため自前実装する。
function applyBoxBlur(
  bitmap: Uint8ClampedArray,
  width: number,
  height: number,
  radius: number,
): void {
  const channels = 4;
  const temp = new Uint8ClampedArray(bitmap.length);

  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      for (let c = 0; c < channels; c++) {
        let sum = 0;
        let count = 0;
        for (let dx = -radius; dx <= radius; dx++) {
          const sx = x + dx;
          if (sx < 0 || sx >= width) continue;
          sum += bitmap[(y * width + sx) * channels + c];
          count++;
        }
        temp[(y * width + x) * channels + c] = sum / count;
      }
    }
  }

  for (let x = 0; x < width; x++) {
    for (let y = 0; y < height; y++) {
      for (let c = 0; c < channels; c++) {
        let sum = 0;
        let count = 0;
        for (let dy = -radius; dy <= radius; dy++) {
          const sy = y + dy;
          if (sy < 0 || sy >= height) continue;
          sum += temp[(sy * width + x) * channels + c];
          count++;
        }
        bitmap[(y * width + x) * channels + c] = sum / count;
      }
    }
  }
}

// 原本を復元不可能な程度まで縮小・ぼかしたJPEGを生成する(仕様書 8.1参照)。
// Supabase Edge RuntimeのARM64環境ではネイティブ依存を持つsharpがロードできないため、
// 純粋なTypeScript実装のimagescriptで縮小・エンコードし、ぼかしは自前のボックスブラーで行う。
export async function createBlurredJpeg(
  originalBytes: Uint8Array,
  width: number,
  blurRadius: number,
  quality: number,
): Promise<Uint8Array> {
  const image = await Image.decode(originalBytes);
  image.resize(width, Image.RESIZE_AUTO);
  applyBoxBlur(image.bitmap, image.width, image.height, blurRadius);
  return await image.encodeJPEG(quality);
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
