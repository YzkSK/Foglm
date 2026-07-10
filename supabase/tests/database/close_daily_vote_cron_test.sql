-- close_daily_vote (cron): 投票締め切り・当選写真の即時現像・落選写真のランダム現像予約(issue #25 / 仕様書3.5・3.6・6.4・6.7参照)。
-- check_photo_daily_limitトリガーがtaken_dateをAsia/Tokyo基準で上書きするため、
-- vote_date/taken_atもJST基準に揃える(issue #187)。
begin;
select plan(1);

insert into auth.users (id) values
  ('80000000-0000-0000-0000-000000000001'),
  ('80000000-0000-0000-0000-000000000002'),
  ('80000000-0000-0000-0000-000000000003'),
  ('80000000-0000-0000-0000-000000000004'),
  ('80000000-0000-0000-0000-000000000005');

insert into public.users (id, auth_provider, display_name)
values
  ('80000000-0000-0000-0000-000000000001', 'email', 'Close Vote Member A'),
  ('80000000-0000-0000-0000-000000000002', 'email', 'Close Vote Member B'),
  ('80000000-0000-0000-0000-000000000003', 'email', 'Close Vote Member C'),
  ('80000000-0000-0000-0000-000000000004', 'email', 'Close Vote Member D'),
  ('80000000-0000-0000-0000-000000000005', 'email', 'Close Vote Member E');

-- Scenario 1: majority winner (group G1, photo P1 gets 2 votes, P2 gets 1 vote)
insert into public.groups (id, name, mode, created_by)
values ('81000000-0000-0000-0000-000000000001', 'Close Vote Majority Group', 'group', '80000000-0000-0000-0000-000000000001');

insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
values
  ('82000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001', '80000000-0000-0000-0000-000000000001', (((current_timestamp at time zone 'Asia/Tokyo')::date - 2) + time '12:00') at time zone 'Asia/Tokyo', (current_timestamp at time zone 'Asia/Tokyo')::date - 2, 'original/p1.jpg', 'blurred/p1.jpg'),
  ('82000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000001', '80000000-0000-0000-0000-000000000001', (((current_timestamp at time zone 'Asia/Tokyo')::date - 2) + time '12:00') at time zone 'Asia/Tokyo', (current_timestamp at time zone 'Asia/Tokyo')::date - 2, 'original/p2.jpg', 'blurred/p2.jpg');

insert into public.daily_votes (id, group_id, vote_date, status)
values ('83000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001', (current_timestamp at time zone 'Asia/Tokyo')::date - 2, 'open');

insert into public.vote_entries (daily_vote_id, user_id, photo_id)
values
  ('83000000-0000-0000-0000-000000000001', '80000000-0000-0000-0000-000000000001', '82000000-0000-0000-0000-000000000001'),
  ('83000000-0000-0000-0000-000000000001', '80000000-0000-0000-0000-000000000002', '82000000-0000-0000-0000-000000000001'),
  ('83000000-0000-0000-0000-000000000001', '80000000-0000-0000-0000-000000000003', '82000000-0000-0000-0000-000000000002');

-- Scenario 2: tie (group G2, photos P3 and P4 each get 1 vote)
insert into public.groups (id, name, mode, created_by)
values ('81000000-0000-0000-0000-000000000002', 'Close Vote Tie Group', 'group', '80000000-0000-0000-0000-000000000004');

insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
values
  ('82000000-0000-0000-0000-000000000003', '81000000-0000-0000-0000-000000000002', '80000000-0000-0000-0000-000000000004', (((current_timestamp at time zone 'Asia/Tokyo')::date - 2) + time '12:00') at time zone 'Asia/Tokyo', (current_timestamp at time zone 'Asia/Tokyo')::date - 2, 'original/p3.jpg', 'blurred/p3.jpg'),
  ('82000000-0000-0000-0000-000000000004', '81000000-0000-0000-0000-000000000002', '80000000-0000-0000-0000-000000000004', (((current_timestamp at time zone 'Asia/Tokyo')::date - 2) + time '12:00') at time zone 'Asia/Tokyo', (current_timestamp at time zone 'Asia/Tokyo')::date - 2, 'original/p4.jpg', 'blurred/p4.jpg');

insert into public.daily_votes (id, group_id, vote_date, status)
values ('83000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000002', (current_timestamp at time zone 'Asia/Tokyo')::date - 2, 'open');

insert into public.vote_entries (daily_vote_id, user_id, photo_id)
values
  ('83000000-0000-0000-0000-000000000002', '80000000-0000-0000-0000-000000000004', '82000000-0000-0000-0000-000000000003'),
  ('83000000-0000-0000-0000-000000000002', '80000000-0000-0000-0000-000000000005', '82000000-0000-0000-0000-000000000004');

-- Scenario 3: zero votes (group G3, photo P5 has no votes at all)
insert into public.groups (id, name, mode, created_by)
values ('81000000-0000-0000-0000-000000000003', 'Close Vote Zero Votes Group', 'group', '80000000-0000-0000-0000-000000000001');

insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
values ('82000000-0000-0000-0000-000000000005', '81000000-0000-0000-0000-000000000003', '80000000-0000-0000-0000-000000000001', (((current_timestamp at time zone 'Asia/Tokyo')::date - 2) + time '12:00') at time zone 'Asia/Tokyo', (current_timestamp at time zone 'Asia/Tokyo')::date - 2, 'original/p5.jpg', 'blurred/p5.jpg');

insert into public.daily_votes (id, group_id, vote_date, status)
values ('83000000-0000-0000-0000-000000000003', '81000000-0000-0000-0000-000000000003', (current_timestamp at time zone 'Asia/Tokyo')::date - 2, 'open');

-- Scenario 4: already closed (group G4) must stay untouched
insert into public.groups (id, name, mode, created_by)
values ('81000000-0000-0000-0000-000000000004', 'Close Vote Already Closed Group', 'group', '80000000-0000-0000-0000-000000000001');

insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path, status)
values ('82000000-0000-0000-0000-000000000006', '81000000-0000-0000-0000-000000000004', '80000000-0000-0000-0000-000000000001', (((current_timestamp at time zone 'Asia/Tokyo')::date - 2) + time '12:00') at time zone 'Asia/Tokyo', (current_timestamp at time zone 'Asia/Tokyo')::date - 2, 'original/p6.jpg', 'blurred/p6.jpg', 'developed');

insert into public.daily_votes (id, group_id, vote_date, status, winner_photo_id, closed_at)
values ('83000000-0000-0000-0000-000000000004', '81000000-0000-0000-0000-000000000004', (current_timestamp at time zone 'Asia/Tokyo')::date - 2, 'closed', '82000000-0000-0000-0000-000000000006', now() - interval '1 day');

-- Scenario 5: vote_date in the future (group G5) must not be processed yet
insert into public.groups (id, name, mode, created_by)
values ('81000000-0000-0000-0000-000000000005', 'Close Vote Future Group', 'group', '80000000-0000-0000-0000-000000000001');

insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
values ('82000000-0000-0000-0000-000000000007', '81000000-0000-0000-0000-000000000005', '80000000-0000-0000-0000-000000000001', (((current_timestamp at time zone 'Asia/Tokyo')::date + 1) + time '12:00') at time zone 'Asia/Tokyo', (current_timestamp at time zone 'Asia/Tokyo')::date + 1, 'original/p7.jpg', 'blurred/p7.jpg');

insert into public.daily_votes (id, group_id, vote_date, status)
values ('83000000-0000-0000-0000-000000000005', '81000000-0000-0000-0000-000000000005', (current_timestamp at time zone 'Asia/Tokyo')::date + 1, 'open');

select public.close_daily_vote();

-- Scenario 1 assertions
select is(
  (select status from public.photos where id = '82000000-0000-0000-0000-000000000001'),
  'developed',
  'majority-vote photo P1 becomes developed'
);

select isnt(
  (select developed_at from public.photos where id = '82000000-0000-0000-0000-000000000001'),
  null,
  'majority-vote photo P1 has developed_at set'
);

select is(
  (select status from public.photos where id = '82000000-0000-0000-0000-000000000002'),
  'waiting_random',
  'losing photo P2 becomes waiting_random'
);

select ok(
  (select develop_scheduled_at from public.photos where id = '82000000-0000-0000-0000-000000000002')
    between ((current_timestamp at time zone 'Asia/Tokyo')::date - 2 + 3)::timestamptz and ((current_timestamp at time zone 'Asia/Tokyo')::date - 2 + 14)::timestamptz,
  'losing photo P2 develop_scheduled_at falls within taken_date + 3..14 days'
);

select is(
  (select status from public.daily_votes where id = '83000000-0000-0000-0000-000000000001'),
  'closed',
  'daily_votes G1 becomes closed'
);

select is(
  (select winner_photo_id from public.daily_votes where id = '83000000-0000-0000-0000-000000000001'),
  '82000000-0000-0000-0000-000000000001',
  'daily_votes G1 winner_photo_id is the majority-vote photo P1'
);

-- Scenario 2 assertions (tie)
select is(
  (select count(*)::int from public.photos where id in ('82000000-0000-0000-0000-000000000003', '82000000-0000-0000-0000-000000000004') and status = 'developed'),
  1,
  'exactly one of the tied photos (P3/P4) becomes developed'
);

select is(
  (select count(*)::int from public.photos where id in ('82000000-0000-0000-0000-000000000003', '82000000-0000-0000-0000-000000000004') and status = 'waiting_random'),
  1,
  'exactly one of the tied photos (P3/P4) becomes waiting_random'
);

select is(
  (select p.status from public.photos p join public.daily_votes dv on dv.winner_photo_id = p.id where dv.id = '83000000-0000-0000-0000-000000000002'),
  'developed',
  'daily_votes G2 winner_photo_id points to the developed photo'
);

select is(
  (select status from public.daily_votes where id = '83000000-0000-0000-0000-000000000002'),
  'closed',
  'daily_votes G2 becomes closed'
);

-- Scenario 3 assertions (zero votes)
select is(
  (select winner_photo_id from public.daily_votes where id = '83000000-0000-0000-0000-000000000003'),
  '82000000-0000-0000-0000-000000000005',
  'daily_votes G3 with zero votes picks the only photo P5 as winner'
);

select is(
  (select status from public.photos where id = '82000000-0000-0000-0000-000000000005'),
  'developed',
  'zero-vote photo P5 becomes developed'
);

-- Scenario 4 assertions (already closed, untouched)
select is(
  (select status from public.daily_votes where id = '83000000-0000-0000-0000-000000000004'),
  'closed',
  'already-closed daily_votes G4 remains closed (idempotent, not reprocessed)'
);

-- Scenario 5 assertions (future vote_date, not processed)
select is(
  (select status from public.daily_votes where id = '83000000-0000-0000-0000-000000000005'),
  'open',
  'daily_votes G5 with a future vote_date is not processed yet'
);

-- Cron registration
select isnt_empty(
  $$
  select 1 from cron.job
  where jobname = 'close_daily_vote_daily'
    and schedule = '0 15 * * *'
    and command like '%net.http_post%'
    and command like '%close-daily-vote%'
  $$,
  'close_daily_vote_daily is registered as a daily pg_cron job at UTC 15:00 (JST 24:00) invoking the close-daily-vote Edge Function via net.http_post'
);

select * from finish();
rollback;
