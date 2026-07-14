-- get_today_shots_remaining: 当日のグループの残り撮影可能枚数を取得するQueryを検証する(issue #21 / 仕様書 5.2.3・6.3参照)。
begin;
select plan(8);

insert into auth.users (id) values
  ('d1000000-0000-0000-0000-000000000001'), -- 固定グループの現役メンバー
  ('d1000000-0000-0000-0000-000000000002'); -- 固定グループの非メンバー

insert into public.users (id, auth_provider, display_name)
values
  ('d1000000-0000-0000-0000-000000000001', 'email', 'Remaining Member'),
  ('d1000000-0000-0000-0000-000000000002', 'email', 'Remaining Non Member');

-- 上限10枚のgroupモードのグループ(撮影0枚)
insert into public.groups (id, name, mode, created_by)
values ('d2000000-0000-0000-0000-000000000001', 'Remaining Test Group', 'group', 'd1000000-0000-0000-0000-000000000001');

insert into public.group_members (group_id, user_id)
values ('d2000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001');

-- 上限3枚のsoloモードのグループ(撮影2枚)
insert into public.groups (id, name, mode, created_by)
values ('d2000000-0000-0000-0000-000000000002', 'Remaining Test Solo', 'solo', 'd1000000-0000-0000-0000-000000000001');

insert into public.group_members (group_id, user_id)
values ('d2000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000001');

insert into public.photos (group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
values
  ('d2000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000001',
   (((current_timestamp at time zone 'Asia/Tokyo')::date) + time '12:00') at time zone 'Asia/Tokyo',
   (current_timestamp at time zone 'Asia/Tokyo')::date, 'so/1.jpg', 'sb/1.jpg'),
  ('d2000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000001',
   (((current_timestamp at time zone 'Asia/Tokyo')::date) + time '12:00') at time zone 'Asia/Tokyo',
   (current_timestamp at time zone 'Asia/Tokyo')::date, 'so/2.jpg', 'sb/2.jpg');

-- 前日撮影分(当日のカウント対象外)を持つグループ
insert into public.groups (id, name, mode, created_by)
values ('d2000000-0000-0000-0000-000000000003', 'Remaining Test Yesterday', 'group', 'd1000000-0000-0000-0000-000000000001');

insert into public.group_members (group_id, user_id)
values ('d2000000-0000-0000-0000-000000000003', 'd1000000-0000-0000-0000-000000000001');

insert into public.photos (group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
values (
  'd2000000-0000-0000-0000-000000000003', 'd1000000-0000-0000-0000-000000000001',
  (((current_timestamp at time zone 'Asia/Tokyo')::date - 1) + time '12:00') at time zone 'Asia/Tokyo',
  (current_timestamp at time zone 'Asia/Tokyo')::date - 1, 'o/yesterday.jpg', 'b/yesterday.jpg'
);

-- =====================================================================
-- 1. 撮影0枚のgroupモードは上限枚数(10)がそのまま返る
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "d1000000-0000-0000-0000-000000000001"}';

select results_eq(
  $$ select public.get_today_shots_remaining('d2000000-0000-0000-0000-000000000001') $$,
  $$ values (10) $$,
  'groupモードは撮影0枚なら残り10枚'
);

-- =====================================================================
-- 2. soloモードは撮影2枚済みなので残り1枚(上限3枚)
-- =====================================================================
select results_eq(
  $$ select public.get_today_shots_remaining('d2000000-0000-0000-0000-000000000002') $$,
  $$ values (1) $$,
  'soloモードは撮影2枚なら残り1枚(上限3枚)'
);

-- =====================================================================
-- 3. 前日撮影分は当日の残数カウントに影響しない
-- =====================================================================
select results_eq(
  $$ select public.get_today_shots_remaining('d2000000-0000-0000-0000-000000000003') $$,
  $$ values (10) $$,
  '前日撮影分は当日の残数カウントに含まれない'
);

reset role;

-- =====================================================================
-- 4. 非メンバーは呼び出せない
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "d1000000-0000-0000-0000-000000000002"}';

select throws_ok(
  $$ select public.get_today_shots_remaining('d2000000-0000-0000-0000-000000000001') $$,
  null,
  null,
  'get_today_shots_remainingは非メンバーからの呼び出しを拒否する'
);

reset role;

-- =====================================================================
-- 5. 存在しないグループは拒否される
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "d1000000-0000-0000-0000-000000000001"}';

select throws_ok(
  $$ select public.get_today_shots_remaining('99999999-0000-0000-0000-000000000000') $$,
  null,
  null,
  'get_today_shots_remainingは存在しないグループを拒否する'
);

reset role;

-- =====================================================================
-- 6. anonロールは実行できない
-- =====================================================================
set local role anon;

select throws_ok(
  $$ select public.get_today_shots_remaining('d2000000-0000-0000-0000-000000000001') $$,
  null,
  null,
  'anonロールはget_today_shots_remainingを実行できない'
);

reset role;

-- =====================================================================
-- 7. 上限に達したグループは0枚(マイナスにならない)を返す
-- =====================================================================
insert into public.photos (group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
values (
  'd2000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000001',
  (((current_timestamp at time zone 'Asia/Tokyo')::date) + time '12:00') at time zone 'Asia/Tokyo',
  (current_timestamp at time zone 'Asia/Tokyo')::date, 'so/3.jpg', 'sb/3.jpg'
);

set local role authenticated;
set local request.jwt.claims to '{"sub": "d1000000-0000-0000-0000-000000000001"}';

select results_eq(
  $$ select public.get_today_shots_remaining('d2000000-0000-0000-0000-000000000002') $$,
  $$ values (0) $$,
  '上限に達したグループは残り0枚を返す'
);

-- =====================================================================
-- 8. photosテーブルがRealtime publicationに含まれる
-- =====================================================================
select results_eq(
  $$ select count(*)::int from pg_publication_tables
     where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'photos' $$,
  $$ values (1) $$,
  'photosテーブルはsupabase_realtime publicationに含まれる'
);

reset role;

select * from finish();
rollback;
