import 'package:foglm/features/auth/domain/public_user.dart';

/// メール・パスワード方式かつ未確認のユーザーでも遷移を許可するパス。
/// 撮影・投票・アルバム閲覧などの主要機能画面は今後の別issueで追加され次第、
/// この一覧に含めない(=自動的にガード対象になる)想定。
const allowedWhenUnverifiedPaths = {'/', '/signup', '/verify-pending'};

/// 未確認ユーザーの機能制限(仕様書 3.1・6.1参照)。
/// メール・パスワード方式で`email_verified = false`のユーザーが許可リスト外の画面へ
/// 遷移しようとした場合、確認待ち画面へリダイレクトする。
String? emailVerificationRedirect({
  required PublicUserRow? user,
  required String location,
}) {
  if (user == null) {
    return null;
  }
  if (user.authProvider != 'email' || user.emailVerified) {
    return null;
  }
  if (allowedWhenUnverifiedPaths.contains(location)) {
    return null;
  }
  return '/verify-pending';
}
