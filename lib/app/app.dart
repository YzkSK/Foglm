import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/core/router/app_router.dart';
import 'package:foglm/core/theme/app_theme.dart';

class FoglmApp extends ConsumerWidget {
  const FoglmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Foglm',
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
