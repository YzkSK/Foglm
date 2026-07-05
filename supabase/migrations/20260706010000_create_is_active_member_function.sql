-- is_active_member: group_id・user_idの組み合わせが現役メンバー(left_at IS NULL)かどうかを判定する。
-- RLSポリシーからgroup_membersを安全に参照するため security definer とする(仕様書 8.1参照)。
create function public.is_active_member(p_group_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.group_members
    where group_id = p_group_id
      and user_id = p_user_id
      and left_at is null
  );
$$;

grant execute on function public.is_active_member(uuid, uuid) to authenticated;
