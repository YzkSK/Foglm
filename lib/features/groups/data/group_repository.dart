import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/core/supabase/supabase_providers.dart';
import 'package:foglm/core/utils/date_formatting.dart';
import 'package:foglm/features/groups/domain/my_group.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class GroupRepository {
  Future<void> createGroup({required String name});

  Future<void> createEventGroup({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<List<MyGroupRow>> getMyGroups();
}

class SupabaseGroupRepository implements GroupRepository {
  SupabaseGroupRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> createGroup({required String name}) async {
    await _client.rpc<void>('create_group', params: {'p_name': name});
  }

  @override
  Future<void> createEventGroup({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await _client.rpc<void>(
      'create_event_group',
      params: {
        'p_name': name,
        'p_start_date': formatDateOnly(startDate),
        'p_end_date': formatDateOnly(endDate),
      },
    );
  }

  @override
  Future<List<MyGroupRow>> getMyGroups() async {
    // RLS(groups_select_active_member)により、自分が現役メンバーのグループのみ返る
    // (仕様書 6.2 get_my_groups参照)。
    final rows = await _client
        .from('groups')
        .select('id, name, mode, status, start_date, end_date')
        .order('created_at', ascending: false);
    return rows.map(MyGroupRow.fromMap).toList();
  }
}

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return SupabaseGroupRepository(ref.watch(supabaseClientProvider));
});
