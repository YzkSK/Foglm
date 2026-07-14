import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/groups/application/usecase/get_my_groups_usecase.dart';
import 'package:foglm/features/groups/domain/group_repository.dart';
import 'package:foglm/features/groups/domain/my_group.dart';
import 'package:mocktail/mocktail.dart';

class MockGroupRepository extends Mock implements GroupRepository {}

void main() {
  late MockGroupRepository repository;
  late GetMyGroupsUseCase useCase;

  setUp(() {
    repository = MockGroupRepository();
    useCase = GetMyGroupsUseCase(repository);
  });

  test('delegates to the repository and returns its result', () async {
    const groups = [
      MyGroupRow(
        id: 'group-1',
        name: '固定グループ',
        mode: 'group',
        status: 'active',
      ),
    ];
    when(repository.getMyGroups).thenAnswer((_) async => groups);

    final result = await useCase.call();

    expect(result, groups);
    verify(repository.getMyGroups).called(1);
  });

  test('propagates repository failures', () async {
    when(repository.getMyGroups).thenThrow(Exception('unexpected'));

    expect(() => useCase.call(), throwsA(isA<Exception>()));
  });
}
