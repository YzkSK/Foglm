import 'package:supabase_flutter/supabase_flutter.dart';

/// アカウント削除失敗時のアプリ内エラー種別。
sealed class DeleteAccountFailure implements Exception {
  const DeleteAccountFailure();
}

class UnknownDeleteAccountFailure extends DeleteAccountFailure {
  const UnknownDeleteAccountFailure();
}

/// Edge Function `delete-account`が返す`FunctionException`を
/// アプリ内の`DeleteAccountFailure`に変換する。
DeleteAccountFailure mapFunctionExceptionToDeleteAccountFailure(
  FunctionException e,
) {
  return const UnknownDeleteAccountFailure();
}
