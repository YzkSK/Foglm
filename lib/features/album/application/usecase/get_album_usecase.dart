import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/features/album/data/album_repository.dart';
import 'package:foglm/features/album/domain/album_photo.dart';
import 'package:foglm/features/album/domain/album_repository.dart';

/// 指定したグループの現像済み写真一覧(撮影日の新しい順)を取得する
/// (アルバム画面 S09、#27の表示に使う)。
class GetAlbumUseCase {
  GetAlbumUseCase(this._repository);

  final AlbumRepository _repository;

  Future<List<AlbumPhotoRow>> call({required String groupId}) {
    return _repository.getAlbum(groupId: groupId);
  }
}

final getAlbumUseCaseProvider = Provider<GetAlbumUseCase>((ref) {
  return GetAlbumUseCase(ref.watch(albumRepositoryProvider));
});
