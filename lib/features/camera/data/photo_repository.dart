// 他のRepository(AuthRepository/GroupRepository)と同じくmocktailでの差し替え
// テストを可能にするため、単一メソッドでもクラスとして定義する。
// ignore_for_file: one_member_abstracts

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/core/supabase/supabase_providers.dart';
import 'package:foglm/features/camera/domain/upload_photo_failure.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class PhotoRepository {
  Future<void> uploadPhoto({
    required String groupId,
    required Uint8List bytes,
  });
}

class SupabasePhotoRepository implements PhotoRepository {
  SupabasePhotoRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> uploadPhoto({
    required String groupId,
    required Uint8List bytes,
  }) async {
    try {
      await _client.functions.invoke(
        'upload-photo',
        body: {'group_id': groupId},
        files: [
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'photo.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        ],
      );
    } on FunctionException catch (e) {
      throw mapFunctionExceptionToUploadPhotoFailure(e);
    } on Object catch (_) {
      throw const UnknownUploadPhotoFailure();
    }
  }
}

final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  return SupabasePhotoRepository(ref.watch(supabaseClientProvider));
});
