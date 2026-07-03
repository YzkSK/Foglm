/// ビルド時に `--dart-define` で注入する環境変数の窓口。
/// 実際の値の管理方法は #48（環境変数・シークレット管理の整備）で確定する。
class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
