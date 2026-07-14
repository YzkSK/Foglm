import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/features/groups/data/group_repository.dart';
import 'package:foglm/features/groups/domain/group_repository.dart';
import 'package:foglm/features/groups/domain/my_group.dart';

/// ログイン中ユーザーが所属するグループ一覧を取得する(仕様書 6.2
/// `get_my_groups`参照)。
class GetMyGroupsUseCase {
  GetMyGroupsUseCase(this._repository);

  final GroupRepository _repository;

  Future<List<MyGroupRow>> call() {
    return _repository.getMyGroups();
  }
}

final getMyGroupsUseCaseProvider = Provider<GetMyGroupsUseCase>((ref) {
  return GetMyGroupsUseCase(ref.watch(groupRepositoryProvider));
});
