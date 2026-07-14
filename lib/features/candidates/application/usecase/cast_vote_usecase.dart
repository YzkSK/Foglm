import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/features/candidates/data/vote_repository.dart';
import 'package:foglm/features/candidates/domain/vote_repository.dart';

/// 候補写真へ投票する(仕様書 5.2/6.4 `cast_vote`参照)。
class CastVoteUseCase {
  CastVoteUseCase(this._repository);

  final VoteRepository _repository;

  Future<void> call({required String photoId}) {
    return _repository.castVote(photoId: photoId);
  }
}

final castVoteUseCaseProvider = Provider<CastVoteUseCase>((ref) {
  return CastVoteUseCase(ref.watch(voteRepositoryProvider));
});
