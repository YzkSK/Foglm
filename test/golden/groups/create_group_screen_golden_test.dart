import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/groups/data/group_repository.dart';
import 'package:foglm/features/groups/presentation/create_group_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockGroupRepository extends Mock implements GroupRepository {}

Widget _pumpApp(GroupRepository repository) {
  return ProviderScope(
    overrides: [groupRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: CreateGroupScreen()),
  );
}

Future<void> _enterName(WidgetTester tester, String name) async {
  await tester.enterText(find.byType(TextFormField), name);
}

void main() {
  unawaited(
    goldenTest(
      'CreateGroupScreen shows the initial empty form',
      fileName: 'create_group_screen_initial',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () => _pumpApp(_MockGroupRepository()),
    ),
  );

  unawaited(
    goldenTest(
      'CreateGroupScreen shows a validation error',
      fileName: 'create_group_screen_validation_error',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        await tester.tap(find.text('作成する'));
        await tester.pumpAndSettle();
      },
      builder: () => _pumpApp(_MockGroupRepository()),
    ),
  );

  unawaited(
    goldenTest(
      'CreateGroupScreen shows a loading indicator while submitting',
      fileName: 'create_group_screen_loading',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await _enterName(tester, 'My Group');
        await tester.tap(find.text('作成する'));
        await tester.pump();
      },
      builder: () {
        final repository = _MockGroupRepository();
        when(
          () => repository.createGroup(name: 'My Group'),
        ).thenAnswer((_) => Completer<void>().future);
        return _pumpApp(repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'CreateGroupScreen shows a server error',
      fileName: 'create_group_screen_server_error',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await _enterName(tester, 'My Group');
        await tester.tap(find.text('作成する'));
        await tester.pumpAndSettle();
      },
      builder: () {
        final repository = _MockGroupRepository();
        when(
          () => repository.createGroup(name: 'My Group'),
        ).thenThrow(Exception('unexpected'));
        return _pumpApp(repository);
      },
    ),
  );
}
