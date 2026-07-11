import 'package:freezed_annotation/freezed_annotation.dart';

part 'album_photo.freezed.dart';

/// 現像済み写真の1件(仕様書 3.6 / 3.7 / 6.5 `get_album`参照)。
/// アルバム画面(S09)は一覧表示のみを担い、原本の署名付きURLは写真詳細
/// 画面(S10)で`get-photo-url` Edge Functionから個別に取得する想定のため、
/// ここではURLを持たない(原本はauthenticatedロール向けのSELECTポリシーが
/// 存在せず、service_role経由のEdge Functionでしか発行できないため)。
@freezed
abstract class AlbumPhotoRow with _$AlbumPhotoRow {
  const factory AlbumPhotoRow({
    required String id,
    required DateTime takenAt,
    required DateTime takenDate,
  }) = _AlbumPhotoRow;

  factory AlbumPhotoRow.fromMap(Map<String, dynamic> map) {
    return AlbumPhotoRow(
      id: map['id'] as String,
      takenAt: DateTime.parse(map['taken_at'] as String),
      takenDate: DateTime.parse(map['taken_date'] as String),
    );
  }
}
