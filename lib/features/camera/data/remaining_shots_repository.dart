// 他のRepositoryと同じくmocktailでの差し替えテストを可能にするため、
// 単一メソッドでもクラスとして定義する。
// ignore_for_file: one_member_abstracts

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/core/supabase/supabase_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class RemainingShotsRepository {
  /// 指定したグループの当日の残り撮影可能枚数を購読する。
  ///
  /// 購読開始時に`get_today_shots_remaining`で現在値を取得し、以降は
  /// `photos`テーブルへのINSERT(Supabase Realtime)を検知するたびに
  /// 再取得して流す。他メンバーの撮影による残数減少も即座に反映する
  /// (仕様書 5.2.3参照)。
  Stream<int> watchTodayShotsRemaining({required String groupId});
}

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
