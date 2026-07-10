import 'package:foglm/features/candidates/domain/candidate_photo.dart';

/// `candidate_repository.dart`から取得した生の行データを、投票状況を集計した
/// [CandidatePhotoRow]のリストへ変換する(純粋関数として切り出すことで
/// Supabaseクライアントなしに単体テスト可能にする)。
///
/// `votes`の各`userId`は`vote_entries`の`UNIQUE (daily_vote_id, user_id)`
/// 制約により1人1行しか存在しないため、再投票による重複集計は起こらない。
List<CandidatePhotoRow> buildCandidateRows({
  required List<({String id, String blurredStoragePath})> photos,
  required List<({String userId, String photoId})> votes,
  required String? currentUserId,
  required Map<String, String> blurredUrlsByPath,
}) {
  final voteCounts = <String, int>{};
  String? myVotedPhotoId;
  for (final vote in votes) {
    voteCounts[vote.photoId] = (voteCounts[vote.photoId] ?? 0) + 1;
    if (vote.userId == currentUserId) {
      myVotedPhotoId = vote.photoId;
    }
  }

  return photos.map((photo) {
    return CandidatePhotoRow(
      id: photo.id,
      blurredUrl: blurredUrlsByPath[photo.blurredStoragePath] ?? '',
      voteCount: voteCounts[photo.id] ?? 0,
      votedByMe: photo.id == myVotedPhotoId,
    );
  }).toList();
}
