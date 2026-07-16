import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/groups/application/my_groups_provider.dart';
import 'package:foglm/features/groups/data/group_repository.dart';

class JoinGroupController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({required String code}) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref.read(groupRepositoryProvider).joinGroupByCode(code: code),
    );
    if (!state.hasError) {
      ref.invalidate(myGroupsProvider);
    }
  }
}

final joinGroupControllerProvider =
    AsyncNotifierProvider<JoinGroupController, void>(JoinGroupController.new);
