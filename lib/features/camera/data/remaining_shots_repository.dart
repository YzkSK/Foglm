import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/core/supabase/supabase_providers.dart';
import 'package:foglm/features/camera/domain/remaining_shots_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRemainingShotsRepository implements RemainingShotsRepository {
  SupabaseRemainingShotsRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<int> watchTodayShotsRemaining({required String groupId}) {
    late final StreamController<int> controller;
    RealtimeChannel? channel;

    Future<void> fetchAndEmit() async {
      try {
        final remaining = await _client.rpc<int>(
          'get_today_shots_remaining',
          params: {'p_group_id': groupId},
        );
        if (!controller.isClosed) {
          controller.add(remaining);
        }
      } on Object catch (error, stackTrace) {
        // RPCの例外を握り潰さず、ストリームのエラーとして呼び出し元に伝える
        // (ここで捕まえないとunawaited()の中で未処理のZone例外として消え、
        // ストリームが更新を止めたまま無言でフリーズしてしまう)。
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      }
    }

    controller = StreamController<int>(
      onListen: () {
        channel = _client
            .channel('photos-remaining-$groupId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'photos',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'group_id',
                value: groupId,
              ),
              callback: (_) => unawaited(fetchAndEmit()),
            )
            .subscribe();
        unawaited(fetchAndEmit());
      },
      onCancel: () async {
        final subscribedChannel = channel;
        if (subscribedChannel != null) {
          await _client.removeChannel(subscribedChannel);
        }
        // close()後はfetchAndEmit()側のisClosedガードが効くため、購読解除後に
        // 進行中だったRPCが遅れて完了してもcontroller.add/addErrorは無視される。
        await controller.close();
      },
    );

    return controller.stream;
  }
}

final remainingShotsRepositoryProvider = Provider<RemainingShotsRepository>((
  ref,
) {
  return SupabaseRemainingShotsRepository(ref.watch(supabaseClientProvider));
});
