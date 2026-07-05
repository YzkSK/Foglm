# Supabaseローカル環境 設計書 (Issue #77)

## 背景・目的

`docs/setup/supabase.md` には、Docker導入コストに対してメリットが薄いためローカル環境の導入を見送り、
クラウド上の開発用プロジェクトに直接反映して動作確認する運用にしている旨が記載されている。
一方、RLSやトリガーなど壊れやすい変更(直近の`group_members`関連スキーマ修正など)を試す機会が増えてきており、
まさに同ドキュメントが導入検討のタイミングとして挙げていた状況に該当する。
本設計では、コマンド一つでSupabaseローカル環境(DB・マイグレーション適用・Flutter側の接続設定)まで立ち上げられるようにする。

## スコープ

### `scripts/supabase-start.sh`

1. Dockerが起動しているかを`docker info`で確認する。起動していない場合はエラーメッセージを表示して終了する。
2. `npx supabase start` を実行してローカル環境(DB・Auth・Storage等)を起動する。
3. `npx supabase db reset` を実行し、`supabase/migrations/` のマイグレーションを適用する。
4. `dart_define.json` が存在しない場合、`dart_define.example.json` からコピーする。
5. `npx supabase status` の出力からAPI URLとanon keyを取得し、`dart_define.json` の
   `SUPABASE_URL` / `SUPABASE_ANON_KEY` の値のみを書き換える(他のキーがあれば保持する)。
   - `dart_define.json` は`.gitignore`済みのローカル専用ファイルであり、ローカルのSupabase CLIが
     生成する固定の開発用キーのため、書き換えても問題ない(本番のSecret key等とは無関係)。
6. 完了後、接続情報(API URL等)を表示して終了する。

### `scripts/supabase-stop.sh`

- `npx supabase stop` を実行するだけの単純なラッパー。

### `docs/setup/supabase.md` の更新

- セクション3(現状「見送り中」と記載)を、`scripts/supabase-start.sh` / `scripts/supabase-stop.sh` を使った
  起動・停止手順に更新する。
- 見送りの経緯は残しつつ、「壊れやすい変更を試す機会が増えたため導入した」旨を追記する。

## スコープ外

- Flutter側全体の開発環境セットアップ(依存関係インストール等)は別Issue(#76)で対応する。
- 本番/ステージング環境のシークレット(`supabase secrets set`等)の自動化は対象外。実値の取り扱いは
  `docs/setup/secrets.md`の運用のまま変更しない。
- CI上でのローカルSupabaseを使った自動テスト実行の組み込みは別Issueとして新規起票し、本設計の対象外とする。

## 検証方法

- Docker停止状態で`scripts/supabase-start.sh`を実行し、案内メッセージが表示され非ゼロ終了することを確認する。
- Docker起動状態で`scripts/supabase-start.sh`を実行し、
  - `supabase/migrations/`配下のテーブルがローカルDBに作成されること
  - `dart_define.json`が生成され、`SUPABASE_URL`/`SUPABASE_ANON_KEY`にローカル環境の値が入ること
  を確認する。
- `scripts/supabase-stop.sh`実行後、`npx supabase status`でローカル環境が停止していることを確認する。
