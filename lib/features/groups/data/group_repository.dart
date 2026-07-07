import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/core/supabase/supabase_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// グループ関連の他API(招待・参加・イベントグループ作成等)を今後追加していく
// 想定のため、既存のAuthRepositoryと同じ抽象インターフェース+Supabase実装
// パターンを踏襲する。
// ignore: one_member_abstracts
abstract class GroupRepository {
  Future<void> createGroup({required String name});
}

class SupabaseGroupRepository implements GroupRepository {
  SupabaseGroupRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> createGroup({required String name}) async {
    await _client.rpc<void>('create_group', params: {'p_name': name});
  }
}

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return SupabaseGroupRepository(ref.watch(supabaseClientProvider));
});
