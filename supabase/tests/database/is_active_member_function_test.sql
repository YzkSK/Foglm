begin;
select plan(4);

insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000001'),
  ('00000000-0000-0000-0000-000000000002');

insert into public.users (id, auth_provider, display_name)
values
  ('00000000-0000-0000-0000-000000000001', 'email', 'Active Member'),
  ('00000000-0000-0000-0000-000000000002', 'email', 'Left Member');

insert into public.groups (id, name, mode)
values ('10000000-0000-0000-0000-000000000001', 'Helper Function Test Group', 'group');

insert into public.group_members (group_id, user_id, left_at)
values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', null),
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', now());

select ok(
  public.is_active_member('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001'),
  'active member returns true'
);

select ok(
  not public.is_active_member('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002'),
  'left member returns false'
);

select ok(
  not public.is_active_member('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000099'),
  'non-member returns false'
);

-- anon role cannot execute the function (SECURITY DEFINER function should be restricted)
set local role anon;

select throws_ok(
  $$ select public.is_active_member('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001') $$,
  null,
  null,
  'anon role cannot execute is_active_member function'
);

reset role;

select * from finish();
rollback;
