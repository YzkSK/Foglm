-- Supabase Authは、確認済みメールアドレスが一致する場合、新しいOAuthログインを
-- 既存のauth.usersに自動的にリンクする(auth.identitiesへの追加INSERTのみが発生し、
-- auth.usersへのINSERTは発生しない)。この自動リンクにより、メール・パスワード方式と
-- SNSログインが同一アカウントに統合されてしまうと、仕様書 3.1で定義された「別々の認証方式
-- として扱い、重複登録を拒否する」という要件を満たせない。
-- そのため、auth.identitiesへのINSERT時点で既存のpublic.users.auth_providerと
-- リンクしようとしているプロバイダが異なる場合は例外を投げてリンク(=ログイン)を拒否する。
create function public.prevent_cross_provider_identity_linking()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_provider text;
  v_existing_provider text;
begin
  v_new_provider := new.provider;

  if v_new_provider = 'twitter' then
    v_new_provider := 'x';
  end if;

  select auth_provider into v_existing_provider
  from public.users
  where id = new.user_id;

  if v_existing_provider is not null and v_existing_provider <> v_new_provider then
    raise exception 'DUPLICATE_ACCOUNT: this email is already registered with % sign-in', v_existing_provider;
  end if;

  return new;
end;
$$;

create trigger on_auth_identity_linked
  after insert on auth.identities
  for each row execute function public.prevent_cross_provider_identity_linking();
