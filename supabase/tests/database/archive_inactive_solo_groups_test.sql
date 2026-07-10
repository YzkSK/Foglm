-- archive_inactive_solo_groups (cron): solo_sinceから1週間経過した固定グループをarchivedへ移行する(issue #14 / 仕様書6.2参照)。
begin;
select plan(6);

insert into auth.users (id) values ('e0000000-0000-0000-0000-000000000001');

insert into public.users (id, auth_provider, display_name)
values ('e0000000-0000-0000-0000-000000000001', 'email', 'Archive Cron Member');

-- 1. solo_sinceから8日経過した固定グループはarchivedになる
insert into public.groups (id, name, mode, created_by, solo_since)
values ('f0000000-0000-0000-0000-000000000001', 'Archive Cron Expired', 'group', 'e0000000-0000-0000-0000-000000000001', now() - interval '8 days');

-- 2. solo_sinceから3日しか経過していない固定グループはactiveのまま
insert into public.groups (id, name, mode, created_by, solo_since)
values ('f0000000-0000-0000-0000-000000000002', 'Archive Cron Recent', 'group', 'e0000000-0000-0000-0000-000000000001', now() - interval '3 days');

-- 3. solo_sinceがNULLの固定グループ(新規作成直後で猶予期間の対象外)はactiveのまま
insert into public.groups (id, name, mode, created_by)
values ('f0000000-0000-0000-0000-000000000003', 'Archive Cron Never Solo', 'group', 'e0000000-0000-0000-0000-000000000001');

-- 4. 既にarchived状態の固定グループ(solo_sinceが古くても)はarchivedのまま変化しない
insert into public.groups (id, name, mode, created_by, solo_since, status)
values ('f0000000-0000-0000-0000-000000000004', 'Archive Cron Already Archived', 'group', 'e0000000-0000-0000-0000-000000000001', now() - interval '30 days', 'archived');

-- 5. mode=event はsolo_sinceの猶予期間ルール対象外(仮に古いsolo_sinceが入っていても無視する)
insert into public.groups (id, name, mode, start_date, end_date, created_by, solo_since)
values ('f0000000-0000-0000-0000-000000000005', 'Archive Cron Event', 'event', current_date, current_date + 7, 'e0000000-0000-0000-0000-000000000001', now() - interval '8 days');

select public.archive_inactive_solo_groups();

select is(
  (select status from public.groups where id = 'f0000000-0000-0000-0000-000000000001'),
  'archived',
  'fixed group with solo_since 8 days ago is archived'
);

select is(
  (select status from public.groups where id = 'f0000000-0000-0000-0000-000000000002'),
  'active',
  'fixed group with solo_since 3 days ago stays active'
);

select is(
  (select status from public.groups where id = 'f0000000-0000-0000-0000-000000000003'),
  'active',
  'fixed group with solo_since null (never solo) stays active'
);

select is(
  (select status from public.groups where id = 'f0000000-0000-0000-0000-000000000004'),
  'archived',
  'already archived fixed group remains archived (idempotent)'
);

select is(
  (select status from public.groups where id = 'f0000000-0000-0000-0000-000000000005'),
  'active',
  'event group is untouched by the solo grace-period cron regardless of solo_since'
);

select isnt_empty(
  $$ select 1 from cron.job where jobname = 'archive_inactive_solo_groups_daily' and schedule = '0 0 * * *' $$,
  'archive_inactive_solo_groups is registered as a daily pg_cron job'
);

select * from finish();
rollback;
