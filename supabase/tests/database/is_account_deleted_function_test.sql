begin;
select plan(3);

insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000031'),
  ('00000000-0000-0000-0000-000000000032');

insert into public.users (id, auth_provider, display_name, deleted_at)
values
  ('00000000-0000-0000-0000-000000000031', 'email', 'Active User', null),
  ('00000000-0000-0000-0000-000000000032', 'email', '退会したユーザー', now());

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000031"}';

select ok(
  not public.is_account_deleted(),
  '削除されていないアカウントはfalseを返す'
);

reset role;
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000032"}';

select ok(
  public.is_account_deleted(),
  '削除済み(deleted_at設定済み)アカウントはtrueを返す'
);

reset role;
set local role anon;

select throws_ok(
  $$ select public.is_account_deleted() $$,
  null,
  null,
  'anonロールはis_account_deletedを実行できない'
);

reset role;

select * from finish();
rollback;
