begin;
select plan(11);

insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000031'), -- member
  ('00000000-0000-0000-0000-000000000032'); -- non-member

insert into public.users (id, auth_provider, display_name)
values
  ('00000000-0000-0000-0000-000000000031', 'email', 'Invite Code Member'),
  ('00000000-0000-0000-0000-000000000032', 'email', 'Invite Code Non Member');

insert into public.groups (id, name, mode, created_by)
values
  ('20000000-0000-0000-0000-000000000001', 'Invite Code Group', 'group', '00000000-0000-0000-0000-000000000031'),
  ('20000000-0000-0000-0000-000000000002', 'Invite Code Event Group', 'event', '00000000-0000-0000-0000-000000000031'),
  ('20000000-0000-0000-0000-000000000003', 'Invite Code Archived Group', 'group', '00000000-0000-0000-0000-000000000031');

update public.groups set status = 'archived'
where id = '20000000-0000-0000-0000-000000000003';

insert into public.group_members (group_id, user_id)
values
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000031'),
  ('20000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000031');

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000031"}';

select lives_ok(
  $$ select public.create_invite_code('20000000-0000-0000-0000-000000000001') $$,
  'active member can issue an invite code'
);

select isnt_empty(
  $$ select 1 from public.invite_codes where group_id = '20000000-0000-0000-0000-000000000001' $$,
  'create_invite_code creates a row for the group'
);

select is(
  (select created_by from public.invite_codes where group_id = '20000000-0000-0000-0000-000000000001'),
  '00000000-0000-0000-0000-000000000031'::uuid,
  'invite code records the issuer'
);

create temporary table invite_code_before as
select code from public.invite_codes where group_id = '20000000-0000-0000-0000-000000000001';

select lives_ok(
  $$ select public.create_invite_code('20000000-0000-0000-0000-000000000001') $$,
  're-issuing an invite code for an already-issued group succeeds'
);

select results_eq(
  $$ select count(*)::int from public.invite_codes where group_id = '20000000-0000-0000-0000-000000000001' $$,
  $$ values (1) $$,
  're-issuing replaces the existing row instead of adding a new one'
);

select isnt(
  (select code from public.invite_codes where group_id = '20000000-0000-0000-0000-000000000001'),
  (select code from invite_code_before),
  're-issuing replaces the code value with a newly generated one'
);

select throws_ok(
  $$ select public.create_invite_code('20000000-0000-0000-0000-000000000002') $$,
  null,
  null,
  'create_invite_code rejects an event group (mode<>group)'
);

select throws_ok(
  $$ select public.create_invite_code('20000000-0000-0000-0000-000000000003') $$,
  null,
  null,
  'create_invite_code rejects an archived group'
);

reset role;

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000032"}';

select throws_ok(
  $$ select public.create_invite_code('20000000-0000-0000-0000-000000000001') $$,
  null,
  null,
  'non-member cannot issue an invite code for the group'
);

reset role;

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000031"}';

select throws_like(
  $$ insert into public.invite_codes (group_id, code, created_by)
     values ('20000000-0000-0000-0000-000000000001', 'DIRECTXX', '00000000-0000-0000-0000-000000000031') $$,
  '%permission denied for table invite_codes%',
  '認証済みユーザーはinvite_codesへ直接INSERTできない(create_invite_code経由のみ)'
);

reset role;

set local role anon;

select throws_ok(
  $$ select public.create_invite_code('20000000-0000-0000-0000-000000000001') $$,
  null,
  null,
  'anon role cannot execute create_invite_code function'
);

reset role;

select * from finish();
rollback;
