import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/camera/camera_screen.dart';
import 'package:go_router/go_router.dart';

/// アプリ全体のルーティング定義の土台。
/// 各画面（S01〜S13）は別Issueで追加していく。
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _PlaceholderHome(),
      ),
      GoRoute(
        path: '/camera',
        builder: (context, state) => const CameraScreen(),
      ),
    ],
  );
});

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Foglm'),
            ElevatedButton(
              onPressed: () => context.go('/camera'),
              child: const Text('カメラ'),
            ),
          ],
        ),
      ),
    );
  }
}
