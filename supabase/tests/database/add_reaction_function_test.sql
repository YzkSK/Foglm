-- add_reaction: 現像済み写真へのリアクション追加RPCを検証する(issue #29 / 仕様書 3.7・5.1・6.6参照)。
begin;
select plan(12);

insert into auth.users (id) values
  ('b1000000-0000-0000-0000-000000000001'), -- 固定グループの現役メンバー
  ('b1000000-0000-0000-0000-000000000002'), -- 固定グループの非メンバー
  ('b1000000-0000-0000-0000-000000000003'); -- ソログループの所有者

insert into public.users (id, auth_provider, display_name)
values
  ('b1000000-0000-0000-0000-000000000001', 'email', 'Reaction Member'),
  ('b1000000-0000-0000-0000-000000000002', 'email', 'Reaction Non Member'),
  ('b1000000-0000-0000-0000-000000000003', 'email', 'Reaction Solo Owner');

insert into public.groups (id, name, mode, created_by)
values ('b2000000-0000-0000-0000-000000000001', 'Reaction Fixed Group', 'group', 'b1000000-0000-0000-0000-000000000001');

insert into public.group_members (group_id, user_id)
values ('b2000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001');

insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path, status)
values
  ('b3000000-0000-0000-0000-000000000001', 'b2000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001',
   now(), current_date, 'reaction/developed_original.jpg', 'reaction/developed_blurred.jpg', 'developed'),
  ('b3000000-0000-0000-0000-000000000002', 'b2000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001',
   now(), current_date, 'reaction/pending_original.jpg', 'reaction/pending_blurred.jpg', 'pending_vote');

-- ソロモード写真(ensure_solo_spaceトリガーによりpublic.users挿入時にソログループが自動作成済み)
insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path, status)
values (
  'b3000000-0000-0000-0000-000000000003',
  (select id from public.groups where mode = 'solo' and created_by = 'b1000000-0000-0000-0000-000000000003'),
  'b1000000-0000-0000-0000-000000000003',
  now(), current_date, 'reaction/solo_original.jpg', 'reaction/solo_blurred.jpg', 'developed'
);

-- =====================================================================
-- 1. 現役メンバーは現像済み写真にリアクションできる
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "b1000000-0000-0000-0000-000000000001"}';

select lives_ok(
  $$ select public.add_reaction('b3000000-0000-0000-0000-000000000001', '❤️') $$,
  'an active member can react to a developed photo'
);

select results_eq(
  $$ select emoji from public.reactions
     where photo_id = 'b3000000-0000-0000-0000-000000000001'
       and user_id = 'b1000000-0000-0000-0000-000000000001' $$,
  $$ values ('❤️'::text) $$,
  'the reaction row stores the chosen emoji'
);

-- =====================================================================
-- 2. 再選択するとUPSERTで上書きされる(行数は増えない)
-- =====================================================================
select lives_ok(
  $$ select public.add_reaction('b3000000-0000-0000-0000-000000000001', '😂') $$,
  'the same member can change their reaction'
);

select results_eq(
  $$ select emoji from public.reactions
     where photo_id = 'b3000000-0000-0000-0000-000000000001'
       and user_id = 'b1000000-0000-0000-0000-000000000001' $$,
  $$ values ('😂'::text) $$,
  'the reaction is overwritten, not duplicated'
);

select results_eq(
  $$ select count(*) from public.reactions
     where photo_id = 'b3000000-0000-0000-0000-000000000001'
       and user_id = 'b1000000-0000-0000-0000-000000000001' $$,
  $$ values (1::bigint) $$,
  'only one reaction row exists per (photo, user)'
);

reset role;

-- =====================================================================
-- 3. 現像前の写真にはリアクションできない
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "b1000000-0000-0000-0000-000000000001"}';

select throws_ok(
  $$ select public.add_reaction('b3000000-0000-0000-0000-000000000002', '❤️') $$,
  null,
  null,
  'add_reaction rejects a photo that is not developed yet'
);

reset role;

-- =====================================================================
-- 4. ソロモードの写真にはリアクションできない
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "b1000000-0000-0000-0000-000000000003"}';

select throws_ok(
  $$ select public.add_reaction('b3000000-0000-0000-0000-000000000003', '❤️') $$,
  null,
  null,
  'add_reaction rejects a solo mode photo'
);

reset role;

-- =====================================================================
-- 5. 非メンバーはリアクションできない
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "b1000000-0000-0000-0000-000000000002"}';

select throws_ok(
  $$ select public.add_reaction('b3000000-0000-0000-0000-000000000001', '❤️') $$,
  null,
  null,
  'add_reaction rejects a non-member of the group'
);

-- =====================================================================
-- 6. 存在しない写真・空の絵文字は拒否される
-- =====================================================================
select throws_ok(
  $$ select public.add_reaction('99999999-0000-0000-0000-000000000000', '❤️') $$,
  null,
  null,
  'add_reaction rejects a non-existent photo'
);

reset role;

set local role authenticated;
set local request.jwt.claims to '{"sub": "b1000000-0000-0000-0000-000000000001"}';

select throws_ok(
  $$ select public.add_reaction('b3000000-0000-0000-0000-000000000001', '') $$,
  null,
  null,
  'add_reaction rejects an empty emoji'
);

-- =====================================================================
-- 7. reactionsへの直接書き込みは禁止されている
-- =====================================================================
select throws_ok(
  $$ insert into public.reactions (photo_id, user_id, emoji)
     values ('b3000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', '👍') $$,
  null,
  null,
  'direct INSERT into reactions is rejected for authenticated role'
);

reset role;

-- =====================================================================
-- 8. anonロールは実行できない
-- =====================================================================
set local role anon;

select throws_ok(
  $$ select public.add_reaction('b3000000-0000-0000-0000-000000000001', '❤️') $$,
  null,
  null,
  'anon role cannot execute add_reaction function'
);

reset role;

select * from finish();
rollback;
