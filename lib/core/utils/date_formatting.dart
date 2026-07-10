/// 時刻・タイムゾーンを含まない日付文字列(`yyyy<separator>MM<separator>dd`)を
/// 組み立てる。RPCパラメータ用(`-`区切り)・画面表示用(`/`区切り)などで共用する。
String formatDateOnly(DateTime date, {String separator = '-'}) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year$separator$month$separator$day';
}

/// [now](省略時は現在時刻)を日本時間(Asia/Tokyo)の日付文字列(`yyyy-MM-dd`)に
/// 変換する。日本時間はDST(サマータイム)を持たないため、UTC+9の固定オフセットで
/// 計算してよい(`photos.taken_date`を算出するDBトリガー
/// `check_photo_daily_limit`と同じ基準に揃える必要がある)。
/// `now`を引数化しているのは、日付境界(UTC 15:00前後)のテストを
/// 時刻注入で書けるようにするため(`docs/testing-policy.md`参照)。
String todayInAsiaTokyo([DateTime? now]) {
  final jst = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 9));
  return formatDateOnly(jst);
}
