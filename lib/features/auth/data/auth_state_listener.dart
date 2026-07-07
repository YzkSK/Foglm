import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/core/supabase/supabase_providers.dart';
import 'package:foglm/features/auth/data/current_public_user_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabaseの認証状態の変化(ログイン・ログアウト・SNSログインの
/// セッション確立)を監視し、[currentPublicUserProvider]を再評価させる。
///
/// `signInWithOAuth`はブラウザを起動した時点で処理が返ってしまい、
/// 実際のセッション確立(ディープリンクでのコールバック受信)を
/// 待てないため、SNSログイン完了はこのリスナー経由でしか検知できない
/// (メール・パスワードログインは`AuthRepository.signInWithEmail`側でも
/// 即座に検知できるため、こちらは主にSNSログイン向けのバックストップ)。
///
/// あわせて、ログイン成立時に削除済みアカウント(`deleted_at`設定済み)
/// でないかを`is_account_deleted()` RPCで確認し、削除済みなら即座に
/// サインアウトさせる(仕様書 3.1.3 / 6.1参照。SNSログインでは
/// `AuthRepository`側でこの判定を行えないため、ここが唯一の判定箇所)。
class AuthStateListener {
  AuthStateListener(this._ref, this._client) {
    _subscription = _client.auth.onAuthStateChange.listen(_handle);
  }

  final Ref _ref;
  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _subscription;

  Future<void> _handle(AuthState data) async {
    // tokenRefreshed等、ログイン状態が変わらないイベントでは再評価しない
    // (currentPublicUserProviderが無駄に再取得され、ログイン画面が
    // 入力中でもスピナー表示にちらつく問題を防ぐ)。
    if (data.event != AuthChangeEvent.signedIn &&
        data.event != AuthChangeEvent.signedOut) {
      return;
    }
    if (data.event == AuthChangeEvent.signedIn) {
      final isDeleted = await _client.rpc<bool>('is_account_deleted');
      if (isDeleted) {
        await _client.auth.signOut();
        return;
      }
    }
    _ref.invalidate(currentPublicUserProvider);
  }

  void dispose() {
    unawaited(_subscription.cancel());
  }
}

/// Supabase未初期化の環境(テスト等)では`supabaseClientProvider`が同期的に
/// 例外を投げるため、監視を開始せず`null`を返す。
final authStateListenerProvider = Provider<AuthStateListener?>((ref) {
  final SupabaseClient client;
  try {
    client = ref.watch(supabaseClientProvider);
  } on Object {
    return null;
  }
  final listener = AuthStateListener(ref, client);
  ref.onDispose(listener.dispose);
  return listener;
});
