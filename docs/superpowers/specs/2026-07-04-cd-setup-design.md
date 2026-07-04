# CD構築 設計書 (Issue #51)

## 背景・目的
DBマイグレーションやEdge Functionsの変更を安全に本番へ反映する。

## スコープ

### GitHub Actionsワークフロー
- `.github/workflows/cd.yml` を新規作成する。
- トリガー: `push`(`branches: [main]`)かつ `paths: ['supabase/**']`(supabase配下の変更があるmainへのpushのみ発火)。
- ジョブ `deploy`(ubuntu-latest):
  1. `actions/checkout@v4`
  2. `supabase/setup-cli@v1` でSupabase CLIをセットアップ
  3. `supabase link --project-ref $SUPABASE_PROJECT_ID`(環境変数 `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD` を使用)
  4. `supabase db push` でマイグレーションを適用
  5. Edge Functionsディレクトリに `.ts` ファイルが存在する場合のみ `supabase functions deploy` を実行(現時点では存在しないためスキップされる)

### 必要なGitHub Secrets(ユーザーが手動登録)
- `SUPABASE_ACCESS_TOKEN`: Supabaseダッシュボード → Account → Access Tokens で発行
- `SUPABASE_PROJECT_ID`: Supabaseプロジェクトのref ID(Project Settings → General)
- `SUPABASE_DB_PASSWORD`: プロジェクト作成時に設定したDBパスワード

これらの値はチャットには含めず、ユーザー自身が `gh secret set` またはGitHub UIから登録する。

### ロールバック方針のドキュメント化
- `docs/setup/supabase.md` に、デプロイ失敗時の手動対応手順を追記する。
  - `supabase db push` が失敗した場合、失敗したマイグレーションを打ち消す新しいマイグレーションSQLを作成し、再度pushする(自動ロールバックは行わない)。
  - `supabase functions deploy` が失敗した場合、直前のデプロイ済みバージョンは影響を受けないため、原因を修正して再デプロイする。

## スコープ外
- Edge Functions未実装の現時点では、functions deployは実質的にスキップされる。Edge Functions実装時に動作確認を行う。

## 検証方法
- ワークフローファイルのYAML構文確認。
- Secrets未登録の状態では実際のデプロイは実行できないため、mainマージ後にユーザーがSecretsを登録した上で、supabase配下に変更を加えて動作確認を行う(このタスクのスコープ外、フォローアップとする)。
