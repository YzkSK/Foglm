begin;
select plan(8);

insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000021');

insert into public.users (id, auth_provider, display_name)
values
  ('00000000-0000-0000-0000-000000000021', 'email', 'Group Creator');

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000021"}';

select lives_ok(
  $$ select public.create_group('New Group') $$,
  'authenticated user can call create_group'
);

select isnt_empty(
  $$ select 1 from public.groups where name = 'New Group' and mode = 'group'
     and created_by = '00000000-0000-0000-0000-000000000021' $$,
  'create_group creates a group row owned by the caller'
);

select isnt_empty(
  $$ select 1 from public.group_members
     where group_id = (select id from public.groups where name = 'New Group')
       and user_id = '00000000-0000-0000-0000-000000000021'
       and left_at is null $$,
  'create_group registers the creator as an active member'
);

select is(
  (select mode from public.groups where name = 'New Group'),
  'group',
  'created group has mode=group'
);

select throws_ok(
  $$ select public.create_group('') $$,
  null,
  null,
  'create_group rejects an empty name'
);

select throws_ok(
  $$ select public.create_group(null) $$,
  null,
  null,
  'create_group rejects a null name'
);

select throws_ok(
  $$ select public.create_group('　　　') $$,
  null,
  null,
  'create_group rejects a whitespace-only name'
);

reset role;

-- anon role cannot execute the function (revoked from public, granted only to authenticated)
set local role anon;

select throws_ok(
  $$ select public.create_group('Anon Group') $$,
  null,
  null,
  'anon role cannot execute create_group function'
);

reset role;

select * from finish();
rollback;
