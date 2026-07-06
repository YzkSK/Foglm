import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'sign_up_failure.freezed.dart';

/// サインアップ失敗時のアプリ内エラー種別(仕様書 6.1 sign_up_with_email参照)。
@freezed
sealed class SignUpFailure with _$SignUpFailure implements Exception {
  const factory SignUpFailure.invalidEmail() = InvalidEmailFailure;

  const factory SignUpFailure.weakPassword() = WeakPasswordFailure;

  const factory SignUpFailure.emailUsedBySns(String provider) =
      EmailUsedBySnsFailure;

  const factory SignUpFailure.unknown() = UnknownSignUpFailure;
}

/// Edge Function `sign-up-with-email`が返す`FunctionException`を
/// アプリ内の`SignUpFailure`に変換する。
SignUpFailure mapFunctionExceptionToSignUpFailure(FunctionException e) {
  final details = e.details;
  final errorCode = details is Map ? details['error'] as String? : null;

  switch (errorCode) {
    case 'invalid_email':
      return const SignUpFailure.invalidEmail();
    case 'weak_password':
      return const SignUpFailure.weakPassword();
    case 'email_used_by_sns':
      final provider = details is Map ? details['provider'] as String? : null;
      return SignUpFailure.emailUsedBySns(provider ?? 'unknown');
    default:
      return const SignUpFailure.unknown();
  }
}
