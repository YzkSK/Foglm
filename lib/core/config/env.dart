/// ビルド時に `--dart-define` で注入する環境変数の窓口。
/// 値の管理方法は docs/setup/secrets.md を参照。
class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// `--dart-define=APP_PROFILE=dev` で指定するビルドプロファイル。
  /// devプロファイル限定の機能(デバッグ用画面等)の判定に使う。
  /// 詳細は docs/setup/debug-menu.md を参照。
  static const appProfile = String.fromEnvironment('APP_PROFILE');

  /// devプロファイルでビルド・実行されているかどうか。
  static bool get isDevProfile => appProfile == 'dev';
}
