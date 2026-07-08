import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/core/supabase/supabase_providers.dart';
import 'package:foglm/core/utils/date_formatting.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class GroupRepository {
  Future<void> createGroup({required String name});

  Future<void> createEventGroup({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  });
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
}

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return SupabaseGroupRepository(ref.watch(supabaseClientProvider));
});
