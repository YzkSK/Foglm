import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/groups/application/create_group_controller.dart';
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
    when(
      () => repository.createGroup(name: 'My Group'),
    ).thenAnswer((_) async {});

    await container
        .read(createGroupControllerProvider.notifier)
        .submit(name: 'My Group');

    final state = container.read(createGroupControllerProvider);
    expect(state, const AsyncData<void>(null));
    verify(() => repository.createGroup(name: 'My Group')).called(1);
  });

  test('submit exposes the repository failure as AsyncError', () async {
    when(
      () => repository.createGroup(name: ''),
    ).thenThrow(Exception('create_group: name must not be empty'));

    await container
        .read(createGroupControllerProvider.notifier)
        .submit(name: '');

    final state = container.read(createGroupControllerProvider);
    expect(state.hasError, isTrue);
  });
}
