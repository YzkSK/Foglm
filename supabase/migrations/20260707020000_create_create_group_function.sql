-- create_group: 固定グループ(mode=group)を作成し、作成者をgroup_membersに登録するRPC(仕様書 3.2/6.2 create_group参照)。
-- groups の SELECT ポリシー(groups_select_active_member)は group_members に現役メンバー行が
-- 存在することを要求するため、groups への INSERT 直後(まだ group_members 登録前)は
-- RETURNING句の可視性チェックでRLS違反になってしまう。そのため security definer とし、
-- created_by/user_id は常に呼び出し元の auth.uid() に固定して安全性を担保する(仕様書 8.1参照)。
create function public.create_group(p_name text)
returns public.groups
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group public.groups;
begin
  if auth.uid() is null then
    raise exception 'create_group: authentication required';
  end if;

  if p_name is null or btrim(p_name) = '' then
    raise exception 'create_group: name must not be empty';
  end if;

  insert into public.groups (name, mode, created_by)
  values (btrim(p_name), 'group', auth.uid())
  returning * into v_group;

  insert into public.group_members (group_id, user_id)
  values (v_group.id, auth.uid());

  return v_group;
end;
$$;

revoke execute on function public.create_group(text) from public;
grant execute on function public.create_group(text) to authenticated;
