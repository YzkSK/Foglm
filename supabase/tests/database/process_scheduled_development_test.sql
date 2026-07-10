-- process_scheduled_development (cron): develop_scheduled_atが到来したwaiting_random写真を
-- developedへ更新し、group_id単位で集計した件数を返す(issue #26 / 仕様書3.6・6.5・6.7参照)。
begin;
select plan(9);

insert into auth.users (id) values
  ('e0000000-0000-0000-0000-000000000031'),
  ('e0000000-0000-0000-0000-000000000032');

insert into public.users (id, auth_provider, display_name)
values
  ('e0000000-0000-0000-0000-000000000031', 'email', 'Development Cron Member A'),
  ('e0000000-0000-0000-0000-000000000032', 'email', 'Development Cron Member B');

insert into public.groups (id, name, mode, created_by)
values
  ('f0000000-0000-0000-0000-000000000021', 'Development Cron Group 1', 'group', 'e0000000-0000-0000-0000-000000000031'),
  ('f0000000-0000-0000-0000-000000000022', 'Development Cron Group 2', 'group', 'e0000000-0000-0000-0000-000000000032');

-- 1. group1: develop_scheduled_atが過去の写真が2枚 -> developedに更新され、集計は2件
insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path, status, develop_scheduled_at)
values
  ('a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000021', 'e0000000-0000-0000-0000-000000000031', now() - interval '5 days', current_date - 5, 'original/1.jpg', 'blurred/1.jpg', 'waiting_random', now() - interval '1 hour'),
  ('a0000000-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000021', 'e0000000-0000-0000-0000-000000000031', now() - interval '4 days', current_date - 4, 'original/2.jpg', 'blurred/2.jpg', 'waiting_random', now() - interval '10 minutes');

-- 2. group1: develop_scheduled_atが未来の写真 -> 対象外、waiting_randomのまま
insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path, status, develop_scheduled_at)
values (
  'a0000000-0000-0000-0000-000000000003', 'f0000000-0000-0000-0000-000000000021', 'e0000000-0000-0000-0000-000000000031', now(), current_date, 'original/3.jpg', 'blurred/3.jpg', 'waiting_random', now() + interval '3 days'
);

-- 3. group2: develop_scheduled_atが過去の写真が1枚 -> developedに更新され、集計は1件
insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path, status, develop_scheduled_at)
values (
  'a0000000-0000-0000-0000-000000000004', 'f0000000-0000-0000-0000-000000000022', 'e0000000-0000-0000-0000-000000000032', now() - interval '3 days', current_date - 3, 'original/4.jpg', 'blurred/4.jpg', 'waiting_random', now() - interval '2 hours'
);

-- 4. group2: 既にdevelopedな写真(develop_scheduled_atは過去だが対象外) -> 二重処理されない(冪等性)
insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path, status, develop_scheduled_at, developed_at)
values (
  'a0000000-0000-0000-0000-000000000005', 'f0000000-0000-0000-0000-000000000022', 'e0000000-0000-0000-0000-000000000032', now() - interval '10 days', current_date - 10, 'original/5.jpg', 'blurred/5.jpg', 'developed', now() - interval '10 days', now() - interval '3 days'
);

-- 5. pending_vote状態(投票締め切り前)の写真にdevelop_scheduled_atは通常設定されないが、
--    念のため過去日時が入っていても対象外であることを確認する
insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path, status, develop_scheduled_at)
values (
  'a0000000-0000-0000-0000-000000000006', 'f0000000-0000-0000-0000-000000000021', 'e0000000-0000-0000-0000-000000000031', now(), current_date, 'original/6.jpg', 'blurred/6.jpg', 'pending_vote', now() - interval '1 hour'
);

select results_eq(
  $$ select group_id, developed_count from public.process_scheduled_development() order by group_id $$,
  $$ values
      ('f0000000-0000-0000-0000-000000000021'::uuid, 2::bigint),
      ('f0000000-0000-0000-0000-000000000022'::uuid, 1::bigint)
  $$,
  'aggregated developed counts are grouped by group_id'
);

select is(
  (select status from public.photos where id = 'a0000000-0000-0000-0000-000000000001'),
  'developed',
  'photo 1 (scheduled 1 hour ago) is developed'
);

select isnt(
  (select developed_at from public.photos where id = 'a0000000-0000-0000-0000-000000000001'),
  null,
  'photo 1 has developed_at set'
);

select is(
  (select status from public.photos where id = 'a0000000-0000-0000-0000-000000000002'),
  'developed',
  'photo 2 (scheduled 10 minutes ago) is developed'
);

select is(
  (select status from public.photos where id = 'a0000000-0000-0000-0000-000000000003'),
  'waiting_random',
  'photo 3 with a future develop_scheduled_at stays waiting_random'
);

select is(
  (select status from public.photos where id = 'a0000000-0000-0000-0000-000000000004'),
  'developed',
  'photo 4 in group2 is developed'
);

select is(
  (select developed_at from public.photos where id = 'a0000000-0000-0000-0000-000000000005'),
  (now() - interval '3 days')::timestamptz,
  'already-developed photo 5 keeps its original developed_at (not reprocessed)'
);

select is(
  (select status from public.photos where id = 'a0000000-0000-0000-0000-000000000006'),
  'pending_vote',
  'pending_vote photo is untouched even if develop_scheduled_at is in the past'
);

select isnt_empty(
  $$ select 1 from cron.job where jobname = 'process_scheduled_development_hourly' and schedule = '0 * * * *' $$,
  'process_scheduled_development is registered as an hourly pg_cron job'
);

select * from finish();
rollback;
