begin;
select plan(5);

-- 通常のサインアップ(email)ではhandle_new_userでpublic.usersが作成され、
-- 続けてensure_solo_spaceでmode=soloのグループと自身のgroup_membersが自動作成される。
insert into auth.users (id, email, raw_app_meta_data, raw_user_meta_data)
values (
  '00000000-0000-0000-0000-000000000030',
  'solo-user@example.com',
  '{"provider": "email"}',
  '{"full_name": "Solo User"}'
);

select is(
  (select mode from public.groups where created_by = '00000000-0000-0000-0000-000000000030'),
  'solo',
  'サインアップ時にmode=soloのグループが自動作成される'
);

select is(
  (select count(*)::int from public.groups where created_by = '00000000-0000-0000-0000-000000000030'),
  1,
  'ソロ空間は1件だけ作成される'
);

select ok(
  exists (
    select 1
    from public.group_members gm
    join public.groups g on g.id = gm.group_id
    where g.created_by = '00000000-0000-0000-0000-000000000030'
      and gm.user_id = '00000000-0000-0000-0000-000000000030'
      and gm.left_at is null
  ),
  '本人がgroup_membersに現役メンバーとして登録される'
);

-- providerメタデータの無い直接INSERT(handle_new_userが何もしないケース)では
-- public.usersが作成されないため、ソロ空間も作成されない。
insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000031');

select is_empty(
  $$ select 1 from public.groups where created_by = '00000000-0000-0000-0000-000000000031' $$,
  'public.usersが作成されない場合はソロ空間も作成されない'
);

select is_empty(
  $$ select 1 from public.group_members where user_id = '00000000-0000-0000-0000-000000000031' $$,
  'public.usersが作成されない場合はgroup_membersにも登録されない'
);

select * from finish();
rollback;
