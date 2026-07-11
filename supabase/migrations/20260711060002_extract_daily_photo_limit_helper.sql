-- 1日の撮影上限枚数(仕様書 5.2参照: solo=3枚、group/event=10枚)が
-- check_photo_daily_limitトリガーとget_today_shots_remaining関数の
-- 2箇所に別々にハードコードされており、片方だけ変更すると表示上の残数と
-- 実際に強制される上限が静かにズレる恐れがあったため、共通関数に切り出す。
create function public.get_daily_photo_limit(p_group_mode text)
returns integer
language sql
immutable
as $$
  select case when p_group_mode = 'solo' then 3 else 10 end;
$$;

create or replace function public.check_photo_daily_limit()
returns trigger
language plpgsql
as $$
declare
  group_mode text;
  daily_limit integer;
  photo_count integer;
begin
  new.taken_date := (new.taken_at at time zone 'Asia/Tokyo')::date;

  perform pg_advisory_xact_lock(hashtextextended(new.group_id::text || ':' || new.taken_date::text, 0));

  select mode into group_mode
  from public.groups
  where id = new.group_id;

  daily_limit := public.get_daily_photo_limit(group_mode);

  select count(*) into photo_count
  from public.photos
  where group_id = new.group_id
    and taken_date = new.taken_date;

  if photo_count >= daily_limit then
    raise exception 'photos: group % already has % photos on % (max %)', new.group_id, photo_count, new.taken_date, daily_limit;
  end if;

  return new;
end;
$$;

create or replace function public.get_today_shots_remaining(p_group_id uuid)
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

  v_daily_limit := public.get_daily_photo_limit(v_group_mode);

  v_today := (current_timestamp at time zone 'Asia/Tokyo')::date;

  select count(*) into v_photo_count
  from public.photos
  where group_id = p_group_id
    and taken_date = v_today;

  return greatest(v_daily_limit - v_photo_count, 0);
end;
$$;
