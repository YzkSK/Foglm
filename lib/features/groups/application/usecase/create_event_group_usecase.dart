import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/features/groups/data/group_repository.dart';
import 'package:foglm/features/groups/domain/group_repository.dart';

/// イベントグループを作成する(仕様書 6.2 `create_event_group`参照)。
class CreateEventGroupUseCase {
  CreateEventGroupUseCase(this._repository);

  final GroupRepository _repository;

  Future<void> call({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _repository.createEventGroup(
      name: name,
      startDate: startDate,
      endDate: endDate,
    );
  }
}

final createEventGroupUseCaseProvider = Provider<CreateEventGroupUseCase>((
  ref,
) {
  return CreateEventGroupUseCase(ref.watch(groupRepositoryProvider));
});
