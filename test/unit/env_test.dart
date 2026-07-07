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
}
