# APIフロー

Foglmのクライアントとバックエンドの間には**6本の経路**があり、さらにcronとDBトリガーによる**ユーザー操作を起点としない処理**が動いている。このドキュメントは、

- **どの機能がどの経路で実装されているか**（現状台帳）
- **新しく機能を追加するとき、どの経路を選ぶべきか**（規約）

の2つを扱う。

`docs/spec.md` の6章は「**何を**提供するか」（仕様）を定める。本ドキュメントは「**どう**実装されているか / 実装すべきか」を定める。仕様の変更は spec.md、実装方式の変更は本ドキュメントで行う。

---

## 1. 規約：どの経路を選ぶか

判断基準は「**Postgresの中で完結できるか**」に一本化する。能力から機械的に決まるため、判断に迷う余地を残さない。

| 経路 | 選ぶ条件 |
|---|---|
| **Auth API** | Supabase Authのセッション操作そのもの（サインイン、サインアウト、OAuth、確認メール再送） |
| **Edge Function** | Postgresの外の能力が要る。Auth Admin API / 画像処理(sharp) / 外部API(FCM) / Storage操作・署名 |
| **RPC** (security definer) | DB内で完結する**書き込み**、または**集計・整合性判断を伴う読み取り** |
| **直接テーブル** | 単純な読み取りで、**RLSだけで安全に閉じられる**もの |
| **直接Storage** | **使用しない**（署名URLの発行はEdge Functionに寄せる。§1.2参照） |
| **Realtime** | サーバー側の変更をクライアントへpushしたいとき（読み取り専用） |

### 1.1 「直接テーブル」に降ろしてよい読み取りの条件

単に `select` するだけでは足りない。以下のいずれかに該当したら、**直接テーブルではなくRPCにする**。

- **集計が要る**（件数、得票数など）
- **複数テーブルの結合・突き合わせが要る**
- **秘匿URLの発行が絡む**
- **キャッシュ方針を持たせたい**

クライアントに業務ロジックが漏れるのを防ぐための条件である。複数回selectしてクライアント側で突き合わせている実装を見つけたら、それはRPC化のサインとみなす。

### 1.2 署名付きURLはクライアントで発行しない

仕様書8.1のとおり、原本は非公開ストレージにのみ置き、クライアントへ配信しない。署名URLの発行は `get-photo-url` Edge Function に集約する。この関数は `signed_url_cache` テーブルによる署名URLのキャッシュを持ち、CDNヒット率を保っている（#167）。クライアントが `storage.createSignedUrl()` を直接呼ぶと、**このキャッシュを迂回してしまう**。

### 1.3 Edge Functionの認可方式

呼び出し元によって2方式に分ける。**ここを外すと認証なしで公開される**（実際に起きた → #218）。

| 呼び出し元 | 認可方式 |
|---|---|
| クライアント起点 | `verify_jwt = true`（デフォルト）。ユーザーのJWTで認可する |
| cron / サーバー起点 | `verify_jwt = false` + **`X-Cron-Secret` 共有シークレットをハンドラ内で必ず検証する** |

**`verify_jwt = false` にしたら、独自の認可を必ず実装すること。** 設定は `supabase/config.toml` の `[functions.<name>]` で行う。

また、**1つの関数に `Deno.serve` は1つだけ**にする。複数定義すると、認可のないハンドラが先に登録されて認可付きハンドラを無効化しうる（#218 の直接原因）。

---

## 2. 台帳：クライアント起点のAPI

### 2.1 認証・アカウント

| API | 種別 | 呼び出し元 | 権限の担保 | 適合 |
|---|---|---|---|---|
| `sign-up-with-email` | Edge Function | `auth_repository.dart:56` | サーバー側でSNSメール重複を検証 | ✅ |
| `signInWithPassword` | Auth API | `auth_repository.dart:78, 94` | Supabase Auth | ✅ |
| `signInWithOAuth` | Auth API | `auth_repository.dart:105` | Supabase Auth | ✅ |
| `signOut` | Auth API | `auth_repository.dart:113, 120, 184` | Supabase Auth | ✅ |
| `auth.resend` | Auth API | `auth_repository.dart:69` | Supabase Auth | ✅ |
| `request-password-reset` | Edge Function | `auth_repository.dart:126` | Auth Admin API が必要 | ✅ |
| `reset-password` | Edge Function | `auth_repository.dart:140` | Auth Admin API が必要 | ✅ |
| `delete-account` | Edge Function | `auth_repository.dart:165` | `auth.identities` 操作にAdmin APIが必要 | ⚠️ #208 |
| `update_profile` | RPC | `auth_repository.dart:156` | `security definer` + 更新列を制限 | ✅ |
| `is_account_deleted` | RPC | `auth_repository.dart:111`<br>`auth_state_listener.dart:40` | `security definer` | ✅ |
| プロフィール取得 | 直接テーブル | `my_profile_provider.dart:16`<br>`current_public_user_provider.dart:16` | RLS `users_select_own_or_shared_active_group` | ✅ |

**なぜサインアップだけEdge Functionなのか**：サインアップは、登録の**前に**「そのメールアドレスがSNSログインで使用済みでないか」を検証する必要がある（仕様書3.1）。この検証には他ユーザーの `auth.identities` を読む必要があり、クライアントの権限では不可能。だからEdge Functionでラップしている。一方サインイン・サインアウトにはそうした事前検証がないため、Auth APIを直接呼ぶ。パスワードリセットも Auth Admin API が要るためEdge Functionになる。

### 2.2 グループ

| API | 種別 | 呼び出し元 | 権限の担保 | 適合 |
|---|---|---|---|---|
| `create_group` | RPC | `group_repository.dart:37` | `security definer`。`groups` への直接INSERTはrevoke済み | ✅ |
| `create_event_group` | RPC | `group_repository.dart:46` | 同上 | ✅ |
| `create_invite_code` | RPC | `group_repository.dart:98` | `security definer` | ✅ |
| `invite_member` | RPC | `group_repository.dart:76` | `security definer` | ⚠️ #219 |
| `join_event_group` | RPC | `group_repository.dart:78` | `security definer` | ⚠️ #219 |
| `leave_group` | RPC | `group_repository.dart:90` | `security definer` | ✅ |
| グループ一覧 | 直接テーブル | `group_repository.dart:61` | RLS `groups_select_active_member` | ✅ |
| 招待コード取得 | 直接テーブル | `group_repository.dart:111` | RLS `invite_codes_select_active_member` | ✅ |
| `dissolve_group` | RPC | **未使用** | `security definer` | 画面未実装 |

### 2.3 撮影

| API | 種別 | 呼び出し元 | 権限の担保 | 適合 |
|---|---|---|---|---|
| `upload-photo` | Edge Function | `photo_repository.dart:32` | sharpによる画像処理が必要。サーバー側で現役メンバー・メール確認を検証 | ⚠️ #208 |
| `get_today_shots_remaining` | RPC | `remaining_shots_repository.dart:33` | `security definer` | ✅ |
| 残り枚数の購読 | Realtime | `remaining_shots_repository.dart:53` | `photos` のINSERTを購読（読み取り専用） | ✅ |

**撮影上限の最終担保はEdge Functionではなく、DBトリガー `trg_check_photo_daily_limit` にある**（§4参照）。クライアントの残り枚数表示はあくまでUI上の予防線であり、上限の強制はDB側で行われる。

### 2.4 投票

| API | 種別 | 呼び出し元 | 権限の担保 | 適合 |
|---|---|---|---|---|
| `cast_vote` | RPC | `vote_repository.dart:20` | `security definer`。`vote_entries` への直接書き込みはrevoke済み | ✅ |
| 候補一覧の取得 | 直接テーブル ×3 | `candidate_repository.dart:39, 79, 101` | RLS | ⚠️ #219 |
| ボヤけ版の署名URL | 直接Storage | `candidate_repository.dart:118` | RLS `photo_blurred_select_active_member` | ⚠️ #219 |

### 2.5 アルバム・現像

| API | 種別 | 呼び出し元 | 権限の担保 | 適合 |
|---|---|---|---|---|
| アルバム取得 | 直接テーブル | `album_repository.dart:31` | RLS `photos_select_active_member` | ✅ |
| 現像待ち枚数 | 直接テーブル | `album_repository.dart:45` | 同上（`count()` によるHEADリクエスト） | ✅ |
| `get-photo-url` | Edge Function | **未使用** | 呼び出し元のJWTで所属を検証 | ⚠️ #219 |

### 2.6 リアクション・コメント

`add_reaction` / `add_comment` はRPCとしてDBに実装済みだが、**写真詳細画面（#28）が未実装のためアプリからは呼ばれていない**。

---

## 3. 非同期フロー（cron → Edge Function）

すべて `service_role` で動作し、**RLSを迂回する**。ユーザーのセッションは存在しない。

| cronジョブ | 実行間隔 | 呼び出し先 | 認可 |
|---|---|---|---|
| `close_daily_vote_daily` | 毎日 15:00 UTC（= JST 24:00） | `close-daily-vote` Edge Function | ⚠️ **#218**（無認可で公開されている） |
| `process_scheduled_development_hourly` | 毎時0分 | `process-scheduled-development` Edge Function | `X-Cron-Secret` ✅ |
| `archive_expired_events_daily` | 毎日 0:00 UTC | DB関数を直接実行 | cron内で完結 |
| `archive_inactive_solo_groups_daily` | 毎日 0:00 UTC | DB関数を直接実行 | cron内で完結 |

### 3.1 写真のライフサイクル

`photos.status` は4つの状態を持つ（`20260705172916_create_photos.sql:11-12`）。

```
                          [撮影]
                       upload-photo
                            │
                            ▼
                     ┌─────────────┐
                     │ pending_vote │  ← 投票の候補。ボヤけ版のみ閲覧可
                     └──────┬───────┘
                            │
                  close-daily-vote（毎日 JST 24:00）
                  その日の得票を集計し、当選写真を1枚決める
                  （同数はランダム / 0票なら撮影分からランダム）
                            │
              ┌─────────────┴──────────────┐
         [当選]                          [落選]
              │                              │
              ▼                              ▼
     ┌────────────────┐          ┌──────────────────┐
     │ selected_today │          │  waiting_random  │
     └────────┬───────┘          └────────┬─────────┘
              │                            │
       即時現像                    develop_scheduled_at
       通知を送信                  （撮影日 +3〜14日のランダム値）を設定
              │                            │
              │            process-scheduled-development（毎時）
              │            予定時刻が到来した写真をまとめて現像
              │            グループ単位で集約して通知を1件送る
              │                            │
              └─────────────┬──────────────┘
                            ▼
                     ┌────────────┐
                     │ developed  │  ← 原本を閲覧可。アルバムに載る
                     └────────────┘
```

現像待ち枚数（`get_developing_count`）が数えているのは `pending_vote` と `waiting_random` の2つ（`album_repository.dart:10`）。

---

## 4. DBトリガー（呼び出し側から見えない副作用）

**8個。**「この操作をすると裏で何が起きるか」を把握していないとハマる。

| トリガー | 発火条件 | 何が起きるか |
|---|---|---|
| `on_auth_user_created` | `auth.users` INSERT | `handle_new_user` が `public.users` の行を自動作成する |
| `on_public_user_created` | `public.users` INSERT | `ensure_solo_space` が**ソロ用グループと `group_members` を自動作成する**（サインアップしただけでグループが1件できる） |
| `on_auth_user_email_confirmed` | `auth.users` の確認完了 | `sync_email_verified` が `users.email_verified` を true にする |
| `on_auth_identity_linked` | `auth.identities` INSERT | `prevent_cross_provider_identity_linking` が、**別プロバイダの連携を拒否しうる**（メール登録済みのアドレスでSNSログインさせない） |
| `trg_check_photo_daily_limit` | `photos` INSERT | **撮影上限（1日10枚）の最終担保**。`taken_date` をJST基準で上書きし、上限超過なら拒否する |
| `trg_check_group_member_limit` | `group_members` INSERT | **メンバー上限（6人）の最終担保**。超過なら拒否する |
| `trg_prevent_group_members_group_id_change` | `group_members` UPDATE | `group_id` の付け替えを拒否する |
| `trg_restore_group_active_status` | `group_members` の加入 | 現役2人以上に戻ったら `groups.solo_since` を NULL に戻す |

**上限系（撮影10枚・メンバー6人）はアプリ側でもEdge Function側でもなく、最終的にDBトリガーが担保している。** アプリ側のチェックはUXのための予防線にすぎない。

---

## 5. 既知の規約違反

| # | 内容 | issue |
|---|---|---|
| 1 | `close-daily-vote` が無認可で公開されている（`Deno.serve` 二重定義 + cronの認可不整合） | [#218](https://github.com/YzkSK/Foglm/issues/218) |
| 2 | 候補一覧が3回selectしてクライアント側で得票を集計している → `get_today_candidates` RPCへ | [#219](https://github.com/YzkSK/Foglm/issues/219) |
| 3 | 候補一覧が署名URLをクライアントで直接発行し、`get-photo-url` のキャッシュを迂回している | [#219](https://github.com/YzkSK/Foglm/issues/219) |
| 4 | `joinGroupByCode` が2つのRPCを総当たりしている → `join_group_by_code` RPCへ統合 | [#219](https://github.com/YzkSK/Foglm/issues/219) |
| 5 | 全Edge FunctionがHTTPメソッドを検証していない | [#208](https://github.com/YzkSK/Foglm/issues/208) |
