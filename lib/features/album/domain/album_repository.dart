import 'package:foglm/features/album/domain/album_photo.dart';

/// 現像待ち(まだ現像されていない)とみなす`photos.status`の一覧
/// (仕様書 3.6/3.8 `get_developing_count`参照)。その日撮影されたばかりで
/// まだ投票結果が出ていない写真(pending_vote)も、ランダム現像待ちの写真
/// (waiting_random)も、どちらもまだ現像されていない点では同じため含める。
const developingStatuses = ['pending_vote', 'waiting_random'];

abstract class AlbumRepository {
  /// グループの現像済み写真を撮影日の新しい順に取得する(仕様書 6.5
  /// `get_album`参照)。イベントグループのクローズ後・固定グループの
  /// アーカイブ後も、現役メンバーである限りRLS(photos_select_active_member)
  /// により引き続き閲覧できる。
  Future<List<AlbumPhotoRow>> getAlbum({required String groupId});

  /// グループの現像待ち枚数を取得する(仕様書 6.5 `get_developing_count`
  /// 参照。ホーム画面のバッジ表示用)。
  Future<int> getDevelopingCount({required String groupId});
}
