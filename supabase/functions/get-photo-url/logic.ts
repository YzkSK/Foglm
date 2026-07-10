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
