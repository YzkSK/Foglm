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

## 3. ローカル開発環境の起動（任意・現時点ではスキップ中）

ローカル開発にはDockerが必要。現状は導入コストに対してメリットが薄いため見送っており、クラウド上の開発用プロジェクトに直接マイグレーションを反映して動作確認する運用としている。RLSやトリガーなど壊れやすい変更を試す機会が増えてきたタイミングで、改めて導入を検討する。

```bash
npx supabase start
```

停止する場合は `npx supabase stop`。

## 4. マイグレーションの適用

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

Flutterアプリからは `--dart-define` で以下を渡す（詳細は #48 環境変数・シークレット管理の整備を参照）。

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

## 関連Issue

- #46 Supabaseプロジェクト初期セットアップ
- #48 環境変数・シークレット管理の整備
- #51 CD構築（Supabaseマイグレーション・Edge Functions自動デプロイ）
