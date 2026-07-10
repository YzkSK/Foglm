import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/core/utils/date_formatting.dart';

void main() {
  group('formatDateOnly', () {
    test('pads single-digit month/day with a leading zero', () {
      expect(formatDateOnly(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('supports a custom separator', () {
      expect(
        formatDateOnly(DateTime(2026, 1, 5), separator: '/'),
        '2026/01/05',
      );
    });
  });

  group('todayInAsiaTokyo', () {
    test('stays on the same day when UTC time is well before the '
        'JST midnight boundary', () {
      // UTC 2026-07-10 10:00 = JST 2026-07-10 19:00
      final now = DateTime.utc(2026, 7, 10, 10);
      expect(todayInAsiaTokyo(now), '2026-07-10');
    });

    test('rolls over to the next day at the UTC 15:00 JST-midnight '
        'boundary', () {
      // UTC 2026-07-10 15:00 = JST 2026-07-11 00:00
      final now = DateTime.utc(2026, 7, 10, 15);
      expect(todayInAsiaTokyo(now), '2026-07-11');
    });

    test('stays on the previous day one second before the boundary', () {
      // UTC 2026-07-10 14:59:59 = JST 2026-07-10 23:59:59
      final now = DateTime.utc(2026, 7, 10, 14, 59, 59);
      expect(todayInAsiaTokyo(now), '2026-07-10');
    });

    test('handles a JST year boundary correctly', () {
      // UTC 2025-12-31 15:00 = JST 2026-01-01 00:00
      final now = DateTime.utc(2025, 12, 31, 15);
      expect(todayInAsiaTokyo(now), '2026-01-01');
    });
  });
}
