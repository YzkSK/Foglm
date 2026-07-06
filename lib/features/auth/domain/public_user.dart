/// `public.users`テーブルの1行を表す(認証ガード判定に必要な列のみ)。
class PublicUserRow {
  const PublicUserRow({
    required this.authProvider,
    required this.emailVerified,
  });

  factory PublicUserRow.fromMap(Map<String, dynamic> map) {
    return PublicUserRow(
      authProvider: map['auth_provider'] as String,
      emailVerified: map['email_verified'] as bool,
    );
  }

  final String authProvider;
  final bool emailVerified;
}
