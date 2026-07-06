-- check_sns_email_conflict: 指定したメールアドレスがSNSログイン(google/apple/x/instagram)で
-- 既に使用されているかを判定する(仕様書 3.1・6.1 sign_up_with_email参照)。
-- auth.identitiesを横断参照するためservice_roleのみ実行可能とする。
create function public.check_sns_email_conflict(p_email text)
returns text
language sql
security definer
set search_path = auth, public
stable
as $$
  -- 注意: 'x'・'instagram'はSupabaseのauth.identitiesが実際にprovider列へ格納する
  -- 値とは異なる可能性がある(SupabaseネイティブOAuthではXは'twitter'として保存され、
  -- Instagram向けのネイティブプロバイダは存在しない)。
  -- SNSログイン実装時にauth.identities.providerの実値を確認し、
  -- 本関数のprovider一覧をそれに合わせて更新すること(現時点ではSNSログインが
  -- スコープ外のため、この不一致は無害)。
  select provider
  from auth.identities
  where provider in ('google', 'apple', 'x', 'instagram')
    and lower(identity_data ->> 'email') = lower(p_email)
  limit 1;
$$;

revoke execute on function public.check_sns_email_conflict(text) from public;
revoke execute on function public.check_sns_email_conflict(text) from authenticated;
grant execute on function public.check_sns_email_conflict(text) to service_role;
