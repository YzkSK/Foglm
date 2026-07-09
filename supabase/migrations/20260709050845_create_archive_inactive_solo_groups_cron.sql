-- archive_inactive_solo_groups(#14): 固定グループ(mode=group)のうち、solo_sinceから1週間経過した
-- グループをstatus=archivedへ移行する。solo_sinceがNULL(猶予期間の対象外)のグループや、
-- 既にarchived済みのグループ、イベントグループ(mode=event)は対象外(仕様書 3.2.1/6.2参照)。
-- pg_cronで毎日0時(UTC)に実行するようスケジュールする。
create extension if not exists pg_cron with schema extensions;

create function public.archive_inactive_solo_groups()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.groups
  set status = 'archived'
  where mode = 'group'
    and status = 'active'
    and solo_since is not null
    and solo_since <= now() - interval '7 days';
end;
$$;

revoke execute on function public.archive_inactive_solo_groups() from public;

select cron.schedule(
  'archive_inactive_solo_groups_daily',
  '0 0 * * *',
  $$ select public.archive_inactive_solo_groups(); $$
);
