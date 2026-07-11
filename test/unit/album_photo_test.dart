import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/album/domain/album_photo.dart';

void main() {
  group('AlbumPhotoRow.fromMap', () {
    test('parses a developed photo row', () {
      final row = AlbumPhotoRow.fromMap({
        'id': 'photo-1',
        'taken_at': '2026-07-10T12:00:00+00:00',
        'taken_date': '2026-07-10',
      });

      expect(row.id, 'photo-1');
      expect(row.takenAt, DateTime.parse('2026-07-10T12:00:00+00:00'));
      expect(row.takenDate, DateTime.parse('2026-07-10'));
    });
  });
}
