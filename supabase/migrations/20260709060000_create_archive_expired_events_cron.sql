-- archive_expired_events(#17): イベントグループ(mode=event)のうち、end_dateを過ぎた
-- グループをstatus=archivedへ移行する。既にarchived済みのグループや固定グループ・
-- ソロ(mode=group/solo)は対象外(仕様書 3.11/6.2参照)。
-- pg_cronで毎日0時(UTC)に実行するようスケジュールする。
create extension if not exists pg_cron with schema extensions;

create function public.archive_expired_events()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.groups
  set status = 'archived'
  where mode = 'event'
    and status = 'active'
    and end_date < current_date;
end;
$$;

revoke execute on function public.archive_expired_events() from public;

select cron.schedule(
  'archive_expired_events_daily',
  '0 0 * * *',
  $$ select public.archive_expired_events(); $$
);
