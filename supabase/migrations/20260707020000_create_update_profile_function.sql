-- update_profile: ログイン中の本人のニックネーム・アイコンを更新する(仕様書 3.1.2/6.1参照)。
-- 空白のみのニックネームなど列制約(not null)だけでは防げない不正値をここで弾く。
-- display_name/avatar_urlの直接updateは20260707020001で禁止し、本関数経由のみに限定する。
create function public.update_profile(p_display_name text, p_avatar_url text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_display_name is null or trim(p_display_name) = '' then
    raise exception 'display_name must not be blank';
  end if;

  update public.users
  set display_name = trim(p_display_name),
      avatar_url = p_avatar_url
  where id = auth.uid();
end;
$$;

revoke execute on function public.update_profile(text, text) from public;
grant execute on function public.update_profile(text, text) to authenticated;
