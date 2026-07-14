import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/groups/application/usecase/create_event_group_usecase.dart';
import 'package:foglm/features/groups/domain/group_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockGroupRepository extends Mock implements GroupRepository {}

void main() {
  late MockGroupRepository repository;
  late CreateEventGroupUseCase useCase;

  setUp(() {
    repository = MockGroupRepository();
    useCase = CreateEventGroupUseCase(repository);
  });

  test('delegates to the repository', () async {
    final startDate = DateTime(2026, 8);
    final endDate = DateTime(2026, 8, 3);
    when(
      () => repository.createEventGroup(
        name: 'My Trip',
        startDate: startDate,
        endDate: endDate,
      ),
    ).thenAnswer((_) async {});

    await useCase.call(
      name: 'My Trip',
      startDate: startDate,
      endDate: endDate,
    );

    verify(
      () => repository.createEventGroup(
        name: 'My Trip',
        startDate: startDate,
        endDate: endDate,
      ),
    ).called(1);
  });

  test('propagates repository failures', () async {
    final startDate = DateTime(2026, 8, 3);
    final endDate = DateTime(2026, 8);
    when(
      () => repository.createEventGroup(
        name: 'My Trip',
        startDate: startDate,
        endDate: endDate,
      ),
    ).thenThrow(Exception('unexpected'));

    expect(
      () => useCase.call(
        name: 'My Trip',
        startDate: startDate,
        endDate: endDate,
      ),
      throwsA(isA<Exception>()),
    );
  });
}
