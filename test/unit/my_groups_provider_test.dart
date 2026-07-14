import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/groups/application/my_groups_provider.dart';
import 'package:foglm/features/groups/application/usecase/get_my_groups_usecase.dart';
import 'package:foglm/features/groups/data/group_repository.dart'
    show groupRepositoryProvider;
import 'package:foglm/features/groups/domain/group_repository.dart'
    show GroupRepository;
import 'package:foglm/features/groups/domain/my_group.dart';
import 'package:mocktail/mocktail.dart';

class MockGetMyGroupsUseCase extends Mock implements GetMyGroupsUseCase {}

class MockGroupRepository extends Mock implements GroupRepository {}

void main() {
  late MockGetMyGroupsUseCase useCase;
  late ProviderContainer container;

  setUp(() {
    useCase = MockGetMyGroupsUseCase();
    container = ProviderContainer(
      overrides: [getMyGroupsUseCaseProvider.overrideWithValue(useCase)],
    );
    addTearDown(container.dispose);
  });

  test('resolves to the groups returned by the usecase', () async {
    const groups = [
      MyGroupRow(
        id: 'group-1',
        name: '固定グループ',
        mode: 'group',
        status: 'active',
      ),
    ];
    when(useCase.call).thenAnswer((_) async => groups);

    final result = await container.read(myGroupsProvider.future);

    expect(result, groups);
    verify(useCase.call).called(1);
  });

  test('exposes the usecase failure as AsyncError', () async {
    when(useCase.call).thenAnswer(
      (_) => Future<List<MyGroupRow>>.error(Exception('unexpected')),
    );

    final subscription = container.listen(myGroupsProvider, (_, _) {});
    addTearDown(subscription.close);

    await pumpEventQueue();

    expect(container.read(myGroupsProvider).hasError, isTrue);
  });

  group('default wiring', () {
    test(
      'myGroupsProvider uses the repository through the default usecase '
      'provider',
      () async {
        final repository = MockGroupRepository();
        final wiredContainer = ProviderContainer(
          overrides: [groupRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(wiredContainer.dispose);

        when(repository.getMyGroups).thenAnswer((_) async => []);

        await wiredContainer.read(myGroupsProvider.future);

        verify(repository.getMyGroups).called(1);
      },
    );
  });
}
