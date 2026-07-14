import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/app/app.dart';
import 'package:foglm/core/config/env.dart';
import 'package:foglm/core/notifications/push_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 環境変数未設定のまま初期化をスキップして起動すると、全機能が原因不明の
  // エラーになるまで気付けない(#207参照)。ここで明示的に落として検知する。
  if (!Env.isConfigured) {
    throw StateError(
      'Supabaseの環境変数が設定されていません。 '
      '--dart-define-from-file=dart_define.json を指定してビルドしてください '
      '(docs/setup/secrets.md参照)。',
    );
  }
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );

  await PushNotificationService.initialize();

  runApp(const ProviderScope(child: FoglmApp()));
}
