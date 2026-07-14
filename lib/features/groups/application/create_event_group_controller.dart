import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/groups/application/usecase/create_event_group_usecase.dart';

class CreateEventGroupController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref
          .read(createEventGroupUseCaseProvider)
          .call(
            name: name,
            startDate: startDate,
            endDate: endDate,
          ),
    );
  }
}

final createEventGroupControllerProvider =
    AsyncNotifierProvider<CreateEventGroupController, void>(
      CreateEventGroupController.new,
    );
