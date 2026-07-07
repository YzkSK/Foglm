-- invite_member: 固定グループ(mode=group)へ招待コードからメンバーを追加するRPC(仕様書 3.2/6.2 invite_member参照)。
-- 招待コードはinvite_codes.codeからgroup_idを解決する。過去に脱退したことがある人が再度参加する場合は、
-- 既存のgroup_members行をUPSERT(left_atをNULLに更新)する。人数上限6人はgroup_membersのDBトリガー
-- (check_group_member_limit)で最終的に担保する。
create function public.invite_member(p_code text)
returns public.groups
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group_id uuid;
  v_group public.groups;
begin
  if auth.uid() is null then
    raise exception 'invite_member: authentication required';
  end if;

  if p_code is null or btrim(p_code) = '' then
    raise exception 'invite_member: code must not be empty';
  end if;

  select group_id into v_group_id
  from public.invite_codes
  where code = btrim(p_code);

  if v_group_id is null then
    raise exception 'invite_member: invalid invite code';
  end if;

  select * into v_group from public.groups where id = v_group_id and mode = 'group';

  if v_group.id is null then
    raise exception 'invite_member: group not found';
  end if;

  if v_group.status <> 'active' then
    raise exception 'invite_member: group is not active';
  end if;

  insert into public.group_members (group_id, user_id)
  values (v_group_id, auth.uid())
  on conflict (group_id, user_id) do update
    set left_at = null, joined_at = now()
    where public.group_members.left_at is not null;

  return v_group;
end;
$$;

revoke execute on function public.invite_member(text) from public;
grant execute on function public.invite_member(text) to authenticated;
