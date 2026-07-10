-- cast_vote: 「今日の1枚」投票の登録・更新RPCを検証する(issue #24 / 仕様書 3.5・5.1・6.4参照)。
begin;
select plan(10);

insert into auth.users (id) values
  ('c1000000-0000-0000-0000-000000000001'), -- 固定グループの現役メンバー
  ('c1000000-0000-0000-0000-000000000002'); -- 固定グループの非メンバー

insert into public.users (id, auth_provider, display_name)
values
  ('c1000000-0000-0000-0000-000000000001', 'email', 'Vote Member'),
  ('c1000000-0000-0000-0000-000000000002', 'email', 'Vote Non Member');

insert into public.groups (id, name, mode, created_by)
values ('c2000000-0000-0000-0000-000000000001', 'Cast Vote Test Group', 'group', 'c1000000-0000-0000-0000-000000000001');

insert into public.group_members (group_id, user_id)
values ('c2000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001');

insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path, status)
values
  ('c3000000-0000-0000-0000-000000000001', 'c2000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001',
   now(), current_date, 'vote/photo1_original.jpg', 'vote/photo1_blurred.jpg', 'pending_vote'),
  ('c3000000-0000-0000-0000-000000000002', 'c2000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001',
   now(), current_date, 'vote/photo2_original.jpg', 'vote/photo2_blurred.jpg', 'pending_vote');

insert into public.daily_votes (id, group_id, vote_date, status)
values ('c4000000-0000-0000-0000-000000000001', 'c2000000-0000-0000-0000-000000000001', current_date, 'open');

-- 締切済みのdaily_votesを持つ別グループ・別写真
insert into public.groups (id, name, mode, created_by)
values ('c2000000-0000-0000-0000-000000000002', 'Cast Vote Closed Group', 'group', 'c1000000-0000-0000-0000-000000000001');

insert into public.group_members (group_id, user_id)
values ('c2000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000001');

insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path, status)
values (
  'c3000000-0000-0000-0000-000000000003', 'c2000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000001',
  now(), current_date, 'vote/photo3_original.jpg', 'vote/photo3_blurred.jpg', 'pending_vote'
);

insert into public.daily_votes (id, group_id, vote_date, status)
values ('c4000000-0000-0000-0000-000000000002', 'c2000000-0000-0000-0000-000000000002', current_date, 'closed');

-- 撮影0枚(daily_votesが存在しない)グループ
insert into public.groups (id, name, mode, created_by)
values ('c2000000-0000-0000-0000-000000000003', 'Cast Vote No Vote Group', 'group', 'c1000000-0000-0000-0000-000000000001');

insert into public.group_members (group_id, user_id)
values ('c2000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000001');

insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path, status)
values (
  'c3000000-0000-0000-0000-000000000004', 'c2000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000001',
  now(), current_date, 'vote/photo4_original.jpg', 'vote/photo4_blurred.jpg', 'pending_vote'
);

-- =====================================================================
-- 1. 現役メンバーは投票できる
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "c1000000-0000-0000-0000-000000000001"}';

select lives_ok(
  $$ select public.cast_vote('c3000000-0000-0000-0000-000000000001') $$,
  'an active member can cast a vote'
);

select results_eq(
  $$ select photo_id from public.vote_entries
     where daily_vote_id = 'c4000000-0000-0000-0000-000000000001'
       and user_id = 'c1000000-0000-0000-0000-000000000001' $$,
  $$ values ('c3000000-0000-0000-0000-000000000001'::uuid) $$,
  'the vote entry stores the chosen photo'
);

-- =====================================================================
-- 2. 再投票するとUPSERTで上書きされる(行数は増えない)
-- =====================================================================
select lives_ok(
  $$ select public.cast_vote('c3000000-0000-0000-0000-000000000002') $$,
  'the same member can change their vote'
);

select results_eq(
  $$ select photo_id from public.vote_entries
     where daily_vote_id = 'c4000000-0000-0000-0000-000000000001'
       and user_id = 'c1000000-0000-0000-0000-000000000001' $$,
  $$ values ('c3000000-0000-0000-0000-000000000002'::uuid) $$,
  'the vote is overwritten, not duplicated'
);

select results_eq(
  $$ select count(*) from public.vote_entries
     where daily_vote_id = 'c4000000-0000-0000-0000-000000000001'
       and user_id = 'c1000000-0000-0000-0000-000000000001' $$,
  $$ values (1::bigint) $$,
  'only one vote entry row exists per (daily_vote, user)'
);

reset role;

-- =====================================================================
-- 3. 締切後(closed)の投票は拒否される
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "c1000000-0000-0000-0000-000000000001"}';

select throws_ok(
  $$ select public.cast_vote('c3000000-0000-0000-0000-000000000003') $$,
  null,
  null,
  'cast_vote rejects voting after the daily_vote has closed'
);

-- =====================================================================
-- 4. daily_votesが存在しない(撮影0枚扱い)場合は拒否される
-- =====================================================================
select throws_ok(
  $$ select public.cast_vote('c3000000-0000-0000-0000-000000000004') $$,
  null,
  null,
  'cast_vote rejects a photo with no open daily_vote'
);

-- =====================================================================
-- 5. 存在しない写真は拒否される
-- =====================================================================
select throws_ok(
  $$ select public.cast_vote('99999999-0000-0000-0000-000000000000') $$,
  null,
  null,
  'cast_vote rejects a non-existent photo'
);

reset role;

-- =====================================================================
-- 6. 非メンバーは投票できない
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "c1000000-0000-0000-0000-000000000002"}';

select throws_ok(
  $$ select public.cast_vote('c3000000-0000-0000-0000-000000000001') $$,
  null,
  null,
  'cast_vote rejects a non-member of the group'
);

reset role;

-- =====================================================================
-- 7. anonロールは実行できない
-- =====================================================================
set local role anon;

select throws_ok(
  $$ select public.cast_vote('c3000000-0000-0000-0000-000000000001') $$,
  null,
  null,
  'anon role cannot execute cast_vote function'
);

reset role;

select * from finish();
rollback;
