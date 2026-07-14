import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/features/groups/data/group_repository.dart';
import 'package:foglm/features/groups/domain/group_repository.dart';

/// 招待コードでグループへ参加する(仕様書 6.2 `invite_member` /
/// `join_event_group`参照)。
class JoinGroupUseCase {
  JoinGroupUseCase(this._repository);

  final GroupRepository _repository;

  Future<void> call({required String code}) {
    return _repository.joinGroupByCode(code: code);
  }
}

final joinGroupUseCaseProvider = Provider<JoinGroupUseCase>((ref) {
  return JoinGroupUseCase(ref.watch(groupRepositoryProvider));
});
