import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/candidates/data/candidate_repository.dart';
import 'package:foglm/features/candidates/domain/candidate_photo.dart';

/// 指定したグループの、当日撮影された投票対象の候補写真一覧(ボヤけ版URL・
/// 得票状況付き)。今日の候補一覧画面(S07、#22)・投票画面(S08、#23)の
/// 表示に使う。
// FutureProvider.family()の戻り値の型(FutureProviderFamily)はriverpodの
// 公開APIとしてexportされていないため、型注釈を明示できない。
// ignore: specify_nonobvious_property_types
final todayCandidatesProvider =
    FutureProvider.family<List<CandidatePhotoRow>, String>((ref, groupId) {
      return ref
          .watch(candidateRepositoryProvider)
          .getTodayCandidates(groupId: groupId);
    });
