# Supabaseセットアップ手順

このドキュメントは、Foglmが利用するSupabaseプロジェクトを実際に作成・接続するための手順書。
プロジェクトの新規作成にはSupabaseアカウントでのログインが必要なため、担当者が手作業で行うこと。

## 1. Supabaseプロジェクトの作成

1. https://supabase.com/dashboard にログインし、新規プロジェクトを作成する
2. リージョンは東京（Northeast Asia）を選択する
3. 作成後、Project Settings > Data API から以下の情報を控える
   - Project URL（`SUPABASE_URL`）
   - Publishable key（`SUPABASE_ANON_KEY`。旧anon keyに相当。クライアントに埋め込んでよい）
   - Secret key（旧service_role keyに相当。Edge Function等サーバー側専用。クライアントには絶対に含めない）

> Supabaseは2024年後半以降、キー体系を anon/service_role（レガシー）から Publishable/Secret key に移行している。
> 新規プロジェクトではデフォルトでPublishable/Secret keyが表示され、旧anon/service_roleは「Legacy keys」タブに退避されている。

## 2. Supabase CLIのセットアップ

```bash
# CLIはリポジトリにインストール済みの想定はしていないため、npxで実行する
npx supabase login

# 作成したプロジェクトとリポジトリ内の supabase/ ディレクトリを紐付ける
npx supabase link --project-ref <YOUR_PROJECT_REF>
```

## 3. ローカル開発環境の起動

以前はDocker導入コストに対してメリットが薄いため見送っていたが、RLSやトリガーなど壊れやすい変更を
試す機会が増えてきたため、ローカル環境を導入した。ローカル開発にはDockerが必要。

以下のコマンドを実行すると、ローカルDBの起動・マイグレーション適用・Flutter側の接続設定
(`dart_define.json`)までが一括で行われる。

```bash
dart run tool/supabase_start.dart
```

初回実行時はDockerイメージの取得が入るため時間がかかる。実行後、`dart_define.json`が
無ければ`dart_define.example.json`からコピーされた上で、`SUPABASE_URL`/`SUPABASE_ANON_KEY`が
ローカル環境の値に書き換えられる(ローカル固定の開発用キーであり、本番のSecret key等とは無関係)。

停止する場合は以下を実行する。

```bash
dart run tool/supabase_stop.dart
```

## 4. マイグレーションの適用

新しいマイグレーションファイルは、以下のコマンドで作成する。
手動でファイル名（タイムスタンプ）を付けないこと。並行して作業している別ブランチと
タイムスタンプが衝突し、マージ時に `schema_migrations` の主キー重複でCIが失敗するため。

```bash
npx supabase migration new <name>
```

`supabase/migrations/` にマイグレーションSQLを追加した後、以下で反映する。

```bash
# ローカル環境へ反映
npx supabase db reset

# リンク済みの本番/ステージング環境へ反映
npx supabase db push
```

## 5. ストレージバケットの作成

以下の2つのバケットを作成する（マイグレーションまたはダッシュボードから作成）。

| バケット名 | 公開設定 | 用途 |
|---|---|---|
| `photos-original` | 非公開 | 撮影直後の鮮明な原本 |
| `photos-blurred` | 非公開（署名付きURLで配信） | ボヤけ版・現像済み画像の配信 |

原本はクライアントに一切配信しないため、`photos-original` は常に非公開のままとする（仕様書 8.1参照）。

## 6. Edge Functionsのデプロイ

`supabase/functions/` にFunctionを追加した後、以下でデプロイする。

```bash
npx supabase functions deploy <function-name>
```

## 7. アプリ側の環境変数

Flutterアプリからは `--dart-define` で以下を渡す(詳細は[secrets.md](./secrets.md)を参照)。

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

## 8. デプロイ失敗時の対応(ロールバック方針)

CD(`.github/workflows/cd.yml`)は `supabase db push` / `supabase functions deploy` の自動ロールバックを行わない。失敗時は以下の手順で手動対応する。

### マイグレーション適用(`supabase db push`)が失敗した場合
1. GitHub Actionsのログでどのマイグレーションファイルが失敗したか確認する。
2. 本番環境のスキーマ状態を確認し、失敗したマイグレーションが部分適用されていないか確認する。
3. 問題のあるマイグレーションを直接編集せず、それを打ち消す新しいマイグレーションSQL(`supabase/migrations/`に追加)を作成する。
4. 修正後、再度mainにマージしてCDを再実行する。

### Edge Functionsデプロイ(`supabase functions deploy`)が失敗した場合
1. デプロイに失敗しても、直前にデプロイ済みのバージョンは稼働し続けるため、サービス断は発生しない。
2. GitHub Actionsのログでエラー内容を確認し、Edge Function側のコードを修正する。
3. 修正後、再度mainにマージしてCDを再実行する。

## 関連Issue

- #46 Supabaseプロジェクト初期セットアップ
- #48 環境変数・シークレット管理の整備 → [secrets.md](./secrets.md)
- #51 CD構築（Supabaseマイグレーション・Edge Functions自動デプロイ）
