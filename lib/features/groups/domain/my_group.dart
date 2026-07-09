import 'package:freezed_annotation/freezed_annotation.dart';

part 'my_group.freezed.dart';

/// `public.groups`テーブルの1行を表す(グループ一覧画面(S03)の表示に必要な列のみ)。
/// `mode`は`group`(固定グループ)・`solo`(ソロモード)・`event`(イベントグループ)、
/// `status`は`active`・`archived`(仕様書 5.1参照)。
@freezed
abstract class MyGroupRow with _$MyGroupRow {
  const factory MyGroupRow({
    required String id,
    required String name,
    required String mode,
    required String status,
    DateTime? startDate,
    DateTime? endDate,
  }) = _MyGroupRow;

  factory MyGroupRow.fromMap(Map<String, dynamic> map) {
    return MyGroupRow(
      id: map['id'] as String,
      name: map['name'] as String,
      mode: map['mode'] as String,
      status: map['status'] as String,
      // start_date/end_dateはPostgresのdate型(時刻・タイムゾーンを持たない)なので、
      // DateTime.parseは常にローカル時刻0時のDateTime(isUtc: false)を返す
      // (showDatePickerの戻り値と同じ表現)。UTCへの変換や、他のtimestamptz由来の
      // DateTimeとの単純な差分計算を行うと日付がずれる可能性があるため注意。
      startDate: map['start_date'] == null
          ? null
          : DateTime.parse(map['start_date'] as String),
      endDate: map['end_date'] == null
          ? null
          : DateTime.parse(map['end_date'] as String),
    );
  }
}
