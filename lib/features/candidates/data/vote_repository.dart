// 他のRepositoryと同じくmocktailでの差し替えテストを可能にするため、
// 単一メソッドでもクラスとして定義する。
// ignore_for_file: one_member_abstracts

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/core/supabase/supabase_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class VoteRepository {
  Future<void> castVote({required String photoId});
}

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
