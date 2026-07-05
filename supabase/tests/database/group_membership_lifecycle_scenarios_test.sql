begin;
select plan(14);

-- =====================================================================
-- Scenario 1: 脱退済みメンバーは脱退前に見えていた写真・コメント・リアクションも
-- 即座に閲覧不可になることを、複数テーブルを横断して検証する。
-- Fixtures: users prefix 40000000-..., group prefix 70000000-...
-- =====================================================================

insert into auth.users (id) values
  ('40000000-0000-0000-0000-000000000001'), -- A: 脱退するメンバー
  ('40000000-0000-0000-0000-000000000002'); -- B: 写真を撮る現役メンバー

insert into public.users (id, auth_provider, display_name)
values
  ('40000000-0000-0000-0000-000000000001', 'email', 'Scenario1 Member A'),
  ('40000000-0000-0000-0000-000000000002', 'email', 'Scenario1 Member B');

insert into public.groups (id, name, mode, created_by)
values
  ('70000000-0000-0000-0000-000000000001', 'Scenario1 Group', 'group', '40000000-0000-0000-0000-000000000002');

insert into public.group_members (group_id, user_id, left_at)
values
  ('70000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', null),
  ('70000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000002', null);

insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
values
  ('70000000-0000-0000-0000-000000000101', '70000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000002',
   now(), current_date, 'scenario1/original.jpg', 'scenario1/blurred.jpg');

insert into public.comments (id, photo_id, user_id, body)
values
  ('70000000-0000-0000-0000-000000000201', '70000000-0000-0000-0000-000000000101', '40000000-0000-0000-0000-000000000002', 'Scenario1 comment by B');

insert into public.reactions (id, photo_id, user_id, emoji)
values
  ('70000000-0000-0000-0000-000000000301', '70000000-0000-0000-0000-000000000101', '40000000-0000-0000-0000-000000000002', '😊');

-- 1. Aは現役メンバーなので写真・コメント・リアクションを閲覧できる
set local role authenticated;
set local request.jwt.claims to '{"sub": "40000000-0000-0000-0000-000000000001"}';

select isnt_empty(
  $$ select 1 from public.photos where id = '70000000-0000-0000-0000-000000000101' $$,
  'scenario1: active member A can see the photo before leaving'
);

select isnt_empty(
  $$ select 1 from public.comments where id = '70000000-0000-0000-0000-000000000201' $$,
  'scenario1: active member A can see the comment before leaving'
);

select isnt_empty(
  $$ select 1 from public.reactions where id = '70000000-0000-0000-0000-000000000301' $$,
  'scenario1: active member A can see the reaction before leaving'
);

reset role;

-- 2. postgres(RLSバイパス)でAを脱退させる
update public.group_members set left_at = now()
where group_id = '70000000-0000-0000-0000-000000000001' and user_id = '40000000-0000-0000-0000-000000000001';

-- 3. 脱退済みAは写真・コメント・リアクションを即座に閲覧不可になる
set local role authenticated;
set local request.jwt.claims to '{"sub": "40000000-0000-0000-0000-000000000001"}';

select is_empty(
  $$ select 1 from public.photos where id = '70000000-0000-0000-0000-000000000101' $$,
  'scenario1: left member A can no longer see the photo'
);

select is_empty(
  $$ select 1 from public.comments where id = '70000000-0000-0000-0000-000000000201' $$,
  'scenario1: left member A can no longer see the comment'
);

select is_empty(
  $$ select 1 from public.reactions where id = '70000000-0000-0000-0000-000000000301' $$,
  'scenario1: left member A can no longer see the reaction'
);

reset role;

-- =====================================================================
-- Scenario 2: 招待によって新規参加したメンバーは、参加前から存在していた
-- グループのコンテンツ(写真・コメント・リアクション)を即座に閲覧できる。
-- Fixtures: users prefix 50000000-..., group prefix 80000000-...
-- =====================================================================

insert into auth.users (id) values
  ('50000000-0000-0000-0000-000000000001'), -- A: 既存の現役メンバー
  ('50000000-0000-0000-0000-000000000002'); -- C: これから招待される新規メンバー

insert into public.users (id, auth_provider, display_name)
values
  ('50000000-0000-0000-0000-000000000001', 'email', 'Scenario2 Member A'),
  ('50000000-0000-0000-0000-000000000002', 'email', 'Scenario2 Invitee C');

insert into public.groups (id, name, mode, created_by)
values
  ('80000000-0000-0000-0000-000000000001', 'Scenario2 Group', 'group', '50000000-0000-0000-0000-000000000001');

insert into public.group_members (group_id, user_id, left_at)
values
  ('80000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', null);

insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
values
  ('80000000-0000-0000-0000-000000000101', '80000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001',
   now(), current_date, 'scenario2/original.jpg', 'scenario2/blurred.jpg');

insert into public.comments (id, photo_id, user_id, body)
values
  ('80000000-0000-0000-0000-000000000201', '80000000-0000-0000-0000-000000000101', '50000000-0000-0000-0000-000000000001', 'Scenario2 comment by A');

insert into public.reactions (id, photo_id, user_id, emoji)
values
  ('80000000-0000-0000-0000-000000000301', '80000000-0000-0000-0000-000000000101', '50000000-0000-0000-0000-000000000001', '📸');

-- 1. まだメンバーでないCは写真を閲覧できない
set local role authenticated;
set local request.jwt.claims to '{"sub": "50000000-0000-0000-0000-000000000002"}';

select is_empty(
  $$ select 1 from public.photos where id = '80000000-0000-0000-0000-000000000101' $$,
  'scenario2: non-member C cannot see the photo before being invited'
);

reset role;

-- 2. 現役メンバーAがCをグループに招待する
set local role authenticated;
set local request.jwt.claims to '{"sub": "50000000-0000-0000-0000-000000000001"}';

select lives_ok(
  $$ insert into public.group_members (group_id, user_id)
     values ('80000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000002') $$,
  'scenario2: active member A can invite user C into the group'
);

reset role;

-- 3. 新規参加したCは、参加前から存在していた写真・コメント・リアクションを即座に閲覧できる
set local role authenticated;
set local request.jwt.claims to '{"sub": "50000000-0000-0000-0000-000000000002"}';

select isnt_empty(
  $$ select 1 from public.photos where id = '80000000-0000-0000-0000-000000000101' $$,
  'scenario2: newly joined member C can immediately see the pre-existing photo'
);

select isnt_empty(
  $$ select 1 from public.comments where id = '80000000-0000-0000-0000-000000000201' $$,
  'scenario2: newly joined member C can immediately see the pre-existing comment'
);

select isnt_empty(
  $$ select 1 from public.reactions where id = '80000000-0000-0000-0000-000000000301' $$,
  'scenario2: newly joined member C can immediately see the pre-existing reaction'
);

reset role;

-- =====================================================================
-- Scenario 3: 脱退後に再参加(left_atのリセット)すると、閲覧権限が復活する。
-- Fixtures: users prefix 60000000-..., group prefix 90000000-...
-- =====================================================================

insert into auth.users (id) values
  ('60000000-0000-0000-0000-000000000001'); -- A: 脱退・再参加するメンバー

insert into public.users (id, auth_provider, display_name)
values
  ('60000000-0000-0000-0000-000000000001', 'email', 'Scenario3 Member A');

insert into public.groups (id, name, mode, created_by)
values
  ('90000000-0000-0000-0000-000000000001', 'Scenario3 Group', 'group', '60000000-0000-0000-0000-000000000001');

insert into public.group_members (group_id, user_id, left_at)
values
  ('90000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', null);

insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
values
  ('90000000-0000-0000-0000-000000000101', '90000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001',
   now(), current_date, 'scenario3/original.jpg', 'scenario3/blurred.jpg');

-- 1. 現役メンバーAは写真を閲覧できる(サニティチェック)
set local role authenticated;
set local request.jwt.claims to '{"sub": "60000000-0000-0000-0000-000000000001"}';

select isnt_empty(
  $$ select 1 from public.photos where id = '90000000-0000-0000-0000-000000000101' $$,
  'scenario3: active member A can see the photo before leaving'
);

reset role;

-- 2. postgresでAを脱退させる
update public.group_members set left_at = now()
where group_id = '90000000-0000-0000-0000-000000000001' and user_id = '60000000-0000-0000-0000-000000000001';

-- 3. 脱退済みAは写真を閲覧できない
set local role authenticated;
set local request.jwt.claims to '{"sub": "60000000-0000-0000-0000-000000000001"}';

select is_empty(
  $$ select 1 from public.photos where id = '90000000-0000-0000-0000-000000000101' $$,
  'scenario3: left member A can no longer see the photo'
);

reset role;

-- 4. postgresでAを再参加させる(left_atをリセット)
update public.group_members set left_at = null
where group_id = '90000000-0000-0000-0000-000000000001' and user_id = '60000000-0000-0000-0000-000000000001';

-- 5. 再参加したAは写真を再び閲覧できる
set local role authenticated;
set local request.jwt.claims to '{"sub": "60000000-0000-0000-0000-000000000001"}';

select isnt_empty(
  $$ select 1 from public.photos where id = '90000000-0000-0000-0000-000000000101' $$,
  'scenario3: rejoined member A can see the photo again'
);

reset role;

select * from finish();
rollback;
