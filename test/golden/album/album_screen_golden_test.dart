import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/album/data/album_repository.dart';
import 'package:foglm/features/album/data/photo_url_repository.dart';
import 'package:foglm/features/album/domain/album_photo.dart';
import 'package:foglm/features/album/presentation/album_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockAlbumRepository extends Mock implements AlbumRepository {}

class _MockPhotoUrlRepository extends Mock implements PhotoUrlRepository {}

Widget _pumpApp({
  AlbumRepository? albumRepository,
  PhotoUrlRepository? photoUrlRepository,
}) {
  final photoUrl = photoUrlRepository ?? _MockPhotoUrlRepository();
  if (photoUrl is _MockPhotoUrlRepository) {
    when(
      () => photoUrl.getPhotoUrl(photoId: any(named: 'photoId')),
    ).thenAnswer((_) async => '');
  }
  return ProviderScope(
    overrides: [
      albumRepositoryProvider.overrideWithValue(
        albumRepository ?? _MockAlbumRepository(),
      ),
      photoUrlRepositoryProvider.overrideWithValue(photoUrl),
    ],
    child: const MaterialApp(home: AlbumScreen(groupId: 'test-group-id')),
  );
}

void main() {
  unawaited(
    goldenTest(
      'AlbumScreen shows a loading indicator',
      fileName: 'album_screen_loading',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: pumpNTimes(10),
      builder: () {
        final repository = _MockAlbumRepository();
        when(
          () => repository.getAlbum(groupId: 'test-group-id'),
        ).thenAnswer((_) => Completer<List<AlbumPhotoRow>>().future);
        return _pumpApp(albumRepository: repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'AlbumScreen shows an error state',
      fileName: 'album_screen_error',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () {
        final repository = _MockAlbumRepository();
        when(
          () => repository.getAlbum(groupId: 'test-group-id'),
        ).thenThrow(Exception('unexpected'));
        return _pumpApp(albumRepository: repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'AlbumScreen shows an empty state',
      fileName: 'album_screen_empty',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () {
        final repository = _MockAlbumRepository();
        when(
          () => repository.getAlbum(groupId: 'test-group-id'),
        ).thenAnswer((_) async => []);
        return _pumpApp(albumRepository: repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'AlbumScreen shows photos grouped by taken date',
      fileName: 'album_screen_normal',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 900),
      builder: () {
        final repository = _MockAlbumRepository();
        when(
          () => repository.getAlbum(groupId: 'test-group-id'),
        ).thenAnswer(
          (_) async => [
            AlbumPhotoRow(
              id: 'photo-1',
              takenAt: DateTime.utc(2026, 7, 10, 12),
              takenDate: DateTime.utc(2026, 7, 10),
            ),
            AlbumPhotoRow(
              id: 'photo-2',
              takenAt: DateTime.utc(2026, 7, 10, 9),
              takenDate: DateTime.utc(2026, 7, 10),
            ),
            AlbumPhotoRow(
              id: 'photo-3',
              takenAt: DateTime.utc(2026, 7, 9, 12),
              takenDate: DateTime.utc(2026, 7, 9),
            ),
          ],
        );
        return _pumpApp(albumRepository: repository);
      },
    ),
  );
}
