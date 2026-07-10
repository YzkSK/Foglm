import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/camera/data/photo_repository.dart';

class UploadPhotoController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({
    required String groupId,
    required Uint8List bytes,
  }) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref
          .read(photoRepositoryProvider)
          .uploadPhoto(groupId: groupId, bytes: bytes),
    );
  }
}

final uploadPhotoControllerProvider =
    AsyncNotifierProvider<UploadPhotoController, void>(
      UploadPhotoController.new,
    );
