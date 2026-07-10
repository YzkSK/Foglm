// 署名付きURLキャッシュ(get-photo-url)と原本Storageオブジェクトのcacheキャッシュ(upload-photo)は
// この秒数で足並みを揃える。ズレるとCDNが署名の実効期限を超えて原本レスポンスを
// キャッシュし続け、無効化されたはずの署名URLからも原本が返ってしまう恐れがある(issue #166参照)。
export const CACHE_REFRESH_BUFFER_SECONDS = 30;
