import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/groups/application/create_event_group_controller.dart';
import 'package:foglm/features/groups/application/usecase/create_event_group_usecase.dart';
import 'package:foglm/features/groups/data/group_repository.dart'
    show groupRepositoryProvider;
import 'package:foglm/features/groups/domain/group_repository.dart'
    show GroupRepository;
import 'package:mocktail/mocktail.dart';

class MockCreateEventGroupUseCase extends Mock
    implements CreateEventGroupUseCase {}

class MockGroupRepository extends Mock implements GroupRepository {}

void main() {
  late MockCreateEventGroupUseCase useCase;
  late ProviderContainer container;

  setUp(() {
    useCase = MockCreateEventGroupUseCase();
    container = ProviderContainer(
      overrides: [
        createEventGroupUseCaseProvider.overrideWithValue(useCase),
      ],
    );
    addTearDown(container.dispose);
  });

  test('submit calls the usecase and resolves to data on success', () async {
    final startDate = DateTime(2026, 8);
    final endDate = DateTime(2026, 8, 3);
    when(
      () => useCase.call(
        name: 'My Trip',
        startDate: startDate,
        endDate: endDate,
      ),
    ).thenAnswer((_) async {});

    await container
        .read(createEventGroupControllerProvider.notifier)
        .submit(name: 'My Trip', startDate: startDate, endDate: endDate);

    final state = container.read(createEventGroupControllerProvider);
    expect(state, const AsyncData<void>(null));
    verify(
      () => useCase.call(
        name: 'My Trip',
        startDate: startDate,
        endDate: endDate,
      ),
    ).called(1);
  });

  test('submit exposes the usecase failure as AsyncError', () async {
    final startDate = DateTime(2026, 8, 3);
    final endDate = DateTime(2026, 8);
    when(
      () => useCase.call(
        name: 'My Trip',
        startDate: startDate,
        endDate: endDate,
      ),
    ).thenThrow(
      Exception('create_event_group: end_date must not be before start_date'),
    );

    await container
        .read(createEventGroupControllerProvider.notifier)
        .submit(name: 'My Trip', startDate: startDate, endDate: endDate);

    final state = container.read(createEventGroupControllerProvider);
    expect(state.hasError, isTrue);
  });

  group('default wiring', () {
    test(
      'createEventGroupControllerProvider uses the repository through the '
      'default usecase provider',
      () async {
        final repository = MockGroupRepository();
        final wiredContainer = ProviderContainer(
          overrides: [groupRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(wiredContainer.dispose);
        final startDate = DateTime(2026, 8);
        final endDate = DateTime(2026, 8, 3);

        when(
          () => repository.createEventGroup(
            name: 'My Trip',
            startDate: startDate,
            endDate: endDate,
          ),
        ).thenAnswer((_) async {});

        await wiredContainer
            .read(createEventGroupControllerProvider.notifier)
            .submit(name: 'My Trip', startDate: startDate, endDate: endDate);

        verify(
          () => repository.createEventGroup(
            name: 'My Trip',
            startDate: startDate,
            endDate: endDate,
          ),
        ).called(1);
      },
    );
  });
}
