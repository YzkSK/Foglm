import 'package:supabase_flutter/supabase_flutter.dart';

/// 写真アップロード失敗時のアプリ内エラー種別(仕様書 5.2.2/8.1参照)。
sealed class UploadPhotoFailure implements Exception {
  const UploadPhotoFailure();
}

/// その日の撮影上限に達している(仕様書 3.3/5.2.2参照)。
class DailyLimitReachedFailure extends UploadPhotoFailure {
  const DailyLimitReachedFailure();
}

/// グループがアーカイブ済みで新規撮影を受け付けない(仕様書 3.2.1参照)。
class GroupArchivedFailure extends UploadPhotoFailure {
  const GroupArchivedFailure();
}

/// 撮影時点で既にグループの現役メンバーでなくなっている。
class NotActiveMemberFailure extends UploadPhotoFailure {
  const NotActiveMemberFailure();
}

class UnknownUploadPhotoFailure extends UploadPhotoFailure {
  const UnknownUploadPhotoFailure();
}

/// Edge Function `upload-photo`が返す`FunctionException`を
/// アプリ内の`UploadPhotoFailure`に変換する。
UploadPhotoFailure mapFunctionExceptionToUploadPhotoFailure(
  FunctionException e,
) {
  final details = e.details;
  final errorCode = details is Map ? details['error'] as String? : null;

  switch (errorCode) {
    case 'daily_limit_reached':
      return const DailyLimitReachedFailure();
    case 'group_archived':
      return const GroupArchivedFailure();
    case 'not_active_member':
      return const NotActiveMemberFailure();
    default:
      return const UnknownUploadPhotoFailure();
  }
}
