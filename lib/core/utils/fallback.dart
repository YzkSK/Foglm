/// [primary]を実行し、失敗した場合のみ[fallback]を試す。
/// [primary]の失敗は[onPrimaryError]経由で通知されるため、握り潰されない。
/// [fallback]も失敗した場合は、その例外がそのまま呼び出し元に伝播する。
Future<T> tryWithFallback<T>({
  required Future<T> Function() primary,
  required Future<T> Function() fallback,
  required void Function(Object error, StackTrace stackTrace) onPrimaryError,
}) async {
  try {
    return await primary();
  } on Object catch (error, stackTrace) {
    onPrimaryError(error, stackTrace);
    return fallback();
  }
}
