import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/features/candidates/data/candidate_repository.dart';
import 'package:foglm/features/candidates/domain/candidate_photo.dart';
import 'package:foglm/features/candidates/domain/candidate_repository.dart';

/// 指定したグループの、当日撮影された投票対象の候補写真一覧を取得する
/// (仕様書 6.4 `get_today_candidates`参照)。
class GetTodayCandidatesUseCase {
  GetTodayCandidatesUseCase(this._repository);

  final CandidateRepository _repository;

  Future<List<CandidatePhotoRow>> call({required String groupId}) {
    return _repository.getTodayCandidates(groupId: groupId);
  }
}

final getTodayCandidatesUseCaseProvider = Provider<GetTodayCandidatesUseCase>((
  ref,
) {
  return GetTodayCandidatesUseCase(ref.watch(candidateRepositoryProvider));
});
