import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/album/data/album_repository.dart';
import 'package:foglm/features/album/data/photo_url_repository.dart';
import 'package:foglm/features/album/domain/album_photo.dart';
import 'package:foglm/features/album/presentation/album_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockAlbumRepository extends Mock implements AlbumRepository {}

class MockPhotoUrlRepository extends Mock implements PhotoUrlRepository {}

void main() {
  late MockAlbumRepository albumRepository;
  late MockPhotoUrlRepository photoUrlRepository;

  setUp(() {
    albumRepository = MockAlbumRepository();
    photoUrlRepository = MockPhotoUrlRepository();
    when(
      () => photoUrlRepository.getPhotoUrl(photoId: any(named: 'photoId')),
    ).thenAnswer((_) async => '');
  });

  Future<void> pumpScreen(WidgetTester tester) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumRepositoryProvider.overrideWithValue(albumRepository),
          photoUrlRepositoryProvider.overrideWithValue(photoUrlRepository),
        ],
        child: const MaterialApp(home: AlbumScreen(groupId: 'group-1')),
      ),
    );
  }

  testWidgets('groups photos by taken date with the newest date first', (
    tester,
  ) async {
    when(() => albumRepository.getAlbum(groupId: 'group-1')).thenAnswer(
      (_) async => [
        AlbumPhotoRow(
          id: 'photo-1',
          takenAt: DateTime.utc(2026, 7, 10, 12),
          takenDate: DateTime.utc(2026, 7, 10),
        ),
        AlbumPhotoRow(
          id: 'photo-2',
          takenAt: DateTime.utc(2026, 7, 9, 12),
          takenDate: DateTime.utc(2026, 7, 9),
        ),
      ],
    );

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('2026/07/10'), findsOneWidget);
    expect(find.text('2026/07/09'), findsOneWidget);
  });

  testWidgets('shows an empty message when there are no photos', (
    tester,
  ) async {
    when(
      () => albumRepository.getAlbum(groupId: 'group-1'),
    ).thenAnswer((_) async => []);

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('まだ現像済みの写真がありません'), findsOneWidget);
  });

  testWidgets('shows an error message when the album fails to load', (
    tester,
  ) async {
    when(
      () => albumRepository.getAlbum(groupId: 'group-1'),
    ).thenThrow(Exception('unexpected'));

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('アルバムの取得に失敗しました'), findsOneWidget);
  });
}
