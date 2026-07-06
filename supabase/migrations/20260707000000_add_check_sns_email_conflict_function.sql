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
  select provider
  from auth.identities
  where provider in ('google', 'apple', 'x', 'instagram')
    and identity_data ->> 'email' = lower(p_email)
  limit 1;
$$;

revoke execute on function public.check_sns_email_conflict(text) from public;
revoke execute on function public.check_sns_email_conflict(text) from authenticated;
grant execute on function public.check_sns_email_conflict(text) to service_role;
