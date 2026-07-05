begin;
select plan(7);

-- Fixtures: group(A=現役メンバー, D=脱退済み)。B=Aが招待する相手。F=グループと無関係の第三者。E=Fが招待しようとする相手。
insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000021'),
  ('00000000-0000-0000-0000-000000000022'),
  ('00000000-0000-0000-0000-000000000023'),
  ('00000000-0000-0000-0000-000000000024'),
  ('00000000-0000-0000-0000-000000000025');

insert into public.users (id, auth_provider, display_name)
values
  ('00000000-0000-0000-0000-000000000021', 'email', 'Member A'),
  ('00000000-0000-0000-0000-000000000022', 'email', 'Invitee B'),
  ('00000000-0000-0000-0000-000000000023', 'email', 'Left Member D'),
  ('00000000-0000-0000-0000-000000000024', 'email', 'Unrelated F'),
  ('00000000-0000-0000-0000-000000000025', 'email', 'Invitee E');

insert into public.groups (id, name, mode, created_by)
values
  ('10000000-0000-0000-0000-000000000004', 'Group Members Test', 'group', '00000000-0000-0000-0000-000000000021'),
  ('10000000-0000-0000-0000-000000000005', 'Another Group', 'group', '00000000-0000-0000-0000-000000000024');

insert into public.group_members (group_id, user_id, left_at)
values
  ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000021', null),
  ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000023', now());

-- 現役メンバーAは他ユーザーBを招待できる
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000021"}';

select lives_ok(
  $$ insert into public.group_members (group_id, user_id)
     values ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000022') $$,
  'active member A can invite user B'
);

select isnt_empty(
  $$ select 1 from public.group_members where group_id = '10000000-0000-0000-0000-000000000004' and user_id = '00000000-0000-0000-0000-000000000021' $$,
  'user A can see own membership row'
);

reset role;

-- 脱退済みメンバーDは閲覧不可
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000023"}';

select is_empty(
  $$ select 1 from public.group_members where group_id = '10000000-0000-0000-0000-000000000004' $$,
  'left member D cannot see any group_members rows of the group'
);

reset role;

-- 招待によって現役メンバーになったBは、同じグループの他の行(脱退済みDの行も含む)を閲覧できる
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000022"}';

select isnt_empty(
  $$ select 1 from public.group_members where group_id = '10000000-0000-0000-0000-000000000004' and user_id = '00000000-0000-0000-0000-000000000023' $$,
  'newly active member B can see left member D row within the same group'
);

reset role;

-- グループと無関係なFは、E(Fとは別人)をこのグループに招待できない
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000024"}';

select throws_ok(
  $$ insert into public.group_members (group_id, user_id)
     values ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000025') $$,
  null,
  null,
  'unrelated user F cannot invite user E into a group F does not belong to'
);

reset role;

-- Aが別のグループに自分の行を移動しようとしても失敗する(トリガーで防止)
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000021"}';

select throws_ok(
  $$ update public.group_members set group_id = '10000000-0000-0000-0000-000000000005'
     where group_id = '10000000-0000-0000-0000-000000000004' and user_id = '00000000-0000-0000-0000-000000000021' $$,
  'P0001',
  'group_members: group_id cannot be changed on update',
  'user A cannot change group_id on their own row'
);

reset role;

-- Aは自分の行をUPDATE(脱退)できる
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000021"}';

update public.group_members set left_at = now()
where group_id = '10000000-0000-0000-0000-000000000004' and user_id = '00000000-0000-0000-0000-000000000021';

reset role;

select isnt_empty(
  $$ select 1 from public.group_members
     where group_id = '10000000-0000-0000-0000-000000000004'
       and user_id = '00000000-0000-0000-0000-000000000021'
       and left_at is not null $$,
  'user A can update own row to leave the group'
);

select * from finish();
rollback;
