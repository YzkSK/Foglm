begin;
select plan(2);

insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000041');

insert into public.users (id, auth_provider, display_name)
values
  ('00000000-0000-0000-0000-000000000041', 'email', 'Helper Test User');

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000041"}';

select throws_like(
  $$ select public._create_group_and_register_creator('Direct Call', 'group') $$,
  '%permission denied for function _create_group_and_register_creator%',
  '内部ヘルパー_create_group_and_register_creatorはcreate_group/create_event_group経由以外から呼び出せない'
);

select lives_ok(
  $$ select public.create_event_group('Helper Delegation Check', '2026-08-01', '2026-08-03') $$,
  'create_event_group still works via the shared helper after the refactor'
);

reset role;

select * from finish();
rollback;
