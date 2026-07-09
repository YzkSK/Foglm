-- join_event_group: イベントグループ(mode=event)へ招待コードからメンバーを追加するRPC
-- (仕様書 3.11/6.2 join_event_group参照)。固定グループのメンバーである必要はなく、
-- アプリ利用者なら誰でも参加できる。招待コードはinvite_codes.codeからgroup_idを解決する
-- (create_invite_codeで発行、仕様書4.1 S05は固定グループ・イベントグループ共通)。
-- 過去に脱退したことがある人が再度参加する場合は、既存のgroup_members行をUPSERT
-- (left_atをNULLに更新)する。人数上限6人はgroup_membersのDBトリガー
-- (check_group_member_limit)で最終的に担保する。
create function public.join_event_group(p_code text)
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
    raise exception 'join_event_group: authentication required';
  end if;

  if p_code is null or btrim(p_code) = '' then
    raise exception 'join_event_group: code must not be empty';
  end if;

  select group_id into v_group_id
  from public.invite_codes
  where code = upper(btrim(p_code));

  if v_group_id is null then
    raise exception 'join_event_group: invalid invite code';
  end if;

  select * into v_group from public.groups where id = v_group_id and mode = 'event';

  if v_group.id is null then
    raise exception 'join_event_group: event group not found';
  end if;

  if v_group.status <> 'active' then
    raise exception 'join_event_group: event group is not active';
  end if;

  insert into public.group_members (group_id, user_id)
  values (v_group_id, auth.uid())
  on conflict (group_id, user_id) do update
    set left_at = null, joined_at = now()
    where public.group_members.left_at is not null;

  return v_group;
end;
$$;

revoke execute on function public.join_event_group(text) from public;
grant execute on function public.join_event_group(text) to authenticated;
