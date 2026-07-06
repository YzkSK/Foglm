begin;
select plan(3);

insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000051');

insert into public.users (id, auth_provider, display_name, deleted_at)
values
  ('00000000-0000-0000-0000-000000000051', 'email', 'Test User', null);

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000051"}';

select throws_like(
  $$ update public.users set auth_provider = 'google' where id = '00000000-0000-0000-0000-000000000051' $$,
  '%permission denied for table users%',
  '認証済みユーザーは自分のauth_providerを直接更新できない'
);

select throws_like(
  $$ update public.users set deleted_at = now() where id = '00000000-0000-0000-0000-000000000051' $$,
  '%permission denied for table users%',
  '認証済みユーザーは自分のdeleted_atを直接更新できない'
);

update public.users set display_name = 'Updated Name' where id = '00000000-0000-0000-0000-000000000051';

reset role;

select is(
  (select display_name from public.users where id = '00000000-0000-0000-0000-000000000051'),
  'Updated Name',
  'display_nameは引き続き自分で更新できる'
);

select * from finish();
rollback;
