import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/core/supabase/supabase_providers.dart';
import 'package:foglm/core/utils/date_formatting.dart';
import 'package:foglm/core/utils/fallback.dart';
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

  Future<void> joinGroupByCode({required String code});

  Future<void> leaveGroup({required String groupId});
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

  @override
  Future<void> joinGroupByCode({required String code}) async {
    // 招待コードの参加RPCは固定グループ用(invite_member)・イベントグループ用
    // (join_event_group)に分かれており、コード単体からはどちらのモードか
    // 判別できないため、まずinvite_memberを試し、失敗した場合のみ
    // join_event_groupを試す。invite_memberの失敗理由(無効なコードか、単に
    // 固定グループ用でなかっただけかは区別できない)は握り潰さずログに残す。
    await tryWithFallback<void>(
      primary: () =>
          _client.rpc<void>('invite_member', params: {'p_code': code}),
      fallback: () =>
          _client.rpc<void>('join_event_group', params: {'p_code': code}),
      onPrimaryError: (error, stackTrace) => developer.log(
        'invite_member failed, falling back to join_event_group',
        name: 'SupabaseGroupRepository',
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  @override
  Future<void> leaveGroup({required String groupId}) async {
    await _client.rpc<void>(
      'leave_group',
      params: {'p_group_id': groupId},
    );
  }
}

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return SupabaseGroupRepository(ref.watch(supabaseClientProvider));
});
