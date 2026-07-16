import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/groups/application/my_groups_provider.dart';
import 'package:foglm/features/groups/data/group_repository.dart';
import 'package:foglm/features/groups/domain/my_group.dart';
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

  test('resolves to the groups returned by the repository', () async {
    const groups = [
      MyGroupRow(
        id: 'group-1',
        name: '固定グループ',
        mode: 'group',
        status: 'active',
      ),
    ];
    when(() => repository.getMyGroups()).thenAnswer((_) async => groups);

    final result = await container.read(myGroupsProvider.future);

    expect(result, groups);
    verify(() => repository.getMyGroups()).called(1);
  });

  test('exposes the repository failure as AsyncError', () async {
    when(() => repository.getMyGroups()).thenAnswer(
      (_) => Future<List<MyGroupRow>>.error(Exception('unexpected')),
    );

    final subscription = container.listen(myGroupsProvider, (_, _) {});
    addTearDown(subscription.close);

    await pumpEventQueue();

    expect(container.read(myGroupsProvider).hasError, isTrue);
  });
}
