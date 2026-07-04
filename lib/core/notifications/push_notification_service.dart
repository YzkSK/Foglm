import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:foglm/firebase_options.dart';

/// FCM（Firebase Cloud Messaging）初期化・トークン取得の窓口。
/// 通知種別ごとの具体的なハンドリングは #27〜#29 で実装する。
class PushNotificationService {
  PushNotificationService._();

  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseMessaging.instance.requestPermission();
  }

  static Future<String?> getToken() {
    return FirebaseMessaging.instance.getToken();
  }
}
