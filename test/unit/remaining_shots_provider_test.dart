import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/camera/application/remaining_shots_provider.dart';
import 'package:foglm/features/camera/application/usecase/watch_remaining_shots_usecase.dart';
import 'package:foglm/features/camera/data/remaining_shots_repository.dart';
import 'package:foglm/features/camera/domain/remaining_shots_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockWatchRemainingShotsUseCase extends Mock
    implements WatchRemainingShotsUseCase {}

class MockRemainingShotsRepository extends Mock
    implements RemainingShotsRepository {}

void main() {
  late MockWatchRemainingShotsUseCase useCase;
  late ProviderContainer container;

  setUp(() {
    useCase = MockWatchRemainingShotsUseCase();
    container = ProviderContainer(
      overrides: [
        watchRemainingShotsUseCaseProvider.overrideWithValue(useCase),
      ],
    );
    addTearDown(container.dispose);
  });

  group('remainingShotsProvider', () {
    test('resolves to the values streamed by the usecase', () async {
      when(
        () => useCase.call(groupId: 'group-1'),
      ).thenAnswer((_) => Stream.value(10));

      // StreamProviderはautoDisposeのため、listenでの購読を維持しないと
      // .future待機中にプロバイダが破棄され値を受け取れないまま止まる。
      final subscription = container.listen(
        remainingShotsProvider('group-1'),
        (_, _) {},
      );
      addTearDown(subscription.close);

      final result = await container.read(
        remainingShotsProvider('group-1').future,
      );

      expect(result, 10);
      verify(() => useCase.call(groupId: 'group-1')).called(1);
    });

    test('exposes the usecase failure as AsyncError', () async {
      when(
        () => useCase.call(groupId: 'group-1'),
      ).thenAnswer((_) => Stream<int>.error(Exception('unexpected')));

      final subscription = container.listen(
        remainingShotsProvider('group-1'),
        (_, _) {},
      );
      addTearDown(subscription.close);

      await pumpEventQueue();

      expect(
        container.read(remainingShotsProvider('group-1')).hasError,
        isTrue,
      );
    });
  });

  group('default wiring', () {
    test(
      'remainingShotsProvider uses the repository through the default '
      'usecase provider',
      () async {
        final repository = MockRemainingShotsRepository();
        final wiredContainer = ProviderContainer(
          overrides: [
            remainingShotsRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(wiredContainer.dispose);

        when(
          () => repository.watchTodayShotsRemaining(groupId: 'group-1'),
        ).thenAnswer((_) => Stream.value(5));

        final subscription = wiredContainer.listen(
          remainingShotsProvider('group-1'),
          (_, _) {},
        );
        addTearDown(subscription.close);

        final result = await wiredContainer.read(
          remainingShotsProvider('group-1').future,
        );

        expect(result, 5);
        verify(
          () => repository.watchTodayShotsRemaining(groupId: 'group-1'),
        ).called(1);
      },
    );
  });
}
