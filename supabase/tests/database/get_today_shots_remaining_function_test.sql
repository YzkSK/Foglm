begin;
select plan(9);

insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000041'), -- member
  ('00000000-0000-0000-0000-000000000042'); -- non-member

insert into public.users (id, auth_provider, display_name)
values
  ('00000000-0000-0000-0000-000000000041', 'email', 'Shots Remaining Member'),
  ('00000000-0000-0000-0000-000000000042', 'email', 'Shots Remaining Non Member');

insert into public.groups (id, name, mode, created_by)
values
  ('30000000-0000-0000-0000-000000000001', 'Shots Remaining Group', 'group', '00000000-0000-0000-0000-000000000041'),
  ('30000000-0000-0000-0000-000000000002', 'Shots Remaining Solo', 'solo', '00000000-0000-0000-0000-000000000041');

insert into public.group_members (group_id, user_id)
values
  ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000041'),
  ('30000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000041');

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000041"}';

-- groupモード: 撮影0枚の状態では上限10枚がそのまま残数になる。
select results_eq(
  $$ select public.get_today_shots_remaining('30000000-0000-0000-0000-000000000001') $$,
  $$ values (10) $$,
  '撮影0枚のgroupモードは残り10枚'
);

-- 当日3枚撮影すると残数が3減る。
insert into public.photos (group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
values
  ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000041', now(), '2000-01-01', 'o/1.jpg', 'b/1.jpg'),
  ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000041', now(), '2000-01-01', 'o/2.jpg', 'b/2.jpg'),
  ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000041', now(), '2000-01-01', 'o/3.jpg', 'b/3.jpg');

select results_eq(
  $$ select public.get_today_shots_remaining('30000000-0000-0000-0000-000000000001') $$,
  $$ values (7) $$,
  '当日3枚撮影後は残り7枚'
);

-- 前日の撮影は当日の残数計算に影響しない。
insert into public.photos (group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
values ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000041', now() - interval '1 day', '2000-01-01', 'o/yesterday.jpg', 'b/yesterday.jpg');

select results_eq(
  $$ select public.get_today_shots_remaining('30000000-0000-0000-0000-000000000001') $$,
  $$ values (7) $$,
  '前日の撮影は当日の残数に影響しない'
);

-- soloモードは上限3枚。撮影0枚では残り3枚。
select results_eq(
  $$ select public.get_today_shots_remaining('30000000-0000-0000-0000-000000000002') $$,
  $$ values (3) $$,
  '撮影0枚のsoloモードは残り3枚'
);

-- soloモードで3枚撮影すると残り0枚(上限ちょうど)になる。
insert into public.photos (group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
values
  ('30000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000041', now(), '2000-01-01', 'so/1.jpg', 'sb/1.jpg'),
  ('30000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000041', now(), '2000-01-01', 'so/2.jpg', 'sb/2.jpg'),
  ('30000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000041', now(), '2000-01-01', 'so/3.jpg', 'sb/3.jpg');

select results_eq(
  $$ select public.get_today_shots_remaining('30000000-0000-0000-0000-000000000002') $$,
  $$ values (0) $$,
  'soloモードで上限まで撮影すると残り0枚'
);

-- 存在しないグループはエラーになる。
select throws_ok(
  $$ select public.get_today_shots_remaining('30000000-0000-0000-0000-000000000099') $$,
  null,
  null,
  '存在しないグループはエラーになる'
);

reset role;

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000042"}';

-- 非メンバーは呼び出せない。
select throws_ok(
  $$ select public.get_today_shots_remaining('30000000-0000-0000-0000-000000000001') $$,
  null,
  null,
  '非メンバーはget_today_shots_remainingを呼び出せない'
);

reset role;

-- 未認証(anon)は呼び出せない。
set local role anon;

select throws_ok(
  $$ select public.get_today_shots_remaining('30000000-0000-0000-0000-000000000001') $$,
  null,
  null,
  'anonロールはget_today_shots_remaining関数を実行できない'
);

reset role;

set local role authenticated;
set local request.jwt.claims to '{}';

select throws_ok(
  $$ select public.get_today_shots_remaining('30000000-0000-0000-0000-000000000001') $$,
  null,
  null,
  '未認証状態(auth.uidがNULL)ではget_today_shots_remainingを呼び出せない'
);

reset role;

select * from finish();
rollback;
