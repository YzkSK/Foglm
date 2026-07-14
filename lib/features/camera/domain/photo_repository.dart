// 他のRepository(AuthRepository/GroupRepository)と同じくmocktailでの差し替え
// テストを可能にするため、単一メソッドでもクラスとして定義する。
// ignore_for_file: one_member_abstracts

import 'dart:typed_data';

abstract class PhotoRepository {
  Future<void> uploadPhoto({
    required String groupId,
    required Uint8List bytes,
  });
}
