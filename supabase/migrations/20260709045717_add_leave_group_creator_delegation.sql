-- leave_group: 作成者権限の自動委譲(#15)
-- 固定グループ(mode=group)の作成者が脱退した場合、残っている現役メンバーの中から
-- ランダムに1人を選び groups.created_by を委譲する(解散権限もこの新しい作成者に移る)。
-- 残り現役メンバーが0人になる場合は「メンバー0人」ルール(即座解散、#16)が優先されるため委譲しない。
-- イベントグループには解散機能が存在しないため、作成者脱退時の委譲は行わない
-- (仕様書 3.2.1/6.2 leave_group参照)。
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
end;
$$;

revoke execute on function public.leave_group(uuid) from public;
grant execute on function public.leave_group(uuid) to authenticated;
