begin;
select plan(7);

-- Fixtures: 7 auth users + matching public.users rows, 1 group.
insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000001'),
  ('00000000-0000-0000-0000-000000000002'),
  ('00000000-0000-0000-0000-000000000003'),
  ('00000000-0000-0000-0000-000000000004'),
  ('00000000-0000-0000-0000-000000000005'),
  ('00000000-0000-0000-0000-000000000006'),
  ('00000000-0000-0000-0000-000000000007');

insert into public.users (id, auth_provider, display_name)
select id, 'email', 'Test User ' || id::text
from auth.users
where id in (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000004',
  '00000000-0000-0000-0000-000000000005',
  '00000000-0000-0000-0000-000000000006',
  '00000000-0000-0000-0000-000000000007'
);

insert into public.groups (id, name, mode)
values ('10000000-0000-0000-0000-000000000001', 'Limit Test Group', 'group');

-- First 6 active members must succeed.
select lives_ok(
  $$ insert into public.group_members (group_id, user_id)
     values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001') $$,
  'member 1 joins successfully'
);
select lives_ok(
  $$ insert into public.group_members (group_id, user_id)
     values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002') $$,
  'member 2 joins successfully'
);
select lives_ok(
  $$ insert into public.group_members (group_id, user_id)
     values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003') $$,
  'member 3 joins successfully'
);
select lives_ok(
  $$ insert into public.group_members (group_id, user_id)
     values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004') $$,
  'member 4 joins successfully'
);
select lives_ok(
  $$ insert into public.group_members (group_id, user_id)
     values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000005') $$,
  'member 5 joins successfully'
);
select lives_ok(
  $$ insert into public.group_members (group_id, user_id)
     values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000006') $$,
  'member 6 joins successfully (reaches the 6-member cap)'
);

-- 7th active member must be rejected by check_group_member_limit().
select throws_ok(
  $$ insert into public.group_members (group_id, user_id)
     values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000007') $$,
  'P0001',
  'group_members: group 10000000-0000-0000-0000-000000000001 already has 6 active members (max 6)',
  'member 7 is rejected once the group is at capacity'
);

select * from finish();
rollback;
