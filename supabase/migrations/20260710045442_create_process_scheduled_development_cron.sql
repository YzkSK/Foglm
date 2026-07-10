-- process_scheduled_development(#26): develop_scheduled_atが到来したwaiting_random状態の写真を
-- developedへ更新し、原本へのアクセスを解放する。通知は写真単位ではなく、同一グループ・同一実行
-- タイミングでまとめて集計する必要がある(仕様書 3.6/6.5参照)ため、更新件数をgroup_id単位で
-- 集計して返す。実際のプッシュ通知送信(FCM呼び出し)はこの集計結果を使って#31で追加する。
-- pg_cronで1時間ごと(毎時0分)に実行するようスケジュールする(仕様書 6.7参照)。
create extension if not exists pg_cron with schema extensions;

create function public.process_scheduled_development()
returns table (group_id uuid, developed_count bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  with updated as (
    update public.photos
    set status = 'developed',
        developed_at = now()
    where status = 'waiting_random'
      and develop_scheduled_at <= now()
    returning photos.group_id
  )
  select updated.group_id, count(*) as developed_count
  from updated
  group by updated.group_id;
end;
$$;

revoke execute on function public.process_scheduled_development() from public;

select cron.schedule(
  'process_scheduled_development_hourly',
  '0 * * * *',
  $$ select public.process_scheduled_development(); $$
);
