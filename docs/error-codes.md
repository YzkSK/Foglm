# エラーコード一覧

アプリが扱うエラーコードの台帳。サーバー(Edge Function / Supabase Auth)が返すコード文字列と、クライアント(Flutter)側のハンドリング状況を対応付ける。

エラーを追加・変更するときは、まずこのファイルを更新すること。

> **将来的な運用**: このファイルは `tool/error_catalog.yaml` からの生成物にする予定(#262)。それまでは手動で更新する。
> 経緯と設計判断は `docs/superpowers/specs/2026-07-14-error-code-catalog-design.md` を参照。

## 用語

- **source**: コードの出所。`edge_function` は自前の Edge Function が返すもの。`supabase_auth` は Supabase Auth ライブラリが `AuthException.code` として返すもので、クライアントは消費するだけ。
- **クライアント対応**: 対応する `Failure` に変換されているか。
  - **○** — 専用の Failure にマップされている
  - **×** — マップされておらず `Unknown*Failure` に落ちている(ユーザーには原因不明のエラーとして表示される)
  - **—** — cron 専用など、クライアントが呼ばないため対応不要

## Edge Function 由来

### upload-photo → `UploadPhotoFailure`

| コード | 意味 | クライアント対応 |
| --- | --- | --- |
| `daily_limit_reached` | その日の撮影上限に達している | ○ `DailyLimitReachedFailure` |
| `group_archived` | グループがアーカイブ済みで新規撮影を受け付けない | ○ `GroupArchivedFailure` |
| `not_active_member` | 撮影時点で既にグループの現役メンバーでない | ○ `NotActiveMemberFailure` |
| `email_not_verified` | メールアドレスが未確認 | ○ `EmailNotVerifiedFailure` |
| `unsupported_image_type` | 対応していない画像形式 | × (#265) |
| `invalid_image` | 画像として読み取れない | × (#265) |
| `upload_failed` | Storage へのアップロードに失敗 | × (#265) |
| `invalid_group_id` | `group_id` が UUID として不正 | × (#265) |
| `invalid_request` | リクエストボディが不正 | × (#265) |
| `unauthorized` | 認証されていない | × (#265) |
| `unknown` | 分類できないサーバーエラー | ○ `UnknownUploadPhotoFailure` |

### get-photo-url

現時点でクライアントからは呼ばれていない(アルバム画面 S10 の実装時に使用予定)。対応する `Failure` 型も未定義。

| コード | 意味 | クライアント対応 |
| --- | --- | --- |
| `invalid_photo_id` | `photo_id` が UUID として不正 | — 未使用 |
| `unauthorized` | 認証されていない | — 未使用 |
| `not_found` | 写真が存在しない、または閲覧権限が無い | — 未使用 |
| `signed_url_failed` | 署名付き URL の発行に失敗 | — 未使用 |

### sign-up-with-email → `SignUpFailure`

| コード | 意味 | クライアント対応 |
| --- | --- | --- |
| `invalid_email` | メールアドレスの形式が不正 | ○ `InvalidEmailFailure` |
| `weak_password` | パスワードが要件を満たさない | ○ `WeakPasswordFailure` |
| `email_used_by_sns` | 同一メールが SNS ログインで使用済み | ○ `EmailUsedBySnsFailure` |
| `sign_up_failed` | サインアップ処理に失敗 | × (#266) |
| `invalid_request` | リクエストボディが不正 | × (#266) |
| `unknown` | 分類できないサーバーエラー | ○ `UnknownSignUpFailure` |

### request-password-reset / reset-password → `PasswordResetFailure`

| コード | 意味 | クライアント対応 |
| --- | --- | --- |
| `invalid_email` | メールアドレスの形式が不正 | ○ `PasswordResetInvalidEmailFailure` |
| `weak_password` | 新しいパスワードが要件を満たさない | ○ `PasswordResetWeakPasswordFailure` |
| `update_failed` | パスワードの更新に失敗 | ○ `PasswordResetUpdateFailedFailure` |
| `invalid_request` | リクエストボディが不正 | × (#266) |
| `unknown` | 分類できないサーバーエラー | ○ `UnknownPasswordResetFailure` |

### delete-account → `DeleteAccountFailure`

| コード | 意味 | クライアント対応 |
| --- | --- | --- |
| `unauthorized` | 認証されていない | × (#266) |
| `unknown` | 分類できないサーバーエラー | ○ `UnknownDeleteAccountFailure` |

### close-daily-vote (cron専用)

| コード | 意味 | クライアント対応 |
| --- | --- | --- |
| `unauthorized` | cron シークレットが不正 | — |
| `close_daily_vote_failed` | 投票締め処理に失敗 | — |

### process-scheduled-development (cron専用)

| コード | 意味 | クライアント対応 |
| --- | --- | --- |
| `unauthorized` | cron シークレットが不正 | — |
| `process_scheduled_development_failed` | 現像処理に失敗 | — |

## Supabase Auth 由来

Supabase Auth ライブラリが `AuthException.code` として返すコード。自前で定義したものではなく、クライアントは消費するだけ。

### sign_in → `SignInFailure`

| コード | 意味 | クライアント対応 |
| --- | --- | --- |
| `invalid_credentials` | メールアドレスまたはパスワードが正しくない | ○ `InvalidCredentialsFailure` |
| `email_not_confirmed` | メールアドレスが未確認 | ○ `EmailNotConfirmedFailure` |
| (上記以外) | — | ○ `UnknownSignInFailure` |

`DeletedAccountFailure` は `AuthException.code` からではなく、アプリ側の削除済み判定によって生成される。

## 既知の課題

- `unsupported_image_type` / `sign_up_failed` など、サーバーが返しているのにクライアントが `Unknown*Failure` に落としているコードが複数ある(上表の × 印)。原因が特定できているのにユーザーには原因不明のエラーとして表示されるため、順次解消する(#265, #266)。
- コード文字列がサーバー・クライアント双方に生リテラルで散在しており、コンパイラが不一致を検出できない。台帳からの生成に移行して解消する(#262, #264)。
- `get-photo-url` はクライアント側に対応する `Failure` 型が存在しない。アルバム画面(S10)の実装時に必要になる。
