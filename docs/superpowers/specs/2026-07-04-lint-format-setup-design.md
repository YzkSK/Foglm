# Lint/Format設定 設計書 (Issue #49)

## 背景・目的
コードの品質・スタイルを統一する。CI構築(Issue #50)の前提となる設定を整える。

## スコープ

### Flutter側
- `pubspec.yaml` の `dev_dependencies` を `flutter_lints` から `very_good_analysis: ^10.3.0` に置き換える。
- `analysis_options.yaml` の `include` を `package:very_good_analysis/analysis_options.yaml` に変更する。
- `flutter analyze` で検出されたエラーのうち、プロジェクトの実態に合わないルールは `analysis_options.yaml` の `rules` セクションで個別に無効化する。

### Supabase Edge Functions側 (Deno)
- issueには「ESLint/Prettier」とあるが、Edge FunctionsはDenoランタイムのため、npm/ESLint/Prettierは導入せず、Deno組み込みの `deno fmt` / `deno lint` を採用する。
- `supabase/functions/deno.json` を新規作成し、`fmt`/`lint` の設定を定義する。現時点でEdge Functionsの実装はまだ無いため、設定のみのスケルエンとなる。

## スコープ外
- CI(GitHub Actions)へのlint自動実行の組み込みはIssue #50で対応する。

## 検証方法
- `flutter analyze` を実行し、エラーが無いことを確認する。
- `dart format --set-exit-if-changed .` を実行し、フォーマット崩れが無いことを確認する。
- `deno.json` は現時点で対象ファイルが無いため、`deno fmt`/`deno lint` の実行確認は次回Edge Functions実装時に行う。
