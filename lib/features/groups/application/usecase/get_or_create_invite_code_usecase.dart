import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/features/groups/data/group_repository.dart';
import 'package:foglm/features/groups/domain/group_repository.dart';

/// グループに既に発行済みの招待コードがあればそれを返し、まだ無ければ
/// 新規発行する(create_invite_codeは呼ぶたびにコードを置き換えてしまうため、
/// 既存コードを無効化しないようにここでは無条件に発行しない。仕様書
/// 6.2参照)。
class GetOrCreateInviteCodeUseCase {
  GetOrCreateInviteCodeUseCase(this._repository);

  final GroupRepository _repository;

  Future<String> call({required String groupId}) async {
    final existing = await _repository.getInviteCode(groupId: groupId);
    if (existing != null) {
      return existing;
    }
    return _repository.createInviteCode(groupId: groupId);
  }
}

final getOrCreateInviteCodeUseCaseProvider =
    Provider<GetOrCreateInviteCodeUseCase>((ref) {
      return GetOrCreateInviteCodeUseCase(ref.watch(groupRepositoryProvider));
    });
