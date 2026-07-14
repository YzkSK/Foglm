import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/groups/application/create_group_controller.dart';
import 'package:foglm/features/groups/application/usecase/create_group_usecase.dart';
import 'package:foglm/features/groups/data/group_repository.dart'
    show groupRepositoryProvider;
import 'package:foglm/features/groups/domain/group_repository.dart'
    show GroupRepository;
import 'package:mocktail/mocktail.dart';

class MockCreateGroupUseCase extends Mock implements CreateGroupUseCase {}

class MockGroupRepository extends Mock implements GroupRepository {}

void main() {
  late MockCreateGroupUseCase useCase;
  late ProviderContainer container;

  setUp(() {
    useCase = MockCreateGroupUseCase();
    container = ProviderContainer(
      overrides: [createGroupUseCaseProvider.overrideWithValue(useCase)],
    );
    addTearDown(container.dispose);
  });

  test('submit calls the usecase and resolves to data on success', () async {
    when(
      () => useCase.call(name: 'My Group'),
    ).thenAnswer((_) async {});

    await container
        .read(createGroupControllerProvider.notifier)
        .submit(name: 'My Group');

    final state = container.read(createGroupControllerProvider);
    expect(state, const AsyncData<void>(null));
    verify(() => useCase.call(name: 'My Group')).called(1);
  });

  test('submit exposes the usecase failure as AsyncError', () async {
    when(
      () => useCase.call(name: ''),
    ).thenThrow(Exception('create_group: name must not be empty'));

    await container
        .read(createGroupControllerProvider.notifier)
        .submit(name: '');

    final state = container.read(createGroupControllerProvider);
    expect(state.hasError, isTrue);
  });

  group('default wiring', () {
    test(
      'createGroupControllerProvider uses the repository through the '
      'default usecase provider',
      () async {
        final repository = MockGroupRepository();
        final wiredContainer = ProviderContainer(
          overrides: [groupRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(wiredContainer.dispose);

        when(
          () => repository.createGroup(name: 'My Group'),
        ).thenAnswer((_) async {});

        await wiredContainer
            .read(createGroupControllerProvider.notifier)
            .submit(name: 'My Group');

        verify(() => repository.createGroup(name: 'My Group')).called(1);
      },
    );
  });
}
