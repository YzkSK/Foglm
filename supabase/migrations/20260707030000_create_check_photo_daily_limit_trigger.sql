-- taken_dateをtaken_atから算出した上で、group_id×taken_dateの1日の撮影上限を超える
-- INSERTを拒否する(仕様書 5.2.1/5.2.2参照)。
-- アプリ側の事前チェック(get_today_shots_remaining等)は早期エラー表示用の補助であり、
-- 最終的な上限担保はここで行う(check_group_member_limitと同様の設計)。
create function public.check_photo_daily_limit()
returns trigger
language plpgsql
as $$
declare
  group_mode text;
  daily_limit integer;
  photo_count integer;
begin
  -- taken_date は taken_at を日本時間(Asia/Tokyo)に変換した日付部分から算出する(仕様書 5.2.1参照)
  new.taken_date := (new.taken_at at time zone 'Asia/Tokyo')::date;

  -- group_id×taken_date単位でアドバイザリロックを取得し、同時撮影による
  -- カウント→判定のすり抜け(上限超過)を防ぐ(仕様書 5.2.2参照)。
  perform pg_advisory_xact_lock(hashtextextended(new.group_id::text || ':' || new.taken_date::text, 0));

  select mode into group_mode
  from public.groups
  where id = new.group_id;

  -- 1日の上限枚数はgroups.modeで出し分ける(仕様書 5.2参照): solo=3枚、group/event=10枚
  daily_limit := case when group_mode = 'solo' then 3 else 10 end;

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

create trigger trg_check_photo_daily_limit
  before insert on public.photos
  for each row
  execute function public.check_photo_daily_limit();
