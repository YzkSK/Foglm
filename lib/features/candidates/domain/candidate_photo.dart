import 'package:freezed_annotation/freezed_annotation.dart';

part 'candidate_photo.freezed.dart';

/// その日撮影された、投票対象の候補写真の1件(仕様書 3.5 / 6.4
/// `get_today_candidates`参照)。今日の候補一覧画面(S07)・投票画面(S08)の
/// 表示に必要な情報のみを持つ。
@freezed
abstract class CandidatePhotoRow with _$CandidatePhotoRow {
  const factory CandidatePhotoRow({
    required String id,
    required String blurredUrl,
    required int voteCount,
    required bool votedByMe,
  }) = _CandidatePhotoRow;
}
