import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/features/camera/application/usecase/watch_remaining_shots_usecase.dart';

/// 指定したグループの当日の残り撮影可能枚数(仕様書 5.2.3参照)。
///
/// `get_today_shots_remaining`をSupabase Realtimeで購読し、他メンバーの
/// 撮影による残数減少も即座に画面へ反映する。
// StreamProvider.family()の戻り値の型(StreamProviderFamily)はriverpodの
// 公開APIとしてexportされていないため、型注釈を明示できない。
// ignore: specify_nonobvious_property_types
final remainingShotsProvider = StreamProvider.family<int, String>((
  ref,
  groupId,
) {
  return ref.watch(watchRemainingShotsUseCaseProvider).call(groupId: groupId);
});
