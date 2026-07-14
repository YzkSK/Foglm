import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/app/app.dart';
import 'package:foglm/features/auth/data/auth_state_listener.dart';
import 'package:foglm/features/auth/data/current_public_user_provider.dart';

void main() {
  testWidgets('FoglmApp shows the placeholder home screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // Supabase未初期化のテスト環境ではauthStateListenerProvider・
        // currentPublicUserProviderの構築にsupabaseClientProviderが必要と
        // なり例外を投げるため、明示的にoverrideして無効化する(#207参照)。
        overrides: [
          authStateListenerProvider.overrideWithValue(null),
          currentPublicUserProvider.overrideWith((ref) async => null),
        ],
        child: const FoglmApp(),
      ),
    );

    expect(find.text('Foglm'), findsOneWidget);
  });
}
