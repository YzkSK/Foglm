import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_user.freezed.dart';

/// `public.users`テーブルの1行を表す(認証ガード判定に必要な列のみ)。
@freezed
abstract class PublicUserRow with _$PublicUserRow {
  const factory PublicUserRow({
    required String authProvider,
    required bool emailVerified,
  }) = _PublicUserRow;

  factory PublicUserRow.fromMap(Map<String, dynamic> map) {
    return PublicUserRow(
      authProvider: map['auth_provider'] as String,
      emailVerified: map['email_verified'] as bool,
    );
  }
}
