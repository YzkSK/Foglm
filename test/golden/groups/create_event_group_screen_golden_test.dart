import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/groups/data/group_repository.dart';
import 'package:foglm/features/groups/presentation/create_event_group_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockGroupRepository extends Mock implements GroupRepository {}

Widget _pumpApp(GroupRepository repository) {
  return ProviderScope(
    overrides: [groupRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: CreateEventGroupScreen()),
  );
}

/// 開始日・終了日ともに「今日」を選択する(月をまたぐナビゲーション操作を
/// 避けるため、常に確実にカレンダー上に表示されている日付を使う)。
Future<void> _pickTodayAsStartAndEnd(WidgetTester tester) async {
  final today = DateTime.now().day.toString();

  await tester.tap(find.text('開始日を選択'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(today).last);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('終了日を選択'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(today).last);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  unawaited(
    goldenTest(
      'CreateEventGroupScreen shows the initial empty form',
      fileName: 'create_event_group_screen_initial',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () => _pumpApp(_MockGroupRepository()),
    ),
  );

  unawaited(
    goldenTest(
      'CreateEventGroupScreen shows validation errors',
      fileName: 'create_event_group_screen_validation_error',
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
      'CreateEventGroupScreen shows a loading indicator while submitting',
      fileName: 'create_event_group_screen_loading',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.enterText(find.byType(TextFormField), 'My Trip');
        await _pickTodayAsStartAndEnd(tester);
        await tester.tap(find.text('作成する'));
        await tester.pump();
      },
      builder: () {
        final repository = _MockGroupRepository();
        when(
          () => repository.createEventGroup(
            name: 'My Trip',
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) => Completer<void>().future);
        return _pumpApp(repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'CreateEventGroupScreen shows a server error',
      fileName: 'create_event_group_screen_server_error',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.enterText(find.byType(TextFormField), 'My Trip');
        await _pickTodayAsStartAndEnd(tester);
        await tester.tap(find.text('作成する'));
        await tester.pumpAndSettle();
      },
      builder: () {
        final repository = _MockGroupRepository();
        when(
          () => repository.createEventGroup(
            name: 'My Trip',
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenThrow(Exception('unexpected'));
        return _pumpApp(repository);
      },
    ),
  );
}
