import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/groups/data/group_repository.dart';
import 'package:foglm/features/groups/data/my_groups_provider.dart';

class LeaveGroupController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({required String groupId}) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref.read(groupRepositoryProvider).leaveGroup(groupId: groupId),
    );
    if (!state.hasError) {
      ref.invalidate(myGroupsProvider);
    }
  }
}

final leaveGroupControllerProvider =
    AsyncNotifierProvider<LeaveGroupController, void>(
      LeaveGroupController.new,
    );
