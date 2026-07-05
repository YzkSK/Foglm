begin;
select plan(7);

-- Fixtures: group1(A, B所属), group2(C所属)。AとBは同じグループ、Cは別グループ。
insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000011'),
  ('00000000-0000-0000-0000-000000000012'),
  ('00000000-0000-0000-0000-000000000013');

insert into public.users (id, auth_provider, display_name)
values
  ('00000000-0000-0000-0000-000000000011', 'email', 'Member A'),
  ('00000000-0000-0000-0000-000000000012', 'email', 'Member B'),
  ('00000000-0000-0000-0000-000000000013', 'email', 'Member C');

insert into public.groups (id, name, mode, created_by)
values
  ('10000000-0000-0000-0000-000000000002', 'Group 1', 'group', '00000000-0000-0000-0000-000000000011'),
  ('10000000-0000-0000-0000-000000000003', 'Group 2', 'group', '00000000-0000-0000-0000-000000000013');

insert into public.group_members (group_id, user_id)
values
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000011'),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000012'),
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000013');

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000011"}';

select isnt_empty(
  $$ select 1 from public.users where id = '00000000-0000-0000-0000-000000000011' $$,
  'user A can see own profile'
);

select isnt_empty(
  $$ select 1 from public.users where id = '00000000-0000-0000-0000-000000000012' $$,
  'user A can see user B profile (shared active group)'
);

select is_empty(
  $$ select 1 from public.users where id = '00000000-0000-0000-0000-000000000013' $$,
  'user A cannot see user C profile (no shared group)'
);

select isnt_empty(
  $$ select 1 from public.groups where id = '10000000-0000-0000-0000-000000000002' $$,
  'user A can see group 1 (own group)'
);

select is_empty(
  $$ select 1 from public.groups where id = '10000000-0000-0000-0000-000000000003' $$,
  'user A cannot see group 2'
);

update public.users set display_name = 'hacked' where id = '00000000-0000-0000-0000-000000000012';

reset role;

select is(
  (select display_name from public.users where id = '00000000-0000-0000-0000-000000000012'),
  'Member B',
  'user A cannot update user B profile'
);

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000013"}';

delete from public.groups where id = '10000000-0000-0000-0000-000000000002';

reset role;

select isnt_empty(
  $$ select 1 from public.groups where id = '10000000-0000-0000-0000-000000000002' $$,
  'group 1 still exists after user C (not the owner) attempted delete'
);

select * from finish();
rollback;
