-- get_today_shots_remaining: 呼び出し時点(当日・Asia/Tokyo基準)のグループの残り撮影可能枚数を
-- 取得するQuery(仕様書 5.2.3/6.3参照)。1日の上限枚数はgroups.modeで出し分ける
-- (check_photo_daily_limitと同一の基準: solo=3枚、group/event=10枚、仕様書3.3/5.2参照)。
-- カメラ画面(S06)からリアルタイム表示・購読の初期値取得に使う。
create function public.get_today_shots_remaining(p_group_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_group public.groups;
  v_daily_limit integer;
  v_today date;
  v_photo_count integer;
begin
  if auth.uid() is null then
    raise exception 'get_today_shots_remaining: authentication required';
  end if;

  select * into v_group from public.groups where id = p_group_id;

  if v_group.id is null then
    raise exception 'get_today_shots_remaining: group not found';
  end if;

  if not public.is_active_member(p_group_id, auth.uid()) then
    raise exception 'get_today_shots_remaining: caller is not an active member of the group';
  end if;

  v_daily_limit := case when v_group.mode = 'solo' then 3 else 10 end;
  v_today := (now() at time zone 'Asia/Tokyo')::date;

  select count(*) into v_photo_count
  from public.photos
  where group_id = p_group_id
    and taken_date = v_today;

  return greatest(v_daily_limit - v_photo_count, 0);
end;
$$;

revoke execute on function public.get_today_shots_remaining(uuid) from public;
grant execute on function public.get_today_shots_remaining(uuid) to authenticated;
