import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';

class SignUpController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({required String email, required String password}) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signUpWithEmail(
            email: email,
            password: password,
          ),
    );
  }
}

final signUpControllerProvider = AsyncNotifierProvider<SignUpController, void>(
  SignUpController.new,
);
