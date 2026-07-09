-- leave_group: 残り1人になった場合の猶予期間開始(solo_since設定)を検証する(issue #14 / 仕様書 3.2.1・6.2参照)。
begin;
select plan(5);

insert into auth.users (id) values
  ('a0000000-0000-0000-0000-000000000001'), -- 固定グループ: 脱退して2人→1人にするメンバー
  ('a0000000-0000-0000-0000-000000000002'), -- 固定グループ: 残るメンバー
  ('a0000000-0000-0000-0000-000000000003'), -- 固定グループ: 3人→2人になるケース用の脱退者
  ('a0000000-0000-0000-0000-000000000004'), -- 固定グループ: 3人→2人になるケース用の残留者1
  ('a0000000-0000-0000-0000-000000000005'), -- 固定グループ: 3人→2人になるケース用の残留者2
  ('a0000000-0000-0000-0000-000000000006'), -- イベントグループ: 脱退して2人→1人にするメンバー
  ('a0000000-0000-0000-0000-000000000007'), -- イベントグループ: 残るメンバー
  ('a0000000-0000-0000-0000-000000000008'); -- 固定グループ: 作成直後1人のまま唯一のメンバー(脱退で0人になる)

insert into public.users (id, auth_provider, display_name)
values
  ('a0000000-0000-0000-0000-000000000001', 'email', 'SoloSince Member 1'),
  ('a0000000-0000-0000-0000-000000000002', 'email', 'SoloSince Member 2'),
  ('a0000000-0000-0000-0000-000000000003', 'email', 'SoloSince Member 3'),
  ('a0000000-0000-0000-0000-000000000004', 'email', 'SoloSince Member 4'),
  ('a0000000-0000-0000-0000-000000000005', 'email', 'SoloSince Member 5'),
  ('a0000000-0000-0000-0000-000000000006', 'email', 'SoloSince Event Member 1'),
  ('a0000000-0000-0000-0000-000000000007', 'email', 'SoloSince Event Member 2'),
  ('a0000000-0000-0000-0000-000000000008', 'email', 'SoloSince Alone Member');

-- Case 1: 固定グループが2人→1人になるケース
insert into public.groups (id, name, mode, created_by)
values ('b0000000-0000-0000-0000-000000000001', 'SoloSince Group 2to1', 'group', 'a0000000-0000-0000-0000-000000000002');

insert into public.group_members (group_id, user_id)
values
  ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001'),
  ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002');

set local role authenticated;
set local request.jwt.claims to '{"sub": "a0000000-0000-0000-0000-000000000001"}';
select public.leave_group('b0000000-0000-0000-0000-000000000001');
reset role;

select isnt(
  (select solo_since from public.groups where id = 'b0000000-0000-0000-0000-000000000001'),
  null,
  'fixed group: solo_since is set once active members drop from 2 to 1'
);

-- Case 2: 固定グループが3人→2人になるケース(猶予期間の対象外)
insert into public.groups (id, name, mode, created_by)
values ('b0000000-0000-0000-0000-000000000002', 'SoloSince Group 3to2', 'group', 'a0000000-0000-0000-0000-000000000004');

insert into public.group_members (group_id, user_id)
values
  ('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000003'),
  ('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000004'),
  ('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000005');

set local role authenticated;
set local request.jwt.claims to '{"sub": "a0000000-0000-0000-0000-000000000003"}';
select public.leave_group('b0000000-0000-0000-0000-000000000002');
reset role;

select is(
  (select solo_since from public.groups where id = 'b0000000-0000-0000-0000-000000000002'),
  null,
  'fixed group: solo_since stays null when active members drop from 3 to 2'
);

-- Case 3: イベントグループが2人→1人になっても対象外
insert into public.groups (id, name, mode, start_date, end_date, created_by)
values ('b0000000-0000-0000-0000-000000000003', 'SoloSince Event 2to1', 'event', current_date, current_date + 7, 'a0000000-0000-0000-0000-000000000006');

insert into public.group_members (group_id, user_id)
values
  ('b0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000006'),
  ('b0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000007');

set local role authenticated;
set local request.jwt.claims to '{"sub": "a0000000-0000-0000-0000-000000000006"}';
select public.leave_group('b0000000-0000-0000-0000-000000000003');
reset role;

select is(
  (select solo_since from public.groups where id = 'b0000000-0000-0000-0000-000000000003'),
  null,
  'event group: solo_since is never set even when active members drop from 2 to 1'
);

-- Case 4: 作成直後1人のまま唯一のメンバーが脱退(0人になるケース)。猶予期間ルールの対象外なのでsolo_sinceは設定されない
insert into public.groups (id, name, mode, created_by)
values ('b0000000-0000-0000-0000-000000000004', 'SoloSince Group Alone', 'group', 'a0000000-0000-0000-0000-000000000008');

insert into public.group_members (group_id, user_id)
values ('b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000008');

set local role authenticated;
set local request.jwt.claims to '{"sub": "a0000000-0000-0000-0000-000000000008"}';
select public.leave_group('b0000000-0000-0000-0000-000000000004');
reset role;

select is(
  (select solo_since from public.groups where id = 'b0000000-0000-0000-0000-000000000004'),
  null,
  'fixed group: solo_since stays null when the sole member leaves and active members drop to 0'
);

-- Case 5: solo_since設定後、現役メンバー数(status)自体は変わらずactiveのまま(archiveは別処理の責務)
select is(
  (select status from public.groups where id = 'b0000000-0000-0000-0000-000000000001'),
  'active',
  'fixed group: status remains active immediately after solo_since is set (archiving happens later via cron)'
);

select * from finish();
rollback;
