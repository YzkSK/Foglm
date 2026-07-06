import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/data/current_public_user_provider.dart';

class SignOutController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signOut() async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signOut(),
    );
    if (!state.hasError) {
      ref.invalidate(currentPublicUserProvider);
    }
  }
}

final signOutControllerProvider =
    AsyncNotifierProvider<SignOutController, void>(SignOutController.new);
