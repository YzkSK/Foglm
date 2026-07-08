-- dissolve_group: 固定グループ(mode=group)限定・作成者のみ実行可能な解散RPCを検証する
-- (issue #16 / 仕様書 3.2.1・6.2参照)。
begin;
select plan(10);

insert into auth.users (id) values
  ('c0000000-0000-0000-0000-000000000001'), -- 固定グループ: 作成者(解散を実行する)
  ('c0000000-0000-0000-0000-000000000002'), -- 固定グループ: 他の現役メンバー
  ('c0000000-0000-0000-0000-000000000003'), -- 固定グループ: 作成者ではないメンバー(解散を試みて拒否される)
  ('c0000000-0000-0000-0000-000000000004'), -- イベントグループ: 作成者(解散不可であることを確認)
  ('c0000000-0000-0000-0000-000000000005'); -- ソロモード: 作成者(解散不可であることを確認)

insert into public.users (id, auth_provider, display_name)
values
  ('c0000000-0000-0000-0000-000000000001', 'email', 'Dissolve Creator'),
  ('c0000000-0000-0000-0000-000000000002', 'email', 'Dissolve Member'),
  ('c0000000-0000-0000-0000-000000000003', 'email', 'Dissolve Non Creator'),
  ('c0000000-0000-0000-0000-000000000004', 'email', 'Dissolve Event Creator'),
  ('c0000000-0000-0000-0000-000000000005', 'email', 'Dissolve Solo Owner');

insert into public.groups (id, name, mode, created_by)
values
  ('d0000000-0000-0000-0000-000000000001', 'Dissolve Group', 'group', 'c0000000-0000-0000-0000-000000000001'),
  ('d0000000-0000-0000-0000-000000000003', 'Dissolve Solo', 'solo', 'c0000000-0000-0000-0000-000000000005');

insert into public.groups (id, name, mode, created_by, start_date, end_date)
values
  ('d0000000-0000-0000-0000-000000000002', 'Dissolve Event', 'event', 'c0000000-0000-0000-0000-000000000004', current_date, current_date + 7);

insert into public.group_members (group_id, user_id)
values
  ('d0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001'),
  ('d0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002'),
  ('d0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000003'),
  ('d0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000004'),
  ('d0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000005');

insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
values
  ('e0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002',
   now(), current_date, 'dissolve_group/original.jpg', 'dissolve_group/blurred.jpg');

insert into storage.objects (bucket_id, name)
values
  ('photo-originals', 'dissolve_group/original.jpg'),
  ('photo-blurred', 'dissolve_group/blurred.jpg');

insert into public.daily_votes (id, group_id, vote_date)
values ('f0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', current_date);

insert into public.vote_entries (daily_vote_id, user_id, photo_id)
values ('f0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000001');

insert into public.reactions (photo_id, user_id, emoji)
values ('e0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', '😊');

insert into public.comments (photo_id, user_id, body)
values ('e0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', 'いい写真!');

insert into public.invite_codes (group_id, code, created_by)
values ('d0000000-0000-0000-0000-000000000001', 'DISSOLVETEST', 'c0000000-0000-0000-0000-000000000001');

-- =====================================================================
-- 1. 作成者でないメンバーは解散できない
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "c0000000-0000-0000-0000-000000000003"}';

select throws_ok(
  $$ select public.dissolve_group('d0000000-0000-0000-0000-000000000001') $$,
  null,
  null,
  'a non-creator member cannot dissolve the group'
);

reset role;

-- =====================================================================
-- 2. イベントグループ・ソロモードは解散できない
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "c0000000-0000-0000-0000-000000000004"}';

select throws_ok(
  $$ select public.dissolve_group('d0000000-0000-0000-0000-000000000002') $$,
  null,
  null,
  'an event group cannot be dissolved'
);

reset role;

set local role authenticated;
set local request.jwt.claims to '{"sub": "c0000000-0000-0000-0000-000000000005"}';

select throws_ok(
  $$ select public.dissolve_group('d0000000-0000-0000-0000-000000000003') $$,
  null,
  null,
  'a solo group cannot be dissolved'
);

reset role;

-- =====================================================================
-- 3. 存在しないグループ・NULLは拒否される
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "c0000000-0000-0000-0000-000000000001"}';

select throws_ok(
  $$ select public.dissolve_group('99999999-0000-0000-0000-000000000000') $$,
  null,
  null,
  'dissolve_group rejects a non-existent group'
);

select throws_ok(
  $$ select public.dissolve_group(null) $$,
  null,
  null,
  'dissolve_group rejects a null group_id'
);

reset role;

-- =====================================================================
-- 4. anonロールは実行できない
-- =====================================================================
set local role anon;

select throws_ok(
  $$ select public.dissolve_group('d0000000-0000-0000-0000-000000000001') $$,
  null,
  null,
  'anon role cannot execute dissolve_group function'
);

reset role;

-- =====================================================================
-- 5. 作成者は解散でき、紐づく全データが完全削除される
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "c0000000-0000-0000-0000-000000000001"}';

select lives_ok(
  $$ select public.dissolve_group('d0000000-0000-0000-0000-000000000001') $$,
  'the creator can dissolve the fixed group'
);

reset role;

select is_empty(
  $$ select 1 from public.groups where id = 'd0000000-0000-0000-0000-000000000001' $$,
  'dissolve_group deletes the group itself'
);

select is_empty(
  $$ select 1 from public.photos where group_id = 'd0000000-0000-0000-0000-000000000001'
     union all
     select 1 from public.daily_votes where group_id = 'd0000000-0000-0000-0000-000000000001'
     union all
     select 1 from public.vote_entries where daily_vote_id = 'f0000000-0000-0000-0000-000000000001'
     union all
     select 1 from public.reactions where photo_id = 'e0000000-0000-0000-0000-000000000001'
     union all
     select 1 from public.comments where photo_id = 'e0000000-0000-0000-0000-000000000001'
     union all
     select 1 from public.group_members where group_id = 'd0000000-0000-0000-0000-000000000001'
     union all
     select 1 from public.invite_codes where group_id = 'd0000000-0000-0000-0000-000000000001' $$,
  'dissolve_group cascades and deletes all photos/votes/reactions/comments/members/invite codes'
);

select is_empty(
  $$ select 1 from storage.objects
     where (bucket_id = 'photo-originals' and name = 'dissolve_group/original.jpg')
        or (bucket_id = 'photo-blurred' and name = 'dissolve_group/blurred.jpg') $$,
  'dissolve_group deletes the original and blurred storage objects'
);

select * from finish();
rollback;
