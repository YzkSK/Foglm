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

  testWidgets('issues and shows the invite code on load', (tester) async {
    when(
      () => repository.createInviteCode(groupId: 'group-1'),
    ).thenAnswer((_) async => 'ABC123');

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('ABC123'), findsOneWidget);
    verify(() => repository.createInviteCode(groupId: 'group-1')).called(1);
  });

  testWidgets('shows an error message when issuing fails', (tester) async {
    when(
      () => repository.createInviteCode(groupId: 'group-1'),
    ).thenThrow(Exception('unexpected'));

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('招待コードの発行に失敗しました。時間をおいて再度お試しください'), findsOneWidget);
  });

  testWidgets('copies the code to the clipboard when the button is tapped', (
    tester,
  ) async {
    when(
      () => repository.createInviteCode(groupId: 'group-1'),
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
