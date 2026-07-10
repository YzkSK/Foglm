import { CACHE_REFRESH_BUFFER_SECONDS } from "../_shared/photo-cache.ts";

export type PhotoStorageBucket = "photo-originals" | "photo-blurred";

export interface StorageTarget {
  bucket: PhotoStorageBucket;
  path: string;
}

// 現像済み(developed)の場合のみ原本を返す。それ以外は必ずボヤけ版を返す(仕様書8.1参照)。
export function resolveStorageTarget(
  status: string,
  originalPath: string,
  blurredPath: string,
): StorageTarget {
  if (status === "developed") {
    return { bucket: "photo-originals", path: originalPath };
  }
  return { bucket: "photo-blurred", path: blurredPath };
}

// キャッシュされたURLの残り有効時間がこの秒数以下の場合、クライアントに渡さず再発行する
// (まもなく失効するURLを配ってCDNキャッシュに乗せてしまうのを防ぐ)。
// 値の定義自体は_shared/photo-cache.tsを参照(upload-photoのcacheControlと足並みを揃える必要があるため)。
export { CACHE_REFRESH_BUFFER_SECONDS };

export function remainingSeconds(expiresAt: Date, now: Date): number {
  return Math.max(0, Math.floor((expiresAt.getTime() - now.getTime()) / 1000));
}

export function isCachedUrlUsable(expiresAt: Date, now: Date): boolean {
  return remainingSeconds(expiresAt, now) > CACHE_REFRESH_BUFFER_SECONDS;
}
