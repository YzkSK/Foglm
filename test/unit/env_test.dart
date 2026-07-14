import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/core/config/env.dart';

void main() {
  group('Env.isDevProfile', () {
    test('is false when APP_PROFILE is not dev (default in tests)', () {
      // テスト実行時は --dart-define=APP_PROFILE=dev を渡していないため、
      // appProfileは空文字列になり、isDevProfileはfalseになる。
      expect(Env.appProfile, isNot('dev'));
      expect(Env.isDevProfile, isFalse);
    });
  });

  group('Env.isConfigured', () {
    test('is false when SUPABASE_URL/SUPABASE_ANON_KEY are not set', () {
      // テスト実行時は--dart-defineを渡していないため両方とも空文字列になり、
      // isConfiguredはfalseになる(#207: fail-fast判定の対象)。
      expect(Env.supabaseUrl, isEmpty);
      expect(Env.supabaseAnonKey, isEmpty);
      expect(Env.isConfigured, isFalse);
    });
  });
}
