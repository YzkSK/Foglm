-- get_today_shots_remaining: 当日のグループの残り撮影可能枚数を取得するQuery(仕様書 5.2.3/6.3参照)。
-- カメラ撮影画面(S06)がRealtimeで購読し、他メンバーの撮影による残数減少を
-- 即座に反映する(仕様書 5.2.3参照)。上限枚数の算出はcheck_photo_daily_limit
-- トリガー(INSERT時の最終防衛)と同じ基準(仕様書 5.2参照: solo=3枚、group/event=10枚)。
create function public.get_today_shots_remaining(p_group_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_group_mode text;
  v_daily_limit integer;
  v_today date;
  v_photo_count integer;
begin
  if auth.uid() is null then
    raise exception 'get_today_shots_remaining: authentication required';
  end if;

  if not public.is_active_member(p_group_id, auth.uid()) then
    raise exception 'get_today_shots_remaining: caller is not an active member of the group';
  end if;

  select mode into v_group_mode from public.groups where id = p_group_id;

  if v_group_mode is null then
    raise exception 'get_today_shots_remaining: group not found';
  end if;

  v_daily_limit := case when v_group_mode = 'solo' then 3 else 10 end;

  -- 撮影枚数のカウント対象日は、check_photo_daily_limitトリガーと同じく
  -- 日本時間(Asia/Tokyo)基準の「今日」とする(仕様書 5.2.1参照)。
  v_today := (current_timestamp at time zone 'Asia/Tokyo')::date;

  select count(*) into v_photo_count
  from public.photos
  where group_id = p_group_id
    and taken_date = v_today;

  return greatest(v_daily_limit - v_photo_count, 0);
end;
$$;

revoke execute on function public.get_today_shots_remaining(uuid) from public;
grant execute on function public.get_today_shots_remaining(uuid) to authenticated;

-- カメラ撮影画面(S06)がRealtimeで購読するため、photosテーブルの変更を
-- supabase_realtime publicationに追加する(仕様書 5.2.3参照)。
alter publication supabase_realtime add table public.photos;
