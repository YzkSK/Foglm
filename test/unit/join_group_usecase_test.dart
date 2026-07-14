import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/groups/application/usecase/join_group_usecase.dart';
import 'package:foglm/features/groups/domain/group_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockGroupRepository extends Mock implements GroupRepository {}

void main() {
  late MockGroupRepository repository;
  late JoinGroupUseCase useCase;

  setUp(() {
    repository = MockGroupRepository();
    useCase = JoinGroupUseCase(repository);
  });

  test('delegates to the repository', () async {
    when(
      () => repository.joinGroupByCode(code: 'ABC123'),
    ).thenAnswer((_) async {});

    await useCase.call(code: 'ABC123');

    verify(() => repository.joinGroupByCode(code: 'ABC123')).called(1);
  });

  test('propagates repository failures', () async {
    when(
      () => repository.joinGroupByCode(code: 'BADCODE'),
    ).thenThrow(Exception('invalid code'));

    expect(
      () => useCase.call(code: 'BADCODE'),
      throwsA(isA<Exception>()),
    );
  });
}
