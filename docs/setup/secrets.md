# 環境変数・シークレット管理

APIキーやFCMサーバーキーなど、機密情報の取り扱いルールをまとめる。

## 1. 基本ルール

- 秘密鍵・シークレットキー・サービスアカウントJSON等は**リポジトリに一切コミットしない**。
- クライアントに埋め込んでよい値(Supabaseの Publishable key など)と、サーバー側専用の値(Secret key、FCMサービスアカウント等)を区別し、後者は絶対にアプリ側のコードやリポジトリに含めない。
- 実際の値は1Password等の安全な方法でチーム内共有する。Slack・GitHub Issue・コミットメッセージ等の平文への貼り付けは禁止。
- サンプルファイル(`*.example.*`)にはプレースホルダーのみを記載し、実際の値を書かない。

## 2. Flutterアプリの環境変数

`--dart-define` 方式を採用する(`flutter_dotenv` 等の追加パッケージは使わない)。値は`lib/core/config/env.dart`の`Env`クラスから`String.fromEnvironment`で参照する。

値をコマンドラインに並べる代わりに、jsonファイルにまとめて `--dart-define-from-file` で渡す。

```bash
# ローカルにサンプルをコピーして実際の値を入れる(このファイルは.gitignore済み)
cp dart_define.example.json dart_define.json

# 実行時
flutter run --dart-define-from-file=dart_define.json

# ビルド時
flutter build apk --dart-define-from-file=dart_define.json
```

dev/prodなど環境を分ける場合は `dart_define.dev.json` / `dart_define.prod.json` のように分割し、それぞれ`.gitignore`の`dart_define*.json`パターンで除外される。

> ローカルのSupabase開発環境を使う場合は、上記の手動コピー・編集を`tool/supabase_start.dart`([docs/setup/supabase.md](./supabase.md)参照)が自動化し、`SUPABASE_URL`/`SUPABASE_ANON_KEY`にローカル開発用の値を自動で設定する。実際の(クラウド)Supabaseプロジェクトを参照する場合は、引き続き上記の手動フローを使う。

devプロファイル限定のデバッグ用画面については[debug-menu.md](./debug-menu.md)を参照。

## 3. Supabase Edge Functionsのシークレット

サーバー側のみで使うシークレット(例: FCMサービスアカウント)は`supabase secrets set`で登録し、コード・リポジトリには含めない。

```bash
npx supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat service-account.json)"
```

登録済みシークレットの確認・削除は以下で行う。

```bash
npx supabase secrets list
npx supabase secrets unset FIREBASE_SERVICE_ACCOUNT
```

## 4. Firebase関連ファイル

`flutterfire configure`で生成される以下のファイルは実際のプロジェクト設定を含むため、リポジトリには含めず`.gitignore`済み。詳細は[firebase.md](./firebase.md)を参照。

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `lib/firebase_options.dart`

## 関連Issue

- #48 環境変数・シークレット管理の整備
