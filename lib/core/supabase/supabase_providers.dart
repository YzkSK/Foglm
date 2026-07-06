import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// アプリ全体で共有するSupabaseクライアント。
/// `main.dart`で`Supabase.initialize`が完了していることを前提とする。
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
