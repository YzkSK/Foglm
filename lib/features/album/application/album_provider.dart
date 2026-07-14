import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/album/application/usecase/get_album_usecase.dart';
import 'package:foglm/features/album/application/usecase/get_developing_count_usecase.dart';
import 'package:foglm/features/album/domain/album_photo.dart';

/// 指定したグループの現像済み写真一覧(撮影日の新しい順)。アルバム画面
/// (S09、#27)の表示に使う。
// FutureProvider.family()の戻り値の型(FutureProviderFamily)はriverpodの
// 公開APIとしてexportされていないため、型注釈を明示できない。
// ignore: specify_nonobvious_property_types
final albumProvider = FutureProvider.family<List<AlbumPhotoRow>, String>((
  ref,
  groupId,
) {
  return ref.watch(getAlbumUseCaseProvider).call(groupId: groupId);
});

/// 指定したグループの現像待ち枚数。現像待ちステータス表示(#32)の表示に
/// 使う。
// ignore: specify_nonobvious_property_types
final developingCountProvider = FutureProvider.family<int, String>((
  ref,
  groupId,
) {
  return ref
      .watch(getDevelopingCountUseCaseProvider)
      .call(groupId: groupId);
});
