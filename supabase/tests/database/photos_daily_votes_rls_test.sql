begin;
select plan(5);

-- Fixtures: group1(A所属), group2(C所属)。group1にphotoとdaily_voteが1件ずつ。
insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000031'),
  ('00000000-0000-0000-0000-000000000032');

insert into public.users (id, auth_provider, display_name)
values
  ('00000000-0000-0000-0000-000000000031', 'email', 'Member A'),
  ('00000000-0000-0000-0000-000000000032', 'email', 'Member C');

insert into public.groups (id, name, mode, created_by)
values
  ('10000000-0000-0000-0000-000000000005', 'Group 1', 'group', '00000000-0000-0000-0000-000000000031'),
  ('10000000-0000-0000-0000-000000000006', 'Group 2', 'group', '00000000-0000-0000-0000-000000000032');

insert into public.group_members (group_id, user_id)
values
  ('10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000031'),
  ('10000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000032');

insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
values (
  '20000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000005',
  '00000000-0000-0000-0000-000000000031',
  now(), current_date, 'original/path.jpg', 'blurred/path.jpg'
);

insert into public.daily_votes (id, group_id, vote_date)
values (
  '30000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000005',
  current_date
);

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000031"}';

select isnt_empty(
  $$ select 1 from public.photos where id = '20000000-0000-0000-0000-000000000001' $$,
  'member A can see photo in own group'
);

select isnt_empty(
  $$ select 1 from public.daily_votes where id = '30000000-0000-0000-0000-000000000001' $$,
  'member A can see daily_vote in own group'
);

select throws_ok(
  $$ insert into public.photos (group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
     values ('10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000031', now(), current_date, 'x', 'y') $$,
  null,
  null,
  'member A cannot insert photo directly (client has no write policy)'
);

reset role;

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000032"}';

select is_empty(
  $$ select 1 from public.photos where id = '20000000-0000-0000-0000-000000000001' $$,
  'member C (different group) cannot see photo in group 1'
);

select is_empty(
  $$ select 1 from public.daily_votes where id = '30000000-0000-0000-0000-000000000001' $$,
  'member C (different group) cannot see daily_vote in group 1'
);

reset role;

select * from finish();
rollback;
