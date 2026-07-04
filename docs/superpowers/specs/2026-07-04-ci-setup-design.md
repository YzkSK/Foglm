# CI構築 設計書 (Issue #50)

## 背景・目的
プルリクエスト時に自動でコード品質・テストをチェックする。Issue #49で導入したlint設定を活用する。

## スコープ

### GitHub Actionsワークフロー
- `.github/workflows/ci.yml` を新規作成する。
- トリガー: `pull_request`(`base: main`) と `push`(`branches: [main]`)。
- ジョブ `flutter-ci`(ubuntu-latest):
  1. `actions/checkout@v4`
  2. `subosito/flutter-action@v2` で Flutter 3.44.4 (stable) をセットアップ
  3. `flutter pub get`
  4. `dart format --output=none --set-exit-if-changed .`
  5. `flutter analyze`
  6. `flutter test`

### ブランチ保護
- ワークフローをmainにマージし、`flutter-ci` ジョブが最低1回実行された後、`gh api` で `main` ブランチの必須ステータスチェックに `flutter-ci` を組み込む。

## スコープ外
- Supabase Edge Functions(Deno)のlint・テスト自動実行はIssue #67で別途対応する(現時点でEdge Functionsの実装・テストが存在しないため)。
- CD(マイグレーション・Edge Functionsデプロイ)はIssue #51で対応する。

## 検証方法
- ワークフローをpushし、GitHub Actions上で `flutter-ci` ジョブが成功することを確認する。
- 意図的にフォーマット崩れ/analyzeエラーを混入させた場合に失敗することを確認する(必要に応じて)。
