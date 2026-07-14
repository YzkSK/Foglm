import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/features/camera/data/photo_repository.dart';
import 'package:foglm/features/camera/domain/photo_repository.dart';

/// 写真をアップロードする(仕様書 5.2参照)。
class UploadPhotoUseCase {
  UploadPhotoUseCase(this._repository);

  final PhotoRepository _repository;

  Future<void> call({required String groupId, required Uint8List bytes}) {
    return _repository.uploadPhoto(groupId: groupId, bytes: bytes);
  }
}

final uploadPhotoUseCaseProvider = Provider<UploadPhotoUseCase>((ref) {
  return UploadPhotoUseCase(ref.watch(photoRepositoryProvider));
});
