-- leave_group: 固定グループ(mode=group)・イベントグループ(mode=event)の両方に対応する脱退RPC
-- (仕様書 3.2.1/6.2 leave_group参照)。本人のgroup_members.left_atに現在時刻を設定する。
-- 以降、RLS(is_active_member)により本人はそのグループの写真・コメント・リアクション等を
-- 一切閲覧できなくなる。
--
-- 作成者権限の自動委譲(#15)・残り1人時のsolo_since設定と猶予期間(#14)・
-- メンバー0人時の即座解散(#16)は、それぞれ別issueのスコープであり本関数では扱わない。
create function public.leave_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group public.groups;
  v_updated_count integer;
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
end;
$$;

revoke execute on function public.leave_group(uuid) from public;
grant execute on function public.leave_group(uuid) to authenticated;
