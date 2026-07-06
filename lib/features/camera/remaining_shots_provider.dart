import 'package:flutter_riverpod/flutter_riverpod.dart';

/// その日の残り撮影可能枚数を管理する。
///
/// 本来は `get_today_shots_remaining` をSupabase Realtimeで購読して
/// 他メンバーの撮影も即座に反映する(仕様書 5.2.3)が、バックエンドAPIが
/// 未実装のため、暫定的に固定グループの1日上限(仕様書 3.3)からの
/// ローカルカウントダウンとして扱う。#19〜#21で実データに差し替える。
class RemainingShotsNotifier extends Notifier<int> {
  @override
  int build() => 10;

  void decrement() {
    if (state > 0) {
      state = state - 1;
    }
  }
}

final remainingShotsProvider = NotifierProvider<RemainingShotsNotifier, int>(
  RemainingShotsNotifier.new,
);
