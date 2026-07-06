-- handle_new_user: auth.usersへの新規INSERT時にpublic.usersへ行を同期するトリガー(仕様書 3.1/6.1参照)。
-- raw_app_meta_data.provider が無い行(テストフィクスチャ等の直接INSERT)には作用せず何もしない。
-- SNSログイン(google/apple/x)は email_verified を自動で true とする。
-- 同一メールアドレスでの別方式の重複登録は auth.users 側の一意インデックス(users_email_partial_key)で
-- 既に阻止されるため、ここでは扱わない(別方式でのSNSアカウント自動リンク経由の重複防止は
-- prevent_cross_provider_identity_linking トリガー(auth.identities)側で行う)。
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_provider text;
  v_display_name text;
begin
  v_provider := new.raw_app_meta_data ->> 'provider';

  if v_provider is null then
    return new;
  end if;

  if v_provider = 'twitter' then
    v_provider := 'x';
  end if;

  if v_provider not in ('google', 'apple', 'x', 'email') then
    return new;
  end if;

  v_display_name := coalesce(
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'name',
    split_part(new.email, '@', 1),
    'ユーザー'
  );

  insert into public.users (id, auth_provider, email, email_verified, display_name, avatar_url)
  values (
    new.id,
    v_provider,
    new.email,
    v_provider <> 'email',
    v_display_name,
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
