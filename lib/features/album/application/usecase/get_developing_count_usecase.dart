import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/features/album/data/album_repository.dart';
import 'package:foglm/features/album/domain/album_repository.dart';

/// 指定したグループの現像待ち枚数を取得する(現像待ちステータス表示
/// #32の表示に使う)。
class GetDevelopingCountUseCase {
  GetDevelopingCountUseCase(this._repository);

  final AlbumRepository _repository;

  Future<int> call({required String groupId}) {
    return _repository.getDevelopingCount(groupId: groupId);
  }
}

final getDevelopingCountUseCaseProvider = Provider<GetDevelopingCountUseCase>((
  ref,
) {
  return GetDevelopingCountUseCase(ref.watch(albumRepositoryProvider));
});
