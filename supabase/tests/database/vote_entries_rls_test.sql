-- vote_entries: 閲覧はグループの現役メンバーのみ許可されることを検証する。
-- 書き込み(登録・更新)はcast_vote関数(security definer)経由に限定されており、
-- 直接のINSERT/UPDATEはロールへのgrant自体が存在しないため拒否される
-- (直接書き込みの認可境界はcast_vote_function_test.sqlで検証する)。
begin;
select plan(4);

-- Fixtures: group(A所属), C(グループ外)。photo・daily_voteはgroup内。
insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000041'),
  ('00000000-0000-0000-0000-000000000042');

insert into public.users (id, auth_provider, display_name)
values
  ('00000000-0000-0000-0000-000000000041', 'email', 'Member A'),
  ('00000000-0000-0000-0000-000000000042', 'email', 'Outsider C');

insert into public.groups (id, name, mode, created_by)
values ('10000000-0000-0000-0000-000000000007', 'Vote Entries Test Group', 'group', '00000000-0000-0000-0000-000000000041');

insert into public.group_members (group_id, user_id)
values ('10000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000041');

insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
values (
  '20000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000007',
  '00000000-0000-0000-0000-000000000041',
  now(), current_date, 'original/path.jpg', 'blurred/path.jpg'
);

insert into public.daily_votes (id, group_id, vote_date)
values ('30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000007', current_date);

-- postgres(RLSバイパス)で投票を用意しておく
insert into public.vote_entries (daily_vote_id, user_id, photo_id)
values ('30000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000041', '20000000-0000-0000-0000-000000000002');

-- 現役メンバーAは自分の投票を閲覧できるが、直接INSERT/UPDATEはできない
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000041"}';

select isnt_empty(
  $$ select 1 from public.vote_entries where daily_vote_id = '30000000-0000-0000-0000-000000000002' and user_id = '00000000-0000-0000-0000-000000000041' $$,
  'member A can see own vote_entry'
);

select throws_ok(
  $$ update public.vote_entries set photo_id = '20000000-0000-0000-0000-000000000002'
     where daily_vote_id = '30000000-0000-0000-0000-000000000002' and user_id = '00000000-0000-0000-0000-000000000041' $$,
  null,
  null,
  'member A cannot update vote_entry directly (write access is limited to cast_vote)'
);

reset role;

-- グループ外のCは投票が見えない・直接書き込めない
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000042"}';

select is_empty(
  $$ select 1 from public.vote_entries where daily_vote_id = '30000000-0000-0000-0000-000000000002' $$,
  'outsider C cannot see vote_entries of a group they do not belong to'
);

select throws_ok(
  $$ insert into public.vote_entries (daily_vote_id, user_id, photo_id)
     values ('30000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000042', '20000000-0000-0000-0000-000000000002') $$,
  null,
  null,
  'outsider C cannot insert a vote_entry directly (write access is limited to cast_vote)'
);

reset role;

select * from finish();
rollback;
