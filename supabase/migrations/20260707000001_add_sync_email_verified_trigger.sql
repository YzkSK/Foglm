-- sync_email_verified: auth.users.email_confirmed_atがNULL以外に変化した際、
-- public.users.email_verifiedをtrueに同期する(仕様書 6.1 verify_email参照)。
-- 確認メール送信・リンク処理自体はSupabase標準機能をそのまま利用する。
create function public.sync_email_verified()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email_confirmed_at is not null and old.email_confirmed_at is null then
    update public.users set email_verified = true where id = new.id;
  end if;
  return new;
end;
$$;

create trigger on_auth_user_email_confirmed
after update of email_confirmed_at on auth.users
for each row
execute function public.sync_email_verified();
