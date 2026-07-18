// 他のRepositoryと同じくmocktailでの差し替えテストを可能にするため、
// 単一メソッドでもクラスとして定義する。
// ignore_for_file: one_member_abstracts

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/core/supabase/supabase_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class PhotoUrlRepository {
  /// 写真1件分の閲覧用署名付きURLを取得する(`get-photo-url` Edge Function、
  /// 仕様書 6.5参照)。現像済み写真は原本、それ以外はボヤけ版のURLが返る。
  /// アルバム画面(S09)はサムネイルごとに個別に呼び出す想定
  /// (`get_album`自体はURLを含まない。`album_photo.dart`のdocコメント参照)。
  Future<String> getPhotoUrl({required String photoId});
}

class SupabasePhotoUrlRepository implements PhotoUrlRepository {
  SupabasePhotoUrlRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String> getPhotoUrl({required String photoId}) async {
    final response = await _client.functions.invoke(
      'get-photo-url',
      body: {'photo_id': photoId},
    );
    final data = response.data as Map<String, dynamic>;
    return data['url'] as String;
  }
}

final photoUrlRepositoryProvider = Provider<PhotoUrlRepository>((ref) {
  return SupabasePhotoUrlRepository(ref.watch(supabaseClientProvider));
});

/// 写真1件分の署名付きURL。アルバム画面(S09)のタイルごとに個別購読する。
// ignore: specify_nonobvious_property_types
final photoUrlProvider = FutureProvider.family<String, String>((
  ref,
  photoId,
) {
  return ref.watch(photoUrlRepositoryProvider).getPhotoUrl(photoId: photoId);
});
