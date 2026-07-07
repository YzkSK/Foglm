begin;
select plan(5);

insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000061'),
  ('00000000-0000-0000-0000-000000000062');

insert into public.users (id, auth_provider, display_name, avatar_url)
values
  ('00000000-0000-0000-0000-000000000061', 'email', 'Old Name', 'https://example.com/old.png'),
  ('00000000-0000-0000-0000-000000000062', 'email', 'Other User', null);

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000061"}';

select lives_ok(
  $$ select public.update_profile('New Name', 'https://example.com/new.png') $$,
  '本人はupdate_profileでニックネーム・アイコンを更新できる'
);

reset role;

select is(
  (select display_name from public.users where id = '00000000-0000-0000-0000-000000000061'),
  'New Name',
  'display_nameが更新される'
);

select is(
  (select avatar_url from public.users where id = '00000000-0000-0000-0000-000000000061'),
  'https://example.com/new.png',
  'avatar_urlが更新される'
);

select is(
  (select display_name from public.users where id = '00000000-0000-0000-0000-000000000062'),
  'Other User',
  '他人の行は更新されない'
);

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000061"}';

select throws_like(
  $$ select public.update_profile('   ', null) $$,
  '%display_name must not be blank%',
  '空白のみのニックネームは拒否される'
);

reset role;

select * from finish();
rollback;
