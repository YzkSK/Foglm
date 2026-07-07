begin;
select plan(11);

-- =====================================================================
-- Fixtures
-- =====================================================================
insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000041'), -- creator / active member
  ('00000000-0000-0000-0000-000000000042'), -- new invitee
  ('00000000-0000-0000-0000-000000000043'); -- previously left member

insert into public.users (id, auth_provider, display_name)
values
  ('00000000-0000-0000-0000-000000000041', 'email', 'Invite Member Creator'),
  ('00000000-0000-0000-0000-000000000042', 'email', 'Invite Member New Invitee'),
  ('00000000-0000-0000-0000-000000000043', 'email', 'Invite Member Rejoiner');

insert into public.groups (id, name, mode, created_by)
values
  ('30000000-0000-0000-0000-000000000001', 'Invite Member Group', 'group', '00000000-0000-0000-0000-000000000041'),
  ('30000000-0000-0000-0000-000000000002', 'Invite Member Archived Group', 'group', '00000000-0000-0000-0000-000000000041');

update public.groups set status = 'archived'
where id = '30000000-0000-0000-0000-000000000002';

insert into public.group_members (group_id, user_id, left_at)
values
  ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000041', null),
  ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000043', now() - interval '1 day');

insert into public.invite_codes (group_id, code, created_by)
values
  ('30000000-0000-0000-0000-000000000001', 'VALIDCODE', '00000000-0000-0000-0000-000000000041'),
  ('30000000-0000-0000-0000-000000000002', 'ARCHIVEDCODE', '00000000-0000-0000-0000-000000000041');

-- =====================================================================
-- 1. 新規ユーザーが有効な招待コードで参加できる
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000042"}';

select lives_ok(
  $$ select public.invite_member('VALIDCODE') $$,
  'a valid invite code lets a new user join the group'
);

select isnt_empty(
  $$ select 1 from public.group_members
     where group_id = '30000000-0000-0000-0000-000000000001'
       and user_id = '00000000-0000-0000-0000-000000000042'
       and left_at is null $$,
  'invite_member registers the invitee as an active member'
);

reset role;

-- =====================================================================
-- 2. 過去に脱退したメンバーが再参加すると left_at がNULLに戻る(UPSERT)
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000043"}';

select lives_ok(
  $$ select public.invite_member('VALIDCODE') $$,
  'a previously-left member can rejoin via invite code'
);

select isnt_empty(
  $$ select 1 from public.group_members
     where group_id = '30000000-0000-0000-0000-000000000001'
       and user_id = '00000000-0000-0000-0000-000000000043'
       and left_at is null $$,
  'rejoining resets left_at to NULL instead of inserting a duplicate row'
);

select results_eq(
  $$ select count(*)::int from public.group_members
     where group_id = '30000000-0000-0000-0000-000000000001'
       and user_id = '00000000-0000-0000-0000-000000000043' $$,
  $$ values (1) $$,
  'rejoining does not create a second group_members row'
);

-- 3. 既に現役メンバーの場合はエラーにならず冪等(idempotent)
select lives_ok(
  $$ select public.invite_member('VALIDCODE') $$,
  'invite_member is idempotent for an already-active member'
);

reset role;

-- =====================================================================
-- 4. 存在しない招待コードは拒否される
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000042"}';

select throws_ok(
  $$ select public.invite_member('NOSUCHCODE') $$,
  null,
  null,
  'invite_member rejects an unknown invite code'
);

select throws_ok(
  $$ select public.invite_member('') $$,
  null,
  null,
  'invite_member rejects an empty code'
);

select throws_ok(
  $$ select public.invite_member(null) $$,
  null,
  null,
  'invite_member rejects a null code'
);

-- =====================================================================
-- 5. アーカイブ済みグループへの招待は拒否される
-- =====================================================================
select throws_ok(
  $$ select public.invite_member('ARCHIVEDCODE') $$,
  null,
  null,
  'invite_member rejects joining an archived group'
);

reset role;

-- =====================================================================
-- 6. anonロールは実行できない
-- =====================================================================
set local role anon;

select throws_ok(
  $$ select public.invite_member('VALIDCODE') $$,
  null,
  null,
  'anon role cannot execute invite_member function'
);

reset role;

select * from finish();
rollback;
