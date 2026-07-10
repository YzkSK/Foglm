-- leave_group: 残り1人だったメンバーもさらに脱退し、現役メンバーが0人になった場合は
-- 猶予期間を待たず即座に解散する(#16)。dissolve_group と同じ完全削除処理
-- (dissolve_group_data)を共通利用する(仕様書 3.2.1/6.2参照)。
create or replace function public.leave_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group public.groups;
  v_updated_count integer;
  v_new_creator uuid;
  v_active_count integer;
begin
  if auth.uid() is null then
    raise exception 'leave_group: authentication required';
  end if;

  if p_group_id is null then
    raise exception 'leave_group: group_id must not be null';
  end if;

  select * into v_group from public.groups where id = p_group_id;

  if v_group.id is null then
    raise exception 'leave_group: group not found';
  end if;

  if v_group.mode = 'solo' then
    raise exception 'leave_group: cannot leave a solo group';
  end if;

  update public.group_members
  set left_at = now()
  where group_id = p_group_id
    and user_id = auth.uid()
    and left_at is null;

  get diagnostics v_updated_count = row_count;

  if v_updated_count = 0 then
    raise exception 'leave_group: not an active member of this group';
  end if;

  if v_group.mode = 'group' and v_group.created_by = auth.uid() then
    select user_id into v_new_creator
    from public.group_members
    where group_id = p_group_id
      and left_at is null
    order by random()
    limit 1;

    if v_new_creator is not null then
      update public.groups
      set created_by = v_new_creator
      where id = p_group_id;
    end if;
  end if;

  if v_group.mode = 'group' then
    select count(*) into v_active_count
    from public.group_members
    where group_id = p_group_id
      and left_at is null;

    if v_active_count = 0 then
      perform public.dissolve_group_data(p_group_id);
    elsif v_active_count = 1 then
      update public.groups
      set solo_since = now()
      where id = p_group_id;
    end if;
  end if;
end;
$$;

revoke execute on function public.leave_group(uuid) from public;
grant execute on function public.leave_group(uuid) to authenticated;
