alter table public.users
add column profile_completed_at timestamptz;

create or replace function public.update_profile(p_display_name text, p_avatar_url text)
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
      avatar_url = p_avatar_url,
      profile_completed_at = coalesce(profile_completed_at, now())
  where id = auth.uid();
end;
$$;

revoke execute on function public.update_profile(text, text) from public;
grant execute on function public.update_profile(text, text) to authenticated;
