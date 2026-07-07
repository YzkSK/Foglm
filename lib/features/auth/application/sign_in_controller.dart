import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/data/current_public_user_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignInController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submitEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signInWithEmail(email: email, password: password),
    );
    // メール・パスワードログインはこの時点でセッションが確立済みのため、
    // 即座にcurrentPublicUserProviderを再評価させる(SNSログインは
    // AuthStateListener側で処理する。詳細はそちらのdocコメント参照)。
    if (!state.hasError) {
      ref.invalidate(currentPublicUserProvider);
    }
  }

  Future<void> submitSns(OAuthProvider provider) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithSns(provider),
    );
  }
}

final signInControllerProvider = AsyncNotifierProvider<SignInController, void>(
  SignInController.new,
);
