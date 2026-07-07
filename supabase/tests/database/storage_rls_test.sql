begin;
select plan(5);

-- Fixtures: group1(A所属), group2(C所属)。group1の写真の原本・ボヤけ版オブジェクトを1件ずつ用意
insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000041'),
  ('00000000-0000-0000-0000-000000000042');

insert into public.users (id, auth_provider, display_name)
values
  ('00000000-0000-0000-0000-000000000041', 'email', 'Member A'),
  ('00000000-0000-0000-0000-000000000042', 'email', 'Member C');

insert into public.groups (id, name, mode, created_by)
values
  ('10000000-0000-0000-0000-000000000007', 'Group 1', 'group', '00000000-0000-0000-0000-000000000041'),
  ('10000000-0000-0000-0000-000000000008', 'Group 2', 'group', '00000000-0000-0000-0000-000000000042');

insert into public.group_members (group_id, user_id)
values
  ('10000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000041'),
  ('10000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000042');

insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
values (
  '20000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000007',
  '00000000-0000-0000-0000-000000000041',
  now(), current_date, 'original/photo.jpg', 'blurred/photo.jpg'
);

insert into storage.objects (bucket_id, name)
values
  ('photo-originals', 'original/photo.jpg'),
  ('photo-blurred', 'blurred/photo.jpg');

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000041"}';

select isnt_empty(
  $$ select 1 from storage.objects where bucket_id = 'photo-blurred' and name = 'blurred/photo.jpg' $$,
  'member A can see blurred object of own group photo'
);

select is_empty(
  $$ select 1 from storage.objects where bucket_id = 'photo-originals' and name = 'original/photo.jpg' $$,
  'member A cannot see original object even for own group photo'
);

reset role;

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000042"}';

select is_empty(
  $$ select 1 from storage.objects where bucket_id = 'photo-blurred' and name = 'blurred/photo.jpg' $$,
  'member C (different group) cannot see blurred object of group 1 photo'
);

select is_empty(
  $$ select 1 from storage.objects where bucket_id = 'photo-originals' and name = 'original/photo.jpg' $$,
  'member C (different group) cannot see original object of group 1 photo'
);

reset role;

set local role anon;

select is_empty(
  $$ select 1 from storage.objects where bucket_id = 'photo-blurred' and name = 'blurred/photo.jpg' $$,
  'anon cannot see blurred object'
);

reset role;

select * from finish();
rollback;
