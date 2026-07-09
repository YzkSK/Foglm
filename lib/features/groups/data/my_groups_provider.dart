import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/core/supabase/supabase_providers.dart';
import 'package:foglm/features/groups/domain/my_group.dart';

/// ログイン中ユーザーが所属するグループ一覧(固定グループ・ソロモード・
/// イベントグループを含む)。RLS(`groups_select_active_member`)により、
/// 自分が現役メンバーのグループのみが返る(仕様書 6.2 get_my_groups参照)。
/// グループ一覧画面(S03、#36)の表示に使う。
final myGroupsProvider = FutureProvider<List<MyGroupRow>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('groups')
      .select('id, name, mode, status, start_date, end_date')
      .order('created_at');
  return rows.map(MyGroupRow.fromMap).toList();
});
