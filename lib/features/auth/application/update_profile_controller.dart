import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/data/current_public_user_provider.dart';
import 'package:foglm/features/auth/data/my_profile_provider.dart';

class UpdateProfileController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({
    required String displayName,
    String? avatarUrl,
  }) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .updateProfile(displayName: displayName, avatarUrl: avatarUrl),
    );
    if (!state.hasError) {
      // update_profileは初回呼び出し時にprofile_completed_atを設定するため、
      // ルーターの認可判定(profileSetupRedirect)が参照するcurrentPublicUser
      // Providerも再取得させる必要がある。再取得の完了を待たずにsubmit()を
      // 返すと、呼び出し元(初回プロフィール設定画面)がすぐ後にcontext.go
      // で画面遷移した際、ルーターのredirectがまだ古い(未完了のままの)
      // 値を見てプロフィール設定画面へ押し戻してしまうため、ここで
      // 再取得の完了を待ってから返す。プロフィール更新自体は既に成功して
      // いるため、この再取得だけが失敗してもsubmit()全体は失敗扱いにせず
      // (誤解を招くため)、ログにのみ記録する。
      ref
        ..invalidate(myProfileProvider)
        ..invalidate(currentPublicUserProvider);
      try {
        await ref.read(currentPublicUserProvider.future);
      } on Object catch (error, stackTrace) {
        developer.log(
          'currentPublicUserProvider refresh after updateProfile failed',
          name: 'UpdateProfileController',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }
}

final updateProfileControllerProvider =
    AsyncNotifierProvider<UpdateProfileController, void>(
      UpdateProfileController.new,
    );
