import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';

class PasswordResetRequestController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({required String email}) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).requestPasswordReset(email: email),
    );
  }
}

final passwordResetRequestControllerProvider =
    AsyncNotifierProvider<PasswordResetRequestController, void>(
      PasswordResetRequestController.new,
    );
