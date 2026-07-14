import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/groups/application/my_groups_provider.dart';
import 'package:foglm/features/groups/application/usecase/join_group_usecase.dart';

class JoinGroupController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({required String code}) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref.read(joinGroupUseCaseProvider).call(code: code),
    );
    if (!state.hasError) {
      ref.invalidate(myGroupsProvider);
    }
  }
}

final joinGroupControllerProvider =
    AsyncNotifierProvider<JoinGroupController, void>(JoinGroupController.new);
