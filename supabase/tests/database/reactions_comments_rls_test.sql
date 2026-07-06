begin;
select plan(9);

-- Fixtures: group(A所属), C(グループ外)。photoはgroup内で現像済み想定。
insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000051'),
  ('00000000-0000-0000-0000-000000000052');

insert into public.users (id, auth_provider, display_name)
values
  ('00000000-0000-0000-0000-000000000051', 'email', 'Member A'),
  ('00000000-0000-0000-0000-000000000052', 'email', 'Outsider C');

insert into public.groups (id, name, mode, created_by)
values ('10000000-0000-0000-0000-000000000008', 'Reactions Comments Test Group', 'group', '00000000-0000-0000-0000-000000000051');

insert into public.group_members (group_id, user_id)
values ('10000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000051');

insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path, status)
values (
  '20000000-0000-0000-0000-000000000003',
  '10000000-0000-0000-0000-000000000008',
  '00000000-0000-0000-0000-000000000051',
  now(), current_date, 'original/path.jpg', 'blurred/path.jpg', 'developed'
);

-- 現役メンバーAはリアクション・コメントを追加・変更できる
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000051"}';

select lives_ok(
  $$ insert into public.reactions (photo_id, user_id, emoji)
     values ('20000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000051', '😊') $$,
  'member A can insert own reaction'
);

select lives_ok(
  $$ update public.reactions set emoji = '😢'
     where photo_id = '20000000-0000-0000-0000-000000000003' and user_id = '00000000-0000-0000-0000-000000000051' $$,
  'member A can update own reaction'
);

select lives_ok(
  $$ insert into public.comments (photo_id, user_id, body)
     values ('20000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000051', 'いい写真！') $$,
  'member A can insert own comment'
);

select lives_ok(
  $$ delete from public.reactions
     where photo_id = '20000000-0000-0000-0000-000000000003' and user_id = '00000000-0000-0000-0000-000000000051' $$,
  'member A can delete own reaction'
);

reset role;

-- グループ外のCはリアクション・コメントを見えない・追加できない
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000052"}';

select is_empty(
  $$ select 1 from public.comments where photo_id = '20000000-0000-0000-0000-000000000003' $$,
  'outsider C cannot see comments on a photo of a group they do not belong to'
);

select throws_ok(
  $$ insert into public.comments (photo_id, user_id, body)
     values ('20000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000052', 'すごい') $$,
  null,
  null,
  'outsider C cannot insert a comment on a photo of a group they do not belong to'
);

reset role;

-- Second group that A is NOT a member of (security check for WITH CHECK on UPDATE)
insert into public.groups (id, name, mode, created_by)
values ('10000000-0000-0000-0000-000000000009', 'Reactions Comments Test Group 2', 'group', '00000000-0000-0000-0000-000000000052');

insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path, status)
values (
  '20000000-0000-0000-0000-000000000004',
  '10000000-0000-0000-0000-000000000009',
  '00000000-0000-0000-0000-000000000052',
  now(), current_date, 'original/path2.jpg', 'blurred/path2.jpg', 'developed'
);

-- Re-insert a reaction for member A to test cross-group update
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000051"}';

select lives_ok(
  $$ insert into public.reactions (photo_id, user_id, emoji)
     values ('20000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000051', '😊') $$,
  'member A can re-insert own reaction for cross-group update test'
);

-- Member A cannot update their reaction to point to a different group's photo (WITH CHECK violation)
select throws_ok(
  $$ update public.reactions set photo_id = '20000000-0000-0000-0000-000000000004'
     where photo_id = '20000000-0000-0000-0000-000000000003' and user_id = '00000000-0000-0000-0000-000000000051' $$,
  null,
  null,
  'member A cannot update reaction to point to a different group photo (WITH CHECK violation)'
);

reset role;

select isnt_empty(
  $$ select 1 from public.reactions where photo_id = '20000000-0000-0000-0000-000000000003' and user_id = '00000000-0000-0000-0000-000000000051' $$,
  'reaction still points to original group photo after unauthorized cross-group update attempt'
);

select * from finish();
rollback;
