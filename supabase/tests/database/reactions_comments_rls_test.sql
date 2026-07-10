-- reactions/comments: 閲覧はグループの現役メンバーのみ許可されることを検証する。
-- 書き込み(追加・変更・削除)はadd_reaction/add_comment関数(security definer)経由に限定されており、
-- 直接のINSERT/UPDATE/DELETEはロールへのgrant自体が存在しないため拒否される
-- (直接書き込みの認可境界はadd_reaction_function_test.sql/add_comment_function_test.sqlで検証する)。
begin;
select plan(4);

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

-- postgres(RLSバイパス)でリアクション・コメントを用意しておく
insert into public.reactions (photo_id, user_id, emoji)
values ('20000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000051', '😊');

insert into public.comments (photo_id, user_id, body)
values ('20000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000051', 'いい写真!');

-- 現役メンバーAはリアクション・コメントを閲覧できる
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000051"}';

select isnt_empty(
  $$ select 1 from public.reactions where photo_id = '20000000-0000-0000-0000-000000000003' $$,
  'member A can see reactions on a photo of their own group'
);

select isnt_empty(
  $$ select 1 from public.comments where photo_id = '20000000-0000-0000-0000-000000000003' $$,
  'member A can see comments on a photo of their own group'
);

reset role;

-- グループ外のCはリアクション・コメントを見えない・直接書き込めない
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
  'outsider C cannot insert a comment directly (write access is limited to add_comment)'
);

reset role;

select * from finish();
rollback;
