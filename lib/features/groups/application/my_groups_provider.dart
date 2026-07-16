import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/groups/data/group_repository.dart';
import 'package:foglm/features/groups/domain/my_group.dart';

/// ログイン中ユーザーが所属するグループ一覧(固定グループ・ソロモード・
/// イベントグループを含む、新しい順)。グループ一覧画面(S03、#36)の表示に使う。
final myGroupsProvider = FutureProvider<List<MyGroupRow>>((ref) {
  return ref.watch(groupRepositoryProvider).getMyGroups();
});
