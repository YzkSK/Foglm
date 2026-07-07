import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/core/supabase/supabase_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class GroupRepository {
  Future<void> createGroup({required String name});

  Future<void> createEventGroup({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  });
}

/// `date`型のRPCパラメータ用に、時刻・タイムゾーンを含まない日付文字列
/// (`yyyy-MM-dd`)を組み立てる。
String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
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
        'p_start_date': _formatDate(startDate),
        'p_end_date': _formatDate(endDate),
      },
    );
  }
}

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return SupabaseGroupRepository(ref.watch(supabaseClientProvider));
});
