-- check_sns_email_conflict: 指定したメールアドレスがSNSログイン(google/apple/twitter)で
-- 既に使用されているかを判定する(仕様書 3.1・6.1 sign_up_with_email参照)。
-- auth.identitiesを横断参照するためservice_roleのみ実行可能とする。
-- SNSログイン対応プロバイダはGoogle/Apple/X(Twitter)に確定(Instagramは対象外)。
-- auth.identities.providerはSupabaseの実プロバイダ表記('twitter')をそのまま格納しており、
-- handle_new_userトリガーのようなpublic.users向けの正規化('twitter'→'x')は行わない。
create function public.check_sns_email_conflict(p_email text)
returns text
language sql
security definer
set search_path = auth, public
stable
as $$
  select provider
  from auth.identities
  where provider in ('google', 'apple', 'twitter')
    and lower(identity_data ->> 'email') = lower(p_email)
  limit 1;
$$;

revoke execute on function public.check_sns_email_conflict(text) from public;
revoke execute on function public.check_sns_email_conflict(text) from authenticated;
grant execute on function public.check_sns_email_conflict(text) to service_role;
