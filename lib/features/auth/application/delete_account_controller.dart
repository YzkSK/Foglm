import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/auth/application/current_public_user_provider.dart';
import 'package:foglm/features/auth/data/auth_repository.dart';

class DeleteAccountController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit() async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).deleteAccount(),
    );
    if (!state.hasError) {
      // ログイン状態を再評価させ、ルーターのredirectでログイン画面へ戻す
      // (仕様書 3.1.3参照)。
      ref.invalidate(currentPublicUserProvider);
    }
  }
}

final deleteAccountControllerProvider =
    AsyncNotifierProvider<DeleteAccountController, void>(
      DeleteAccountController.new,
    );
