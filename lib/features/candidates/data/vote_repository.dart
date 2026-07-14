import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/core/supabase/supabase_providers.dart';
import 'package:foglm/features/candidates/domain/vote_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseVoteRepository implements VoteRepository {
  SupabaseVoteRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> castVote({required String photoId}) async {
    await _client.rpc<void>('cast_vote', params: {'p_photo_id': photoId});
  }
}

final voteRepositoryProvider = Provider<VoteRepository>((ref) {
  return SupabaseVoteRepository(ref.watch(supabaseClientProvider));
});
