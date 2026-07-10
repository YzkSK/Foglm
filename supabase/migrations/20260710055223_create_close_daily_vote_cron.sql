-- close_daily_vote(#25): その日付のdaily_votes.status=openの行を全グループ分(固定・イベント・
-- ソロ問わず)走査し、vote_entriesを集計して最多得票の写真を当選とする。同数の場合はランダムで
-- 1枚選出し、投票が0件の場合は撮影された写真からランダムで1枚選出する(仕様書3.5参照)。
-- 当選写真は即時developedに更新し、落選写真にはdevelop_scheduled_at(撮影日+3〜14日の
-- ランダム値)を設定してwaiting_randomにする(仕様書3.6/6.4参照)。
-- 現像完了通知の送信は含まない(issue #31で別途対応)。
-- pg_cronで毎日 日本時間24:00(=UTC15:00) に実行するようスケジュールする(仕様書6.7参照)。
create extension if not exists pg_cron with schema extensions;

create function public.close_daily_vote()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_daily_vote record;
  v_winner_photo_id uuid;
begin
  for v_daily_vote in
    select * from public.daily_votes
    where status = 'open'
      and vote_date <= current_date
  loop
    -- 最多得票の写真を集計。同数の場合はrandom()でタイブレークする。
    select ve.photo_id
    into v_winner_photo_id
    from public.vote_entries ve
    where ve.daily_vote_id = v_daily_vote.id
    group by ve.photo_id
    order by count(*) desc, random()
    limit 1;

    if v_winner_photo_id is null then
      -- 投票が1票も入らなかった場合、撮影された写真からランダムに1枚選出する。
      select p.id
      into v_winner_photo_id
      from public.photos p
      where p.group_id = v_daily_vote.group_id
        and p.taken_date = v_daily_vote.vote_date
        and p.status = 'pending_vote'
      order by random()
      limit 1;
    end if;

    if v_winner_photo_id is null then
      -- 対象写真が存在しない場合(通常は発生しない防御的ガード)、この投票行はスキップする。
      continue;
    end if;

    update public.photos
    set status = 'developed',
        developed_at = now()
    where id = v_winner_photo_id;

    -- 落選写真: 撮影日+3〜14日のランダムな日を現像予定日に設定する(仕様書3.6参照)。
    update public.photos
    set status = 'waiting_random',
        develop_scheduled_at = (taken_date + ((3 + floor(random() * 12))::int))::timestamptz
    where group_id = v_daily_vote.group_id
      and taken_date = v_daily_vote.vote_date
      and status = 'pending_vote'
      and id <> v_winner_photo_id;

    update public.daily_votes
    set winner_photo_id = v_winner_photo_id,
        status = 'closed',
        closed_at = now()
    where id = v_daily_vote.id;
  end loop;
end;
$$;

revoke execute on function public.close_daily_vote() from public;

select cron.schedule(
  'close_daily_vote_daily',
  '0 15 * * *',
  $$ select public.close_daily_vote(); $$
);
