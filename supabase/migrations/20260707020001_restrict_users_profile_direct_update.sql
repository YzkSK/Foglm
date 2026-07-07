-- display_name/avatar_urlの列単位grant(20260706020003)により、認証済みユーザーは
-- update_profile関数のバリデーション(空白ニックネーム拒否)を経由せず直接updateできてしまう。
-- 本人によるdisplay_name/avatar_urlの更新はupdate_profile関数経由のみに限定する。
revoke update (display_name, avatar_url) on public.users from authenticated;
