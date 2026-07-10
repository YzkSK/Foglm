// 他のRepositoryと同じくmocktailでの差し替えテストを可能にするため、
// 単一メソッドでもクラスとして定義する。
// ignore_for_file: one_member_abstracts

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/core/supabase/supabase_providers.dart';
import 'package:foglm/core/utils/date_formatting.dart';
import 'package:foglm/features/candidates/data/candidate_logic.dart';
import 'package:foglm/features/candidates/domain/candidate_photo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ボヤけ版の署名付きURLの有効期限。閲覧セッション中は十分持たせつつ、
/// 非公開ストレージのURLを無期限に共有可能にしないための値(仕様書 8.1参照)。
const _blurredUrlExpiresInSeconds = 3600;

abstract class CandidateRepository {
  Future<List<CandidatePhotoRow>> getTodayCandidates({
    required String groupId,
  });
}

class SupabaseCandidateRepository implements CandidateRepository {
  SupabaseCandidateRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<CandidatePhotoRow>> getTodayCandidates({
    required String groupId,
  }) async {
    // taken_dateはDBのcheck_photo_daily_limitトリガーと同じくJST基準の
    // 日付なので、こちらもJST基準の「今日」で絞り込む(仕様書 5.2.1参照)。
    final today = todayInAsiaTokyo();

    // RLS(photos_select_active_member)により、自分が現役メンバーの
    // グループの写真のみ返る(仕様書 6.4 get_today_candidates参照)。
    final photoRows = await _client
        .from('photos')
        .select('id, blurred_storage_path')
        .eq('group_id', groupId)
        .eq('taken_date', today)
        .eq('status', 'pending_vote')
        .order('taken_at');

    if (photoRows.isEmpty) {
      return [];
    }

    final dailyVote = await _client
        .from('daily_votes')
        .select('id')
        .eq('group_id', groupId)
        .eq('vote_date', today)
        .maybeSingle();

    var votes = <({String userId, String photoId})>[];
    if (dailyVote != null) {
      // RLS(vote_entries_select_active_member)により、自分が現役メンバーの
      // グループの投票のみ返る。
      final voteRows = await _client
          .from('vote_entries')
          .select('user_id, photo_id')
          .eq('daily_vote_id', dailyVote['id'] as String);
      votes = voteRows
          .map(
            (row) => (
              userId: row['user_id'] as String,
              photoId: row['photo_id'] as String,
            ),
          )
          .toList();
    }

    final photos = photoRows
        .map(
          (row) => (
            id: row['id'] as String,
            blurredStoragePath: row['blurred_storage_path'] as String,
          ),
        )
        .toList();
    final signedUrlResults = await _client.storage
        .from('photo-blurred')
        .createSignedUrlsResult(
          photos.map((photo) => photo.blurredStoragePath).toList(),
          _blurredUrlExpiresInSeconds,
        );
    final blurredUrlsByPath = {
      for (final result in signedUrlResults)
        if (result is SignedUrlSuccess) result.path: result.signedUrl,
    };

    return buildCandidateRows(
      photos: photos,
      votes: votes,
      currentUserId: _client.auth.currentUser?.id,
      blurredUrlsByPath: blurredUrlsByPath,
    );
  }
}

final candidateRepositoryProvider = Provider<CandidateRepository>((ref) {
  return SupabaseCandidateRepository(ref.watch(supabaseClientProvider));
});
