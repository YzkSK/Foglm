import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/album/application/album_provider.dart';
import 'package:foglm/features/album/application/usecase/get_album_usecase.dart';
import 'package:foglm/features/album/application/usecase/get_developing_count_usecase.dart';
import 'package:foglm/features/album/data/album_repository.dart';
import 'package:foglm/features/album/domain/album_photo.dart';
import 'package:foglm/features/album/domain/album_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAlbumUseCase extends Mock implements GetAlbumUseCase {}

class MockGetDevelopingCountUseCase extends Mock
    implements GetDevelopingCountUseCase {}

class MockAlbumRepository extends Mock implements AlbumRepository {}

void main() {
  late MockGetAlbumUseCase getAlbumUseCase;
  late MockGetDevelopingCountUseCase getDevelopingCountUseCase;
  late ProviderContainer container;

  setUp(() {
    getAlbumUseCase = MockGetAlbumUseCase();
    getDevelopingCountUseCase = MockGetDevelopingCountUseCase();
    container = ProviderContainer(
      overrides: [
        getAlbumUseCaseProvider.overrideWithValue(getAlbumUseCase),
        getDevelopingCountUseCaseProvider.overrideWithValue(
          getDevelopingCountUseCase,
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  group('albumProvider', () {
    test('resolves to the photos returned by the usecase', () async {
      final photos = [
        AlbumPhotoRow(
          id: 'photo-1',
          takenAt: DateTime.utc(2026, 7, 10, 12),
          takenDate: DateTime.utc(2026, 7, 10),
        ),
      ];
      when(
        () => getAlbumUseCase.call(groupId: 'group-1'),
      ).thenAnswer((_) async => photos);

      final result = await container.read(albumProvider('group-1').future);

      expect(result, photos);
      verify(() => getAlbumUseCase.call(groupId: 'group-1')).called(1);
    });

    test('requests the album independently per groupId', () async {
      when(
        () => getAlbumUseCase.call(groupId: any(named: 'groupId')),
      ).thenAnswer((_) async => []);

      await container.read(albumProvider('group-1').future);
      await container.read(albumProvider('group-2').future);

      verify(() => getAlbumUseCase.call(groupId: 'group-1')).called(1);
      verify(() => getAlbumUseCase.call(groupId: 'group-2')).called(1);
    });

    test('exposes the usecase failure as AsyncError', () async {
      when(() => getAlbumUseCase.call(groupId: 'group-1')).thenAnswer(
        (_) => Future<List<AlbumPhotoRow>>.error(Exception('unexpected')),
      );

      final subscription = container.listen(
        albumProvider('group-1'),
        (_, _) {},
      );
      addTearDown(subscription.close);

      await pumpEventQueue();

      expect(container.read(albumProvider('group-1')).hasError, isTrue);
    });
  });

  group('developingCountProvider', () {
    test('resolves to the count returned by the usecase', () async {
      when(
        () => getDevelopingCountUseCase.call(groupId: 'group-1'),
      ).thenAnswer((_) async => 3);

      final result = await container.read(
        developingCountProvider('group-1').future,
      );

      expect(result, 3);
    });

    test('exposes the usecase failure as AsyncError', () async {
      when(
        () => getDevelopingCountUseCase.call(groupId: 'group-1'),
      ).thenAnswer((_) => Future<int>.error(Exception('unexpected')));

      final subscription = container.listen(
        developingCountProvider('group-1'),
        (_, _) {},
      );
      addTearDown(subscription.close);

      await pumpEventQueue();

      expect(
        container.read(developingCountProvider('group-1')).hasError,
        isTrue,
      );
    });
  });

  group('default wiring', () {
    test(
      'albumProvider uses the repository through the default usecase '
      'provider',
      () async {
        final repository = MockAlbumRepository();
        final wiredContainer = ProviderContainer(
          overrides: [albumRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(wiredContainer.dispose);

        when(
          () => repository.getAlbum(groupId: 'group-1'),
        ).thenAnswer((_) async => []);

        await wiredContainer.read(albumProvider('group-1').future);

        verify(() => repository.getAlbum(groupId: 'group-1')).called(1);
      },
    );

    test(
      'developingCountProvider uses the repository through the default '
      'usecase provider',
      () async {
        final repository = MockAlbumRepository();
        final wiredContainer = ProviderContainer(
          overrides: [albumRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(wiredContainer.dispose);

        when(
          () => repository.getDevelopingCount(groupId: 'group-1'),
        ).thenAnswer((_) async => 0);

        await wiredContainer.read(developingCountProvider('group-1').future);

        verify(
          () => repository.getDevelopingCount(groupId: 'group-1'),
        ).called(1);
      },
    );
  });
}
