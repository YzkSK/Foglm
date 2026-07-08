import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';
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
      ref.invalidate(myProfileProvider);
    }
  }
}

final updateProfileControllerProvider =
    AsyncNotifierProvider<UpdateProfileController, void>(
      UpdateProfileController.new,
    );
