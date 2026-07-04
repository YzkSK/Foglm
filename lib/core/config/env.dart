/// ビルド時に `--dart-define` で注入する環境変数の窓口。
/// 値の管理方法は docs/setup/secrets.md を参照。
class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
