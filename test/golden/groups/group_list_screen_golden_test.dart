import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/groups/data/group_repository.dart';
import 'package:foglm/features/groups/data/my_groups_provider.dart';
import 'package:foglm/features/groups/domain/my_group.dart';
import 'package:foglm/features/groups/presentation/group_list_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockGroupRepository extends Mock implements GroupRepository {}

const _soloGroup = MyGroupRow(
  id: 'solo-1',
  name: '自分',
  mode: 'solo',
  status: 'active',
);
const _fixedGroup = MyGroupRow(
  id: 'group-1',
  name: '固定グループA',
  mode: 'group',
  status: 'active',
);
const _eventGroup = MyGroupRow(
  id: 'event-1',
  name: 'イベントグループB',
  mode: 'event',
  status: 'active',
);
const _archivedGroup = MyGroupRow(
  id: 'group-2',
  name: '固定グループC',
  mode: 'group',
  status: 'archived',
);

Widget _pumpApp({
  required List<MyGroupRow> groups,
  GroupRepository? repository,
}) {
  return ProviderScope(
    overrides: [
      groupRepositoryProvider.overrideWithValue(
        repository ?? _MockGroupRepository(),
      ),
      myGroupsProvider.overrideWith((ref) async => groups),
    ],
    child: const MaterialApp(home: GroupListScreen()),
  );
}

void main() {
  unawaited(
    goldenTest(
      'GroupListScreen shows the solo tile and other groups',
      fileName: 'group_list_screen_initial',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () => _pumpApp(groups: [_soloGroup, _fixedGroup, _eventGroup]),
    ),
  );

  unawaited(
    goldenTest(
      'GroupListScreen disables the tile for an archived group',
      fileName: 'group_list_screen_archived',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () => _pumpApp(groups: [_soloGroup, _archivedGroup]),
    ),
  );

  unawaited(
    goldenTest(
      'GroupListScreen shows an empty state when there are no other groups',
      fileName: 'group_list_screen_empty',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () => _pumpApp(groups: [_soloGroup]),
    ),
  );

  unawaited(
    goldenTest(
      'GroupListScreen shows the join dialog',
      fileName: 'group_list_screen_join_dialog',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        await tester.tap(find.text('招待コードで参加する'));
        await tester.pumpAndSettle();
      },
      builder: () => _pumpApp(groups: [_soloGroup]),
    ),
  );

  unawaited(
    goldenTest(
      'GroupListScreen shows a loading indicator',
      fileName: 'group_list_screen_loading',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async => tester.pump(),
      builder: () => ProviderScope(
        overrides: [
          groupRepositoryProvider.overrideWithValue(_MockGroupRepository()),
          myGroupsProvider.overrideWith(
            (ref) => Completer<List<MyGroupRow>>().future,
          ),
        ],
        child: const MaterialApp(home: GroupListScreen()),
      ),
    ),
  );

  unawaited(
    goldenTest(
      'GroupListScreen shows an error message',
      fileName: 'group_list_screen_error',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () => ProviderScope(
        overrides: [
          groupRepositoryProvider.overrideWithValue(_MockGroupRepository()),
          myGroupsProvider.overrideWith(
            (ref) => Future<List<MyGroupRow>>.error(Exception('unexpected')),
          ),
        ],
        child: const MaterialApp(home: GroupListScreen()),
      ),
    ),
  );
}
