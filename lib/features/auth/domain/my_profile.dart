import 'package:freezed_annotation/freezed_annotation.dart';

part 'my_profile.freezed.dart';

/// `public.users`テーブルの1行を表す(プロフィール編集画面の表示・編集に必要な列のみ)。
@freezed
abstract class MyProfileRow with _$MyProfileRow {
  const factory MyProfileRow({
    required String displayName,
    String? avatarUrl,
  }) = _MyProfileRow;

  factory MyProfileRow.fromMap(Map<String, dynamic> map) {
    return MyProfileRow(
      displayName: map['display_name'] as String,
      avatarUrl: map['avatar_url'] as String?,
    );
  }
}
