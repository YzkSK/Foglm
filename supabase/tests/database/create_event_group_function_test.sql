begin;
select plan(11);

insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000031');

insert into public.users (id, auth_provider, display_name)
values
  ('00000000-0000-0000-0000-000000000031', 'email', 'Event Creator');

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000031"}';

select lives_ok(
  $$ select public.create_event_group('Trip', '2026-08-01', '2026-08-03') $$,
  'authenticated user can call create_event_group'
);

select isnt_empty(
  $$ select 1 from public.groups where name = 'Trip' and mode = 'event'
     and created_by = '00000000-0000-0000-0000-000000000031'
     and start_date = '2026-08-01' and end_date = '2026-08-03' $$,
  'create_event_group creates a group row owned by the caller with the given period'
);

select isnt_empty(
  $$ select 1 from public.group_members
     where group_id = (select id from public.groups where name = 'Trip')
       and user_id = '00000000-0000-0000-0000-000000000031'
       and left_at is null $$,
  'create_event_group registers the creator as an active member'
);

select is(
  (select mode from public.groups where name = 'Trip'),
  'event',
  'created group has mode=event'
);

select throws_ok(
  $$ select public.create_event_group('', '2026-08-01', '2026-08-03') $$,
  null,
  null,
  'create_event_group rejects an empty name'
);

select throws_ok(
  $$ select public.create_event_group(null, '2026-08-01', '2026-08-03') $$,
  null,
  null,
  'create_event_group rejects a null name'
);

select throws_ok(
  $$ select public.create_event_group('No Start', null, '2026-08-03') $$,
  null,
  null,
  'create_event_group rejects a null start_date'
);

select throws_ok(
  $$ select public.create_event_group('No End', '2026-08-01', null) $$,
  null,
  null,
  'create_event_group rejects a null end_date'
);

select throws_ok(
  $$ select public.create_event_group('Reversed', '2026-08-03', '2026-08-01') $$,
  null,
  null,
  'create_event_group rejects end_date before start_date'
);

select throws_like(
  $$ insert into public.groups (name, mode, start_date, end_date, created_by)
     values ('Direct Insert', 'event', '2026-08-01', '2026-08-03', '00000000-0000-0000-0000-000000000031') $$,
  '%permission denied for table groups%',
  '認証済みユーザーはgroupsへ直接INSERTできない(create_event_group経由のみ)'
);

reset role;

-- anon role cannot execute the function (revoked from public, granted only to authenticated)
set local role anon;

select throws_ok(
  $$ select public.create_event_group('Anon Event', '2026-08-01', '2026-08-03') $$,
  null,
  null,
  'anon role cannot execute create_event_group function'
);

reset role;

select * from finish();
rollback;
