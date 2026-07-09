import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/groups/data/group_repository.dart';
import 'package:foglm/features/groups/presentation/invite_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockGroupRepository extends Mock implements GroupRepository {}

Widget _pumpApp(GroupRepository repository) {
  return ProviderScope(
    overrides: [groupRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(
      home: InviteScreen(groupId: 'group-1', groupName: 'テストグループ'),
    ),
  );
}

void main() {
  unawaited(
    goldenTest(
      'InviteScreen shows a loading indicator while issuing the code',
      fileName: 'invite_screen_loading',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async => tester.pump(),
      builder: () {
        final repository = _MockGroupRepository();
        when(
          () => repository.getInviteCode(groupId: 'group-1'),
        ).thenAnswer((_) => Completer<String?>().future);
        return _pumpApp(repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'InviteScreen shows the existing invite code',
      fileName: 'invite_screen_issued',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () {
        final repository = _MockGroupRepository();
        when(
          () => repository.getInviteCode(groupId: 'group-1'),
        ).thenAnswer((_) async => 'ABC123XYZ0');
        return _pumpApp(repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'InviteScreen shows a server error',
      fileName: 'invite_screen_error',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () {
        final repository = _MockGroupRepository();
        when(
          () => repository.getInviteCode(groupId: 'group-1'),
        ).thenThrow(Exception('unexpected'));
        return _pumpApp(repository);
      },
    ),
  );
}
