import 'package:foglm/features/auth/domain/public_user.dart';

/// メール・パスワード方式かつ未確認のユーザーでも遷移を許可するパス。
/// 撮影・投票・アルバム閲覧などの主要機能画面は今後の別issueで追加され次第、
/// この一覧に含めない(=自動的にガード対象になる)想定。
const allowedWhenUnverifiedPaths = {
  '/',
  '/signup',
  '/verify-pending',
  '/debug',
};

/// 未ログインでもアクセス可能なパス。ログイン必須の画面は今後の別issueで
/// 追加され次第、この一覧に含めない(=自動的にガード対象になる)想定。
const allowedWhenUnauthenticatedPaths = {
  '/',
  '/signup',
  '/verify-pending',
  '/password-reset',
  '/reset-password',
  '/debug',
};

/// 初回プロフィール設定(S02)未完了のユーザーでも遷移を許可するパス。
/// 撮影・投票・アルバム閲覧などの主要機能画面は今後の別issueで追加され次第、
/// この一覧に含めない(=自動的にガード対象になる)想定。
/// `'/'`は含めない: ログイン済みユーザーが`'/'`(ログイン画面)へ着地した際に
/// プロフィール設定画面へ自動的にリダイレクトさせるため
/// (`allowedWhenUnverifiedPaths`と異なり、こちらは新規追加のガードなので
/// この動作を最初から正しくする)。
const allowedWhenProfileIncompletePaths = {
  '/signup',
  '/verify-pending',
  '/password-reset',
  '/reset-password',
  '/profile/setup',
  '/debug',
};

/// 未ログイン(または`public.users`に対応する行が存在しない)ユーザーが
/// 許可リスト外の画面へ遷移しようとした場合、ログイン画面('/')へリダイレクトする
/// (仕様書 3.1.1 / 6.1 sign_out参照)。
/// `isLoading`が`true`の間(ユーザー情報の取得が未確定)は、未ログインと確定するまで
/// リダイレクトを保留する(セッション復元中の認証済みユーザーを誤って弾かないため)。
String? authRequiredRedirect({
  required PublicUserRow? user,
  required bool isLoading,
  required String location,
}) {
  if (user != null || isLoading) {
    return null;
  }
  if (allowedWhenUnauthenticatedPaths.contains(location)) {
    return null;
  }
  return '/';
}

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

/// 初回プロフィール設定(S02)未完了ユーザーの機能制限(仕様書 3.1 / 4.2参照)。
/// `profile_completed_at`が未設定のユーザーが許可リスト外の画面へ遷移しようと
/// した場合、プロフィール初期設定画面へリダイレクトする。
String? profileSetupRedirect({
  required PublicUserRow? user,
  required String location,
}) {
  if (user == null || user.profileCompletedAt != null) {
    return null;
  }
  if (allowedWhenProfileIncompletePaths.contains(location)) {
    return null;
  }
  return '/profile/setup';
}
