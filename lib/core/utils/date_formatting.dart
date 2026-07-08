/// 時刻・タイムゾーンを含まない日付文字列(`yyyy<separator>MM<separator>dd`)を
/// 組み立てる。RPCパラメータ用(`-`区切り)・画面表示用(`/`区切り)などで共用する。
String formatDateOnly(DateTime date, {String separator = '-'}) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year$separator$month$separator$day';
}
