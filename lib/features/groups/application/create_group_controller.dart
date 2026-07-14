import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/groups/application/usecase/create_group_usecase.dart';

class CreateGroupController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({required String name}) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref.read(createGroupUseCaseProvider).call(name: name),
    );
  }
}

final createGroupControllerProvider =
    AsyncNotifierProvider<CreateGroupController, void>(
      CreateGroupController.new,
    );
