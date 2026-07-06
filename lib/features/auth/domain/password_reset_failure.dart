import 'package:supabase_flutter/supabase_flutter.dart';

/// パスワードリセット失敗時のアプリ内エラー種別。
sealed class PasswordResetFailure implements Exception {
  const PasswordResetFailure();
}

class PasswordResetInvalidEmailFailure extends PasswordResetFailure {
  const PasswordResetInvalidEmailFailure();
}

class PasswordResetWeakPasswordFailure extends PasswordResetFailure {
  const PasswordResetWeakPasswordFailure();
}

class PasswordResetUpdateFailedFailure extends PasswordResetFailure {
  const PasswordResetUpdateFailedFailure();
}

class UnknownPasswordResetFailure extends PasswordResetFailure {
  const UnknownPasswordResetFailure();
}

/// Edge Function `request-password-reset`/`reset-password`が返す
/// `FunctionException`をアプリ内の`PasswordResetFailure`に変換する。
PasswordResetFailure mapFunctionExceptionToPasswordResetFailure(
  FunctionException e,
) {
  final details = e.details;
  final errorCode = details is Map ? details['error'] as String? : null;

  switch (errorCode) {
    case 'invalid_email':
      return const PasswordResetInvalidEmailFailure();
    case 'weak_password':
      return const PasswordResetWeakPasswordFailure();
    case 'update_failed':
      return const PasswordResetUpdateFailedFailure();
    default:
      return const UnknownPasswordResetFailure();
  }
}
