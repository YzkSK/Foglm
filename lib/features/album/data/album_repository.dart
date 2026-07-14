import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/core/supabase/supabase_providers.dart';
import 'package:foglm/features/album/domain/album_photo.dart';
import 'package:foglm/features/album/domain/album_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAlbumRepository implements AlbumRepository {
  SupabaseAlbumRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AlbumPhotoRow>> getAlbum({required String groupId}) async {
    final rows = await _client
        .from('photos')
        .select('id, taken_at, taken_date')
        .eq('group_id', groupId)
        .eq('status', 'developed')
        .order('taken_date', ascending: false)
        .order('taken_at', ascending: false);
    return rows.map(AlbumPhotoRow.fromMap).toList();
  }

  @override
  Future<int> getDevelopingCount({required String groupId}) async {
    // select()を挟まずcount()を直接呼ぶことで、行データを取得しないHEAD
    // リクエストにする(件数以外のレスポンスボディ転送を避けるため)。
    return _client
        .from('photos')
        .count()
        .eq('group_id', groupId)
        .inFilter('status', developingStatuses);
  }
}

final albumRepositoryProvider = Provider<AlbumRepository>((ref) {
  return SupabaseAlbumRepository(ref.watch(supabaseClientProvider));
});
