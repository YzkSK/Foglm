import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/groups/data/group_repository.dart';

class CreateGroupController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({required String name}) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref.read(groupRepositoryProvider).createGroup(name: name),
    );
  }
}

final createGroupControllerProvider =
    AsyncNotifierProvider<CreateGroupController, void>(
      CreateGroupController.new,
    );
