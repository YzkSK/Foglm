import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/groups/application/create_event_group_controller.dart';
import 'package:foglm/features/groups/data/group_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockGroupRepository extends Mock implements GroupRepository {}

void main() {
  late MockGroupRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = MockGroupRepository();
    container = ProviderContainer(
      overrides: [groupRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  test('submit calls repository and resolves to data on success', () async {
    final startDate = DateTime(2026, 8);
    final endDate = DateTime(2026, 8, 3);
    when(
      () => repository.createEventGroup(
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
      () => repository.createEventGroup(
        name: 'My Trip',
        startDate: startDate,
        endDate: endDate,
      ),
    ).called(1);
  });

  test('submit exposes the repository failure as AsyncError', () async {
    final startDate = DateTime(2026, 8, 3);
    final endDate = DateTime(2026, 8);
    when(
      () => repository.createEventGroup(
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
}
