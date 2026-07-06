begin;
select plan(2);

-- メール/パスワードでサインアップ(email_confirmed_atは未設定)。
insert into auth.users (id, email, raw_app_meta_data, email_confirmed_at)
values (
  '00000000-0000-0000-0000-000000000061',
  'email-user@example.com',
  '{"provider": "email"}',
  null
);

select is(
  (select email_verified from public.users where id = '00000000-0000-0000-0000-000000000061'),
  false,
  'メール登録直後はemail_verifiedがfalse'
);

-- 確認メールのリンクを踏んだことを模してemail_confirmed_atを設定する。
update auth.users
set email_confirmed_at = now()
where id = '00000000-0000-0000-0000-000000000061';

select is(
  (select email_verified from public.users where id = '00000000-0000-0000-0000-000000000061'),
  true,
  'メール確認完了後にemail_verifiedがtrueに同期される'
);

select * from finish();
rollback;
