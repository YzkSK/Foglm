# Firebaseセットアップ手順（FCM用）

このドキュメントは、プッシュ通知（FCM: Firebase Cloud Messaging）のためのFirebaseプロジェクトを
実際に作成・接続するための手順書。プロジェクトの新規作成にはFirebaseアカウントでのログインが必要なため、
担当者が手作業で行うこと。

## 1. Firebaseプロジェクトの作成

1. https://console.firebase.google.com にログインし、新規プロジェクトを作成する
2. Cloud Messaging（FCM）を有効化する

## 2. FlutterFireのセットアップ

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

- 対象プラットフォームはAndroid/iOSを選択する
- コマンド実行後、以下のファイルが自動生成される（いずれもリポジトリには含めない。`.gitignore`済み）
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist`
  - `lib/firebase_options.dart`

生成された各ファイルは、開発者間で1Password等の安全な方法で共有するか、各自が `flutterfire configure` を実行して取得すること。

## 3. アプリ側の初期化

`lib/core/notifications/push_notification_service.dart` に初期化・トークン取得処理を用意済み。
`lib/firebase_options.dart` が生成された後、`main.dart` から呼び出す配線を行う（#27 FCMプッシュ通知基盤構築で対応）。

## 4. サーバー側（Supabase Edge Function）からのFCM送信

1. Firebaseコンソールの プロジェクト設定 > サービスアカウント から秘密鍵（JSON）を発行する
2. Supabase側にシークレットとして登録する

```bash
npx supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat service-account.json)"
```

シークレットの取り扱いルールの詳細は[secrets.md](./secrets.md)を参照。

3. Edge FunctionからFCM HTTP v1 APIを呼び出す（実装は #28 現像完了通知実装で対応）

## 関連Issue

- #47 Firebaseプロジェクトセットアップ（FCM用）
- #27 FCMプッシュ通知基盤構築
- #28 現像完了通知実装
