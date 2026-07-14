import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/core/supabase/supabase_providers.dart';
import 'package:foglm/core/utils/date_formatting.dart';
import 'package:foglm/features/candidates/domain/candidate_logic.dart';
import 'package:foglm/features/candidates/domain/candidate_photo.dart';
import 'package:foglm/features/candidates/domain/candidate_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ボヤけ版の署名付きURLの有効期限。閲覧セッション中は十分持たせつつ、
/// 非公開ストレージのURLを無期限に共有可能にしないための値(仕様書 8.1参照)。
const _blurredUrlExpiresInSeconds = 3600;

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

    final photos = photoRows
        .map(
          (row) => (
            id: row['id'] as String,
            blurredStoragePath: row['blurred_storage_path'] as String,
          ),
        )
        .toList();

    // 得票状況の取得と署名付きURLの発行は互いに依存しないため、直列に
    // 待たず並行に実行してラウンドトリップの合計待ち時間を縮める
    // (Dartのasync関数は呼び出した時点で実行が始まるため、await前に
    // 両方のFutureを生成しておけば並行実行になる)。
    final votesFuture = _fetchVotes(groupId: groupId, today: today);
    final blurredUrlsFuture = _fetchBlurredUrls(photos);

    return buildCandidateRows(
      photos: photos,
      votes: await votesFuture,
      currentUserId: _client.auth.currentUser?.id,
      blurredUrlsByPath: await blurredUrlsFuture,
    );
  }

  Future<List<({String userId, String photoId})>> _fetchVotes({
    required String groupId,
    required String today,
  }) async {
    final dailyVote = await _client
        .from('daily_votes')
        .select('id')
        .eq('group_id', groupId)
        .eq('vote_date', today)
        .maybeSingle();

    if (dailyVote == null) {
      // upload-photo Edge Functionが撮影のたびにdaily_votesをUPSERTで
      // 必ず作成するため、候補写真(photoRows)が存在する時点でdaily_votes
      // も存在するはず。それでもnullだった場合は不整合として記録した上で、
      // 一覧表示自体は継続させる(0票として扱う)。
      developer.log(
        'daily_votes row not found despite existing candidate photos '
        '(group: $groupId, date: $today)',
        name: 'SupabaseCandidateRepository',
      );
      return [];
    }

    // RLS(vote_entries_select_active_member)により、自分が現役メンバーの
    // グループの投票のみ返る。
    final voteRows = await _client
        .from('vote_entries')
        .select('user_id, photo_id')
        .eq('daily_vote_id', dailyVote['id'] as String);
    return voteRows
        .map(
          (row) => (
            userId: row['user_id'] as String,
            photoId: row['photo_id'] as String,
          ),
        )
        .toList();
  }

  Future<Map<String, String>> _fetchBlurredUrls(
    List<({String id, String blurredStoragePath})> photos,
  ) async {
    final signedUrlResults = await _client.storage
        .from('photo-blurred')
        .createSignedUrlsResult(
          photos.map((photo) => photo.blurredStoragePath).toList(),
          _blurredUrlExpiresInSeconds,
        );
    final blurredUrlsByPath = <String, String>{};
    for (final result in signedUrlResults) {
      switch (result) {
        case SignedUrlSuccess(:final path, :final signedUrl):
          blurredUrlsByPath[path] = signedUrl;
        case SignedUrlFailure(:final path, :final error):
          // 署名付きURLの発行に失敗した写真は、握り潰さずログに残した上で
          // (buildCandidateRows内で)blurredUrlを空文字にフォールバックする。
          developer.log(
            'failed to create a signed URL for $path',
            name: 'SupabaseCandidateRepository',
            error: error,
          );
      }
    }
    return blurredUrlsByPath;
  }
}

final candidateRepositoryProvider = Provider<CandidateRepository>((ref) {
  return SupabaseCandidateRepository(ref.watch(supabaseClientProvider));
});
