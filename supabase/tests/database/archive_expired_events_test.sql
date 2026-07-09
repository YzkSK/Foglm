-- archive_expired_events (cron): end_dateを過ぎたイベントグループをarchivedへ移行する(issue #17 / 仕様書3.11・6.2参照)。
begin;
select plan(6);

insert into auth.users (id) values ('e0000000-0000-0000-0000-000000000002');

insert into public.users (id, auth_provider, display_name)
values ('e0000000-0000-0000-0000-000000000002', 'email', 'Archive Cron Event Member');

-- 1. end_dateが昨日のイベントグループはarchivedになる
insert into public.groups (id, name, mode, start_date, end_date, created_by)
values ('f0000000-0000-0000-0000-000000000011', 'Archive Cron Event Expired', 'event', current_date - 7, current_date - 1, 'e0000000-0000-0000-0000-000000000002');

-- 2. end_dateが今日のイベントグループはまだactiveのまま(過ぎていない)
insert into public.groups (id, name, mode, start_date, end_date, created_by)
values ('f0000000-0000-0000-0000-000000000012', 'Archive Cron Event Today', 'event', current_date - 7, current_date, 'e0000000-0000-0000-0000-000000000002');

-- 3. end_dateが未来のイベントグループはactiveのまま
insert into public.groups (id, name, mode, start_date, end_date, created_by)
values ('f0000000-0000-0000-0000-000000000013', 'Archive Cron Event Future', 'event', current_date, current_date + 7, 'e0000000-0000-0000-0000-000000000002');

-- 4. 既にarchived状態のイベントグループ(end_dateが過去でも)はarchivedのまま変化しない
insert into public.groups (id, name, mode, start_date, end_date, created_by, status)
values ('f0000000-0000-0000-0000-000000000014', 'Archive Cron Event Already Archived', 'event', current_date - 30, current_date - 20, 'e0000000-0000-0000-0000-000000000002', 'archived');

-- 5. mode=group はend_dateの自動クローズルール対象外(仮に古いend_dateが入っていても無視する)
insert into public.groups (id, name, mode, end_date, created_by)
values ('f0000000-0000-0000-0000-000000000015', 'Archive Cron Fixed Group', 'group', current_date - 1, 'e0000000-0000-0000-0000-000000000002');

select public.archive_expired_events();

select is(
  (select status from public.groups where id = 'f0000000-0000-0000-0000-000000000011'),
  'archived',
  'event group with end_date yesterday is archived'
);

select is(
  (select status from public.groups where id = 'f0000000-0000-0000-0000-000000000012'),
  'active',
  'event group with end_date today stays active (not yet past)'
);

select is(
  (select status from public.groups where id = 'f0000000-0000-0000-0000-000000000013'),
  'active',
  'event group with future end_date stays active'
);

select is(
  (select status from public.groups where id = 'f0000000-0000-0000-0000-000000000014'),
  'archived',
  'already archived event group remains archived (idempotent)'
);

select is(
  (select status from public.groups where id = 'f0000000-0000-0000-0000-000000000015'),
  'active',
  'fixed group is untouched by the event expiry cron regardless of end_date'
);

select isnt_empty(
  $$ select 1 from cron.job where jobname = 'archive_expired_events_daily' and schedule = '0 0 * * *' $$,
  'archive_expired_events is registered as a daily pg_cron job'
);

select * from finish();
rollback;
