-- handle_new_userはauth.usersへのINSERT時点の状態しかpublic.usersへ反映しないため、
-- メール/パスワード登録者が後から確認メールのリンクを踏んでauth.users.email_confirmed_atが
-- 設定されても、public.users.email_verifiedはfalseのままになってしまう。
-- auth.users.email_confirmed_atの更新を検知してpublic.users.email_verifiedへ同期する。
create function public.sync_email_verified()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email_confirmed_at is not null and old.email_confirmed_at is null then
    update public.users
    set email_verified = true
    where id = new.id;
  end if;

  return new;
end;
$$;

create trigger on_auth_user_email_confirmed
  after update of email_confirmed_at on auth.users
  for each row execute function public.sync_email_verified();
