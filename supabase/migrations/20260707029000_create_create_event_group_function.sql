-- create_event_group: イベントグループ(mode=event)を開始日・終了日を指定して作成し、
-- 作成者をgroup_membersに登録するRPC(仕様書 3.11/6.2 create_event_group参照)。
-- アプリ利用者であれば誰でも作成可能(固定グループのメンバーである必要はない)。
-- create_groupと同様の理由(groups_select_active_memberポリシー)によりsecurity definerとし、
-- created_by/user_idは常に呼び出し元のauth.uid()に固定する(仕様書 8.1参照)。
create function public.create_event_group(p_name text, p_start_date date, p_end_date date)
returns public.groups
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group public.groups;
begin
  if auth.uid() is null then
    raise exception 'create_event_group: authentication required';
  end if;

  if p_name is null or btrim(p_name) = '' then
    raise exception 'create_event_group: name must not be empty';
  end if;

  if p_start_date is null or p_end_date is null then
    raise exception 'create_event_group: start_date and end_date must not be null';
  end if;

  if p_end_date < p_start_date then
    raise exception 'create_event_group: end_date must not be before start_date';
  end if;

  insert into public.groups (name, mode, start_date, end_date, created_by)
  values (btrim(p_name), 'event', p_start_date, p_end_date, auth.uid())
  returning * into v_group;

  insert into public.group_members (group_id, user_id)
  values (v_group.id, auth.uid());

  return v_group;
end;
$$;

revoke execute on function public.create_event_group(text, date, date) from public;
grant execute on function public.create_event_group(text, date, date) to authenticated;
