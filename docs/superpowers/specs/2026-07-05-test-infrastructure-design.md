# テスト基盤構築 設計書 (Issue #53)

## 背景・目的
実装した機能を継続的に検証できるテスト基盤を整える。Issue #50でFlutter側のCI(`flutter test`)は既に組み込み済みだが、テストコード自体はデフォルトの`test/widget_test.dart`のみ。Supabase Edge Functions(`supabase/functions`)は`.gitkeep`のみで実装が存在しないため、テスト実行環境自体が未検証。

主要ロジック(フィルム上限の排他制御、投票締め切り集計、猶予期間判定)は本Issue時点で未実装のため、実際のテストコードではなくテスト方針の整備に留める。

## スコープ

### Flutter側
- `pubspec.yaml` の `dev_dependencies` に `mocktail` を追加する。
  - 理由: null-safety対応でコード生成(build_runner)が不要。`very_good_analysis`を採用済みの本プロジェクトと相性が良く、Very Good Ventures系のFlutterプロジェクトで標準的に使われる。
- `test/` 配下にサブディレクトリ方針を導入する。
  - `test/unit/` : ロジック・Repository等の単体テスト
  - `test/widget/` : ウィジェットテスト(既存`widget_test.dart`は`test/widget/`へ移動)
- `test/unit/`にmocktailを使った依存モックのサンプル単体テストを1つ追加し、実行環境が機能することを確認する。
- CI(`ci.yml`)の`flutter test`ステップは変更不要(既存のまま新しいテストも実行される)。

### Supabase Edge Functions側 (Deno)
- `supabase/functions/hello/index.ts` に最小のサンプルEdge Functionを追加する。
- `supabase/functions/hello/index.test.ts` に対応する`deno test`を追加する。
- `.github/workflows/ci.yml` に Deno のセットアップとテスト実行ステップ(`denoland/setup-deno@v1` → `deno test`)を追加する。既存の`flutter-ci`ジョブとは別ジョブとして追加する。
- `supabase/functions/deno.json` の既存`fmt`/`lint`設定はそのまま流用する(変更なし)。

### テスト方針ドキュメント
- `docs/testing-policy.md` を新規作成し、以下を記載する。
  - **フィルム上限の排他制御**: DB制約・トランザクションレベルでのテスト観点。競合更新(同時書き込み)をシミュレートするテスト方針。
  - **投票締め切り集計**: 締切時刻の前後境界値(締切ちょうど、締切1秒前/後)を対象としたテスト方針。
  - **猶予期間判定**: 時刻依存ロジックのため、現在時刻を外部から注入可能にする設計(時刻を引数/依存として渡す)を前提としたテスト方針。
- 本ドキュメントは実装時に参照する指針であり、実際のテストコードは各ロジック実装のIssueで書く。

## スコープ外
- テストカバレッジ計測・CI上での閾値チェック(lcov集計など)は行わない。必要になった時点で別Issueとする。
- フィルム上限の排他制御・投票締め切り集計・猶予期間判定の実際のロジック実装およびそのテストコードは、各ロジックの実装Issueで対応する。

## 検証方法
- `flutter test` がローカル・CI双方で成功し、`test/unit/`のサンプル単体テスト(mocktail使用)と`test/widget/`のウィジェットテストが実行されることを確認する。
- `deno test` が `supabase/functions/hello/index.test.ts` を実行して成功することをローカル・CIで確認する。
- CIワークフロー(`ci.yml`)が新しいDenoテストジョブを含めて成功することを確認する。
