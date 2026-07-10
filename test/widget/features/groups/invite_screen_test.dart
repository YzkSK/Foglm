import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/groups/data/group_repository.dart';
import 'package:foglm/features/groups/presentation/invite_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockGroupRepository extends Mock implements GroupRepository {}

void main() {
  late MockGroupRepository repository;

  setUp(() {
    repository = MockGroupRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [groupRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: InviteScreen(groupId: 'group-1', groupName: 'テストグループ'),
        ),
      ),
    );
  }

  testWidgets('shows the existing invite code without reissuing it', (
    tester,
  ) async {
    when(
      () => repository.getInviteCode(groupId: 'group-1'),
    ).thenAnswer((_) async => 'ABC123');

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('ABC123'), findsOneWidget);
    verifyNever(
      () => repository.createInviteCode(groupId: any(named: 'groupId')),
    );
  });

  testWidgets('issues a new code when none exists yet', (tester) async {
    when(
      () => repository.getInviteCode(groupId: 'group-1'),
    ).thenAnswer((_) async => null);
    when(
      () => repository.createInviteCode(groupId: 'group-1'),
    ).thenAnswer((_) async => 'ABC123');

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('ABC123'), findsOneWidget);
    verify(() => repository.createInviteCode(groupId: 'group-1')).called(1);
  });

  testWidgets('shows an error message when loading fails', (tester) async {
    when(
      () => repository.getInviteCode(groupId: 'group-1'),
    ).thenThrow(Exception('unexpected'));

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('招待コードの発行に失敗しました。時間をおいて再度お試しください'), findsOneWidget);
  });

  testWidgets(
    'reissues the code when the reissue action is confirmed in the dialog',
    (tester) async {
      when(
        () => repository.getInviteCode(groupId: 'group-1'),
      ).thenAnswer((_) async => 'ABC123');
      when(
        () => repository.createInviteCode(groupId: 'group-1'),
      ).thenAnswer((_) async => 'NEWCODE');

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('コードを再発行する'));
      await tester.pumpAndSettle();
      expect(find.text('コードを再発行しますか?'), findsOneWidget);
      verifyNever(
        () => repository.createInviteCode(groupId: any(named: 'groupId')),
      );

      await tester.tap(find.text('再発行する'));
      await tester.pumpAndSettle();

      expect(find.text('NEWCODE'), findsOneWidget);
      verify(() => repository.createInviteCode(groupId: 'group-1')).called(1);
    },
  );

  testWidgets('does not reissue the code when the confirmation is cancelled', (
    tester,
  ) async {
    when(
      () => repository.getInviteCode(groupId: 'group-1'),
    ).thenAnswer((_) async => 'ABC123');

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('コードを再発行する'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    expect(find.text('ABC123'), findsOneWidget);
    verifyNever(
      () => repository.createInviteCode(groupId: any(named: 'groupId')),
    );
  });

  testWidgets('retries loading when the retry button is tapped', (
    tester,
  ) async {
    var callCount = 0;
    when(() => repository.getInviteCode(groupId: 'group-1')).thenAnswer((
      _,
    ) async {
      callCount++;
      if (callCount == 1) {
        throw Exception('unexpected');
      }
      return 'ABC123';
    });

    await pumpScreen(tester);
    await tester.pumpAndSettle();
    expect(find.text('招待コードの発行に失敗しました。時間をおいて再度お試しください'), findsOneWidget);

    await tester.tap(find.text('再試行する'));
    await tester.pumpAndSettle();

    expect(find.text('ABC123'), findsOneWidget);
    verify(() => repository.getInviteCode(groupId: 'group-1')).called(2);
  });

  testWidgets('copies the code to the clipboard when the button is tapped', (
    tester,
  ) async {
    when(
      () => repository.getInviteCode(groupId: 'group-1'),
    ).thenAnswer((_) async => 'ABC123');

    final copiedData = <ClipboardData>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<Object?, Object?>;
          copiedData.add(ClipboardData(text: args['text']! as String));
        }
        return null;
      },
    );

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('コードをコピー'));
    await tester.pumpAndSettle();

    expect(copiedData, hasLength(1));
    expect(copiedData.single.text, 'ABC123');
    expect(find.text('招待コードをコピーしました'), findsOneWidget);
  });
}
