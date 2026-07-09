import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/groups/domain/my_group.dart';

void main() {
  group('MyGroupRow.fromMap', () {
    test('parses a fixed group row without start/end dates', () {
      final row = MyGroupRow.fromMap({
        'id': 'group-1',
        'name': 'テストグループ',
        'mode': 'group',
        'status': 'active',
        'start_date': null,
        'end_date': null,
      });

      expect(row.id, 'group-1');
      expect(row.name, 'テストグループ');
      expect(row.mode, 'group');
      expect(row.status, 'active');
      expect(row.startDate, isNull);
      expect(row.endDate, isNull);
    });

    test('parses an event group row with start/end dates', () {
      final row = MyGroupRow.fromMap({
        'id': 'event-1',
        'name': 'イベントグループ',
        'mode': 'event',
        'status': 'archived',
        'start_date': '2026-07-01',
        'end_date': '2026-07-07',
      });

      expect(row.mode, 'event');
      expect(row.status, 'archived');
      expect(row.startDate, DateTime.parse('2026-07-01'));
      expect(row.endDate, DateTime.parse('2026-07-07'));
    });
  });
}
