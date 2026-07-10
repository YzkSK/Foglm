import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/core/supabase/supabase_providers.dart';
import 'package:foglm/features/auth/domain/delete_account_failure.dart';
import 'package:foglm/features/auth/domain/password_reset_failure.dart';
import 'package:foglm/features/auth/domain/sign_in_failure.dart';
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

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signInWithSns(OAuthProvider provider);

  Future<void> signOut();

  Future<void> requestPasswordReset({required String email});

  Future<void> resetPassword({required String newPassword});

  Future<void> updateProfile({
    required String displayName,
    String? avatarUrl,
  });

  Future<void> deleteAccount();
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
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw mapAuthExceptionToSignInFailure(e);
    } on Object catch (_) {
      throw const SignInFailure.unknown();
    }
    await _rejectIfAccountDeleted();
  }

  @override
  Future<void> signInWithSns(OAuthProvider provider) async {
    await _client.auth.signInWithOAuth(provider);
  }

  /// ログイン成立後、削除済みアカウント(`deleted_at`設定済み)であれば
  /// 即座にサインアウトさせる(仕様書 3.1.3 / 6.1参照)。
  Future<void> _rejectIfAccountDeleted() async {
    final isDeleted = await _client.rpc<bool>('is_account_deleted');
    if (isDeleted) {
      await _client.auth.signOut();
      throw const SignInFailure.deletedAccount();
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

  @override
  Future<void> updateProfile({
    required String displayName,
    String? avatarUrl,
  }) async {
    await _client.rpc<void>(
      'update_profile',
      params: {'p_display_name': displayName, 'p_avatar_url': avatarUrl},
    );
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _client.functions.invoke('delete-account');
    } on FunctionException catch (e) {
      throw mapFunctionExceptionToDeleteAccountFailure(e);
    } on Object catch (_) {
      throw const UnknownDeleteAccountFailure();
    }

    // delete-account Edge Function側でも本人のセッションをsignOutしているが、
    // それはサーバー側のセッション(リフレッシュトークン)を無効化するのみで、
    // このFlutterアプリが保持するローカルのセッションキャッシュはクリアされない
    // ため、ここでも明示的にsignOutしてアプリ側の状態を即座に更新する。
    // ここに到達した時点でサーバー側の削除自体は完了しているため、この
    // signOutが失敗しても例外は投げない(投げてしまうとUI上は削除失敗と
    // 誤表示され、ユーザーが再試行して削除済みアカウントに対して
    // delete-accountを再度呼んでしまう)。ローカルセッションが残っても、
    // 削除成功時に呼び出し元がcurrentPublicUserProviderを再評価すれば
    // 本人のusers行は既に存在しないため未ログイン扱いとなり、ルーターの
    // redirectでログイン画面へ戻る(仕様書 3.1.3参照)。
    try {
      await _client.auth.signOut();
    } on Object catch (e, stackTrace) {
      developer.log(
        'signOut after deleteAccount failed (server-side deletion already '
        'succeeded)',
        name: 'SupabaseAuthRepository',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});
