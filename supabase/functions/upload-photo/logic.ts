const SUPPORTED_IMAGE_TYPES: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
};

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
