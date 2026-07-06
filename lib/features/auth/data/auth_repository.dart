import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/core/supabase/supabase_providers.dart';
import 'package:foglm/features/auth/domain/password_reset_failure.dart';
import 'package:foglm/features/auth/domain/sign_up_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthRepository {
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  });

  Future<void> resendVerificationEmail({required String email});

  Future<bool> checkEmailVerifiedBySignIn({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<void> requestPasswordReset({required String email});

  Future<void> resetPassword({required String newPassword});
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _client.functions.invoke(
        'sign-up-with-email',
        body: {'email': email, 'password': password},
      );
    } on FunctionException catch (e) {
      throw mapFunctionExceptionToSignUpFailure(e);
    } on Object catch (_) {
      throw const UnknownSignUpFailure();
    }
  }

  @override
  Future<void> resendVerificationEmail({required String email}) async {
    await _client.auth.resend(type: OtpType.signup, email: email);
  }

  @override
  Future<bool> checkEmailVerifiedBySignIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return true;
    } on AuthException catch (e) {
      if (e.code == 'email_not_confirmed') {
        return false;
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    try {
      await _client.functions.invoke(
        'request-password-reset',
        body: {'email': email},
      );
    } on FunctionException catch (e) {
      throw mapFunctionExceptionToPasswordResetFailure(e);
    } on Object catch (_) {
      throw const UnknownPasswordResetFailure();
    }
  }

  @override
  Future<void> resetPassword({required String newPassword}) async {
    try {
      await _client.functions.invoke(
        'reset-password',
        body: {'password': newPassword},
      );
    } on FunctionException catch (e) {
      throw mapFunctionExceptionToPasswordResetFailure(e);
    } on Object catch (_) {
      throw const UnknownPasswordResetFailure();
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});
