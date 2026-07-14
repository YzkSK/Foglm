import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/features/groups/data/group_repository.dart';
import 'package:foglm/features/groups/domain/group_repository.dart';

/// 固定グループを作成する(仕様書 6.1 `create_group`参照)。
class CreateGroupUseCase {
  CreateGroupUseCase(this._repository);

  final GroupRepository _repository;

  Future<void> call({required String name}) {
    return _repository.createGroup(name: name);
  }
}

final createGroupUseCaseProvider = Provider<CreateGroupUseCase>((ref) {
  return CreateGroupUseCase(ref.watch(groupRepositoryProvider));
});
