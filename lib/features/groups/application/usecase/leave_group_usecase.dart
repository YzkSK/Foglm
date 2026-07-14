import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/features/groups/data/group_repository.dart';
import 'package:foglm/features/groups/domain/group_repository.dart';

/// グループから脱退する(仕様書 3.2.1 / 6.2 `leave_group`参照)。
class LeaveGroupUseCase {
  LeaveGroupUseCase(this._repository);

  final GroupRepository _repository;

  Future<void> call({required String groupId}) {
    return _repository.leaveGroup(groupId: groupId);
  }
}

final leaveGroupUseCaseProvider = Provider<LeaveGroupUseCase>((ref) {
  return LeaveGroupUseCase(ref.watch(groupRepositoryProvider));
});
