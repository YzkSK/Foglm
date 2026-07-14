import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/features/groups/data/group_repository.dart';
import 'package:foglm/features/groups/domain/group_repository.dart';

/// グループの招待コードを発行する(既に発行済みの場合は置き換える。仕様書
/// 6.2 `create_invite_code`参照)。
class CreateInviteCodeUseCase {
  CreateInviteCodeUseCase(this._repository);

  final GroupRepository _repository;

  Future<String> call({required String groupId}) {
    return _repository.createInviteCode(groupId: groupId);
  }
}

final createInviteCodeUseCaseProvider = Provider<CreateInviteCodeUseCase>((
  ref,
) {
  return CreateInviteCodeUseCase(ref.watch(groupRepositoryProvider));
});
