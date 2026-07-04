import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/app/app.dart';

void main() {
  testWidgets('FoglmApp shows the placeholder home screen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: FoglmApp()),
    );

    expect(find.text('Foglm'), findsOneWidget);
  });
}
