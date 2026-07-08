begin;
select plan(12);

-- =====================================================================
-- Fixtures
-- =====================================================================
insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000051'), -- creator / active member
  ('00000000-0000-0000-0000-000000000052'), -- new joiner (not a fixed-group member)
  ('00000000-0000-0000-0000-000000000053'); -- previously left member

insert into public.users (id, auth_provider, display_name)
values
  ('00000000-0000-0000-0000-000000000051', 'email', 'Join Event Group Creator'),
  ('00000000-0000-0000-0000-000000000052', 'email', 'Join Event Group New Joiner'),
  ('00000000-0000-0000-0000-000000000053', 'email', 'Join Event Group Rejoiner');

insert into public.groups (id, name, mode, start_date, end_date, created_by)
values
  ('40000000-0000-0000-0000-000000000001', 'Join Event Group', 'event', '2026-08-01', '2026-08-03', '00000000-0000-0000-0000-000000000051'),
  ('40000000-0000-0000-0000-000000000002', 'Join Event Group Archived', 'event', '2026-01-01', '2026-01-03', '00000000-0000-0000-0000-000000000051');

update public.groups set status = 'archived'
where id = '40000000-0000-0000-0000-000000000002';

insert into public.group_members (group_id, user_id, left_at)
values
  ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000051', null),
  ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000053', now() - interval '1 day');

insert into public.groups (id, name, mode, created_by)
values ('40000000-0000-0000-0000-000000000003', 'Join Event Group Fixed', 'group', '00000000-0000-0000-0000-000000000051');

insert into public.invite_codes (group_id, code, created_by)
values
  ('40000000-0000-0000-0000-000000000001', 'VALIDEVENT', '00000000-0000-0000-0000-000000000051'),
  ('40000000-0000-0000-0000-000000000002', 'ARCHIVEDEVENT', '00000000-0000-0000-0000-000000000051'),
  ('40000000-0000-0000-0000-000000000003', 'FIXEDGROUPCODE', '00000000-0000-0000-0000-000000000051');

-- =====================================================================
-- 1. 固定グループのメンバーでなくても有効な招待コードで参加できる
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000052"}';

select lives_ok(
  $$ select public.join_event_group('VALIDEVENT') $$,
  'a valid invite code lets a new user join the event group without being a fixed-group member'
);

select isnt_empty(
  $$ select 1 from public.group_members
     where group_id = '40000000-0000-0000-0000-000000000001'
       and user_id = '00000000-0000-0000-0000-000000000052'
       and left_at is null $$,
  'join_event_group registers the joiner as an active member'
);

reset role;

-- =====================================================================
-- 2. 過去に脱退したメンバーが再参加すると left_at がNULLに戻る(UPSERT)
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000053"}';

select lives_ok(
  $$ select public.join_event_group('VALIDEVENT') $$,
  'a previously-left member can rejoin via invite code'
);

select isnt_empty(
  $$ select 1 from public.group_members
     where group_id = '40000000-0000-0000-0000-000000000001'
       and user_id = '00000000-0000-0000-0000-000000000053'
       and left_at is null $$,
  'rejoining resets left_at to NULL instead of inserting a duplicate row'
);

select results_eq(
  $$ select count(*)::int from public.group_members
     where group_id = '40000000-0000-0000-0000-000000000001'
       and user_id = '00000000-0000-0000-0000-000000000053' $$,
  $$ values (1) $$,
  'rejoining does not create a second group_members row'
);

-- 3. 既に現役メンバーの場合はエラーにならず冪等(idempotent)
select lives_ok(
  $$ select public.join_event_group('VALIDEVENT') $$,
  'join_event_group is idempotent for an already-active member'
);

reset role;

-- =====================================================================
-- 4. 存在しない招待コードは拒否される
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000052"}';

select throws_ok(
  $$ select public.join_event_group('NOSUCHCODE') $$,
  null,
  null,
  'join_event_group rejects an unknown invite code'
);

select throws_ok(
  $$ select public.join_event_group('') $$,
  null,
  null,
  'join_event_group rejects an empty code'
);

select throws_ok(
  $$ select public.join_event_group(null) $$,
  null,
  null,
  'join_event_group rejects a null code'
);

-- =====================================================================
-- 5. クローズ(アーカイブ)済みイベントグループへの参加は拒否される
-- =====================================================================
select throws_ok(
  $$ select public.join_event_group('ARCHIVEDEVENT') $$,
  null,
  null,
  'join_event_group rejects joining an archived event group'
);

reset role;

-- =====================================================================
-- 6. 固定グループの招待コードでは参加できない(mode<>event)
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000052"}';

select throws_ok(
  $$ select public.join_event_group('FIXEDGROUPCODE') $$,
  null,
  null,
  'join_event_group rejects an invite code issued for a fixed group'
);

reset role;

-- =====================================================================
-- 7. anonロールは実行できない
-- =====================================================================
set local role anon;

select throws_ok(
  $$ select public.join_event_group('VALIDEVENT') $$,
  null,
  null,
  'anon role cannot execute join_event_group function'
);

reset role;

select * from finish();
rollback;
