import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';

class ResetPasswordController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({required String newPassword}) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .resetPassword(newPassword: newPassword),
    );
  }
}

final resetPasswordControllerProvider =
    AsyncNotifierProvider<ResetPasswordController, void>(
      ResetPasswordController.new,
    );
