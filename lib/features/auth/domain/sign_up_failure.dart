import 'package:supabase_flutter/supabase_flutter.dart';

/// サインアップ失敗時のアプリ内エラー種別(仕様書 6.1 sign_up_with_email参照)。
sealed class SignUpFailure implements Exception {
  const SignUpFailure();
}

class InvalidEmailFailure extends SignUpFailure {
  const InvalidEmailFailure();
}

class WeakPasswordFailure extends SignUpFailure {
  const WeakPasswordFailure();
}

class EmailUsedBySnsFailure extends SignUpFailure {
  const EmailUsedBySnsFailure(this.provider);

  final String provider;
}

class UnknownSignUpFailure extends SignUpFailure {
  const UnknownSignUpFailure();
}

/// Edge Function `sign-up-with-email`が返す`FunctionException`を
/// アプリ内の`SignUpFailure`に変換する。
SignUpFailure mapFunctionExceptionToSignUpFailure(FunctionException e) {
  final details = e.details;
  final errorCode = details is Map ? details['error'] as String? : null;

  switch (errorCode) {
    case 'invalid_email':
      return const InvalidEmailFailure();
    case 'weak_password':
      return const WeakPasswordFailure();
    case 'email_used_by_sns':
      final provider = details is Map ? details['provider'] as String? : null;
      return EmailUsedBySnsFailure(provider ?? 'unknown');
    default:
      return const UnknownSignUpFailure();
  }
}
