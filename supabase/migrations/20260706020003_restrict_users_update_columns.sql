-- users_update_own(20260706010001)は列単位の制限がなく、authenticatedクライアントが
-- auth_provider/deleted_atなどを自由に書き換えられてしまう。これにより
-- prevent_cross_provider_identity_linkingトリガーやis_account_deleted()が根拠とする
-- 列を本人が改ざんし、重複登録防止や削除済み判定を回避できてしまうため、
-- クライアントから直接更新してよい列のみに絞る。
revoke update on public.users from authenticated;
grant update (display_name, avatar_url, fcm_token) on public.users to authenticated;
