import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/data/current_public_user_provider.dart';

class SignOutController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signOut() async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      // サインアウト後はauth.uid()が失われ本人の行を更新できなくなるため、
      // 実際のサインアウトの前にクリアする。他人の端末に通知が飛ばないよう
      // にするための処理であり、失敗してもサインアウト自体は継続する
      // (トークン取得失敗を握り潰さない#206の方針に倣いログには残す)。
      try {
        await repository.updateFcmToken(null);
      } on Object catch (e, stackTrace) {
        developer.log(
          'Failed to clear FCM token before sign out',
          name: 'SignOutController',
          error: e,
          stackTrace: stackTrace,
        );
      }
      await repository.signOut();
    });
    if (!state.hasError) {
      ref.invalidate(currentPublicUserProvider);
    }
  }
}

final signOutControllerProvider =
    AsyncNotifierProvider<SignOutController, void>(SignOutController.new);
