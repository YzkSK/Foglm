import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/groups/data/group_repository.dart';
import 'package:foglm/features/groups/domain/group_repository.dart';
import 'package:foglm/features/groups/presentation/leave_group_confirm_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockGroupRepository extends Mock implements GroupRepository {}

Widget _pumpApp(GroupRepository repository) {
  return ProviderScope(
    overrides: [groupRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(
      home: LeaveGroupConfirmScreen(
        groupId: 'group-1',
        groupName: 'テストグループ',
      ),
    ),
  );
}

void main() {
  unawaited(
    goldenTest(
      'LeaveGroupConfirmScreen shows the confirmation message',
      fileName: 'leave_group_confirm_screen_initial',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () => _pumpApp(_MockGroupRepository()),
    ),
  );

  unawaited(
    goldenTest(
      'LeaveGroupConfirmScreen shows a loading indicator while submitting',
      fileName: 'leave_group_confirm_screen_loading',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        await tester.tap(find.text('脱退する'));
        await tester.pump();
      },
      builder: () {
        final repository = _MockGroupRepository();
        when(
          () => repository.leaveGroup(groupId: 'group-1'),
        ).thenAnswer((_) => Completer<void>().future);
        return _pumpApp(repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'LeaveGroupConfirmScreen shows a server error',
      fileName: 'leave_group_confirm_screen_server_error',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        await tester.tap(find.text('脱退する'));
        await tester.pumpAndSettle();
      },
      builder: () {
        final repository = _MockGroupRepository();
        when(
          () => repository.leaveGroup(groupId: 'group-1'),
        ).thenThrow(Exception('unexpected'));
        return _pumpApp(repository);
      },
    ),
  );
}
