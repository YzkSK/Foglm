import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'sign_in_failure.freezed.dart';

/// ログイン失敗時のアプリ内エラー種別(仕様書 3.1.1 / 6.1 sign_in_with_email参照)。
@freezed
sealed class SignInFailure with _$SignInFailure implements Exception {
  const factory SignInFailure.invalidCredentials() = InvalidCredentialsFailure;

  const factory SignInFailure.emailNotConfirmed() = EmailNotConfirmedFailure;

  const factory SignInFailure.deletedAccount() = DeletedAccountFailure;

  const factory SignInFailure.unknown() = UnknownSignInFailure;
}

/// Supabase Authが返す`AuthException`をアプリ内の`SignInFailure`に変換する。
SignInFailure mapAuthExceptionToSignInFailure(AuthException e) {
  switch (e.code) {
    case 'email_not_confirmed':
      return const SignInFailure.emailNotConfirmed();
    case 'invalid_credentials':
      return const SignInFailure.invalidCredentials();
    default:
      return const SignInFailure.unknown();
  }
}
