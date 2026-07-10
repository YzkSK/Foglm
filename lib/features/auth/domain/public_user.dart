import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_user.freezed.dart';

/// `public.users`テーブルの1行を表す(認証ガード判定に必要な列のみ)。
@freezed
abstract class PublicUserRow with _$PublicUserRow {
  const factory PublicUserRow({
    required String authProvider,
    required bool emailVerified,
    DateTime? profileCompletedAt,
  }) = _PublicUserRow;

  factory PublicUserRow.fromMap(Map<String, dynamic> map) {
    return PublicUserRow(
      authProvider: map['auth_provider'] as String,
      emailVerified: map['email_verified'] as bool,
      profileCompletedAt: _nullableDateTimeFromMap(map['profile_completed_at']),
    );
  }
}

DateTime? _nullableDateTimeFromMap(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  return DateTime.parse(value as String);
}
