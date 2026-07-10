-- add_comment: 現像済み写真へのコメント追加RPCを検証する(issue #29 / 仕様書 3.7・5.1・6.6参照)。
begin;
select plan(12);

insert into auth.users (id) values
  ('c1000000-0000-0000-0000-000000000001'), -- 固定グループの現役メンバー
  ('c1000000-0000-0000-0000-000000000002'), -- 固定グループの非メンバー
  ('c1000000-0000-0000-0000-000000000003'); -- ソログループの所有者

insert into public.users (id, auth_provider, display_name)
values
  ('c1000000-0000-0000-0000-000000000001', 'email', 'Comment Member'),
  ('c1000000-0000-0000-0000-000000000002', 'email', 'Comment Non Member'),
  ('c1000000-0000-0000-0000-000000000003', 'email', 'Comment Solo Owner');

insert into public.groups (id, name, mode, created_by)
values ('c2000000-0000-0000-0000-000000000001', 'Comment Fixed Group', 'group', 'c1000000-0000-0000-0000-000000000001');

insert into public.group_members (group_id, user_id)
values ('c2000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001');

insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path, status)
values
  ('c3000000-0000-0000-0000-000000000001', 'c2000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001',
   now(), current_date, 'comment/developed_original.jpg', 'comment/developed_blurred.jpg', 'developed'),
  ('c3000000-0000-0000-0000-000000000002', 'c2000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001',
   now(), current_date, 'comment/pending_original.jpg', 'comment/pending_blurred.jpg', 'pending_vote');

insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path, status)
values (
  'c3000000-0000-0000-0000-000000000003',
  (select id from public.groups where mode = 'solo' and created_by = 'c1000000-0000-0000-0000-000000000003'),
  'c1000000-0000-0000-0000-000000000003',
  now(), current_date, 'comment/solo_original.jpg', 'comment/solo_blurred.jpg', 'developed'
);

-- =====================================================================
-- 1. 現役メンバーは現像済み写真にコメントできる
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "c1000000-0000-0000-0000-000000000001"}';

select lives_ok(
  $$ select public.add_comment('c3000000-0000-0000-0000-000000000001', 'いい写真!') $$,
  'an active member can comment on a developed photo'
);

-- =====================================================================
-- 2. 同じ人が複数件投稿できる(UPSERTされず連投可能)
-- =====================================================================
select lives_ok(
  $$ select public.add_comment('c3000000-0000-0000-0000-000000000001', '2件目のコメント') $$,
  'the same member can post a second comment'
);

select results_eq(
  $$ select count(*) from public.comments
     where photo_id = 'c3000000-0000-0000-0000-000000000001'
       and user_id = 'c1000000-0000-0000-0000-000000000001' $$,
  $$ values (2::bigint) $$,
  'multiple comments from the same user are kept, not overwritten'
);

-- コメント本文の前後の空白は保存前にtrimされる
select lives_ok(
  $$ select public.add_comment('c3000000-0000-0000-0000-000000000001', '  空白付き  ') $$,
  'add_comment accepts a body with surrounding whitespace'
);

select results_eq(
  $$ select body from public.comments
     where photo_id = 'c3000000-0000-0000-0000-000000000001'
       and body like '%空白付き%' $$,
  $$ values ('空白付き'::text) $$,
  'the stored body is trimmed of surrounding whitespace'
);

reset role;

-- =====================================================================
-- 3. 現像前の写真にはコメントできない
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "c1000000-0000-0000-0000-000000000001"}';

select throws_ok(
  $$ select public.add_comment('c3000000-0000-0000-0000-000000000002', 'コメント') $$,
  null,
  null,
  'add_comment rejects a photo that is not developed yet'
);

reset role;

-- =====================================================================
-- 4. ソロモードの写真にはコメントできない
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "c1000000-0000-0000-0000-000000000003"}';

select throws_ok(
  $$ select public.add_comment('c3000000-0000-0000-0000-000000000003', 'コメント') $$,
  null,
  null,
  'add_comment rejects a solo mode photo'
);

reset role;

-- =====================================================================
-- 5. 非メンバーはコメントできない
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "c1000000-0000-0000-0000-000000000002"}';

select throws_ok(
  $$ select public.add_comment('c3000000-0000-0000-0000-000000000001', 'コメント') $$,
  null,
  null,
  'add_comment rejects a non-member of the group'
);

reset role;

-- =====================================================================
-- 6. 存在しない写真・空のコメントは拒否される
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "c1000000-0000-0000-0000-000000000001"}';

select throws_ok(
  $$ select public.add_comment('99999999-0000-0000-0000-000000000000', 'コメント') $$,
  null,
  null,
  'add_comment rejects a non-existent photo'
);

select throws_ok(
  $$ select public.add_comment('c3000000-0000-0000-0000-000000000001', '   ') $$,
  null,
  null,
  'add_comment rejects a blank body'
);

-- =====================================================================
-- 7. commentsへの直接書き込みは禁止されている
-- =====================================================================
select throws_ok(
  $$ insert into public.comments (photo_id, user_id, body)
     values ('c3000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', '直接書き込み') $$,
  null,
  null,
  'direct INSERT into comments is rejected for authenticated role'
);

reset role;

-- =====================================================================
-- 8. anonロールは実行できない
-- =====================================================================
set local role anon;

select throws_ok(
  $$ select public.add_comment('c3000000-0000-0000-0000-000000000001', 'コメント') $$,
  null,
  null,
  'anon role cannot execute add_comment function'
);

reset role;

select * from finish();
rollback;
