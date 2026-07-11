import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/data/current_public_user_provider.dart';
import 'package:foglm/features/auth/data/my_profile_provider.dart';

class UpdateProfileController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // submit()はupdateProfile呼び出し後にcurrentPublicUserProviderの再取得を
    // 待つ複数ステップの非同期処理を行う。この間に一瞬でもwatcherが
    // いなくなる瞬間があると(riverpodはデフォルトでproviderをautoDispose
    // するため)このprovider自体が破棄され、破棄後にstateへ代入しようとして
    // 例外になる。keepAlive()で永続化し、処理途中の破棄を防ぐ。
    ref.keepAlive();
  }

  Future<void> submit({
    required String displayName,
    String? avatarUrl,
  }) async {
    state = const AsyncLoading<void>();
    final mutationResult = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .updateProfile(displayName: displayName, avatarUrl: avatarUrl),
    );
    if (mutationResult.hasError) {
      state = mutationResult;
      return;
    }

    // update_profileは初回呼び出し時にprofile_completed_atを設定するため、
    // ルーターの認可判定(profileSetupRedirect)が参照するcurrentPublicUser
    // Providerも再取得させる必要がある。再取得の完了を待たずにsubmit()を
    // 返すと、呼び出し元(初回プロフィール設定画面)がすぐ後にcontext.go
    // で画面遷移した際、ルーターのredirectがまだ古い(未完了のままの)
    // 値を見てプロフィール設定画面へ押し戻してしまうため、ここで
    // 再取得の完了を待ってから返す。この再取得が失敗した場合、プロフィール
    // 更新自体は成功していてもsubmit()全体をエラー扱いにする。ログにのみ
    // 記録してstateをAsyncData(null)のまま返すと、呼び出し元が
    // context.goで遷移した直後にルーターが古い値を見て設定画面へ押し戻し、
    // ユーザーには何のエラー表示もないまま無限に押し戻され続けて見える
    // (再取得自体はupdate_profileがcoalesceで冪等なため再試行すれば直る)。
    ref
      ..invalidate(myProfileProvider)
      ..invalidate(currentPublicUserProvider);
    state = await AsyncValue.guard(() async {
      await ref.read(currentPublicUserProvider.future);
    });
    if (state.hasError) {
      developer.log(
        'currentPublicUserProvider refresh after updateProfile failed',
        name: 'UpdateProfileController',
        error: state.error,
        stackTrace: state.stackTrace,
      );
    }
  }
}

final updateProfileControllerProvider =
    AsyncNotifierProvider<UpdateProfileController, void>(
      UpdateProfileController.new,
    );
