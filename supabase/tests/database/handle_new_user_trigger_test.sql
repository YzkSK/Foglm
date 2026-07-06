begin;
select plan(6);

-- providerメタデータの無い直接INSERT(既存テストのfixtureと同じ形)ではトリガーは何もしない。
insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000021');

select is_empty(
  $$ select 1 from public.users where id = '00000000-0000-0000-0000-000000000021' $$,
  'provider未設定のauth.users行ではpublic.usersは自動作成されない'
);

-- googleログイン: email_verified が自動でtrueになる。
insert into auth.users (id, email, raw_app_meta_data, raw_user_meta_data)
values (
  '00000000-0000-0000-0000-000000000022',
  'google-user@example.com',
  '{"provider": "google"}',
  '{"full_name": "Google User", "avatar_url": "https://example.com/g.png"}'
);

select is(
  (select auth_provider from public.users where id = '00000000-0000-0000-0000-000000000022'),
  'google',
  'googleログインでauth_providerがgoogleになる'
);

select is(
  (select email_verified from public.users where id = '00000000-0000-0000-0000-000000000022'),
  true,
  'SNSログインはemail_verifiedが自動でtrueになる'
);

select is(
  (select display_name from public.users where id = '00000000-0000-0000-0000-000000000022'),
  'Google User',
  'full_nameがdisplay_nameとして使われる'
);

select is(
  (select avatar_url from public.users where id = '00000000-0000-0000-0000-000000000022'),
  'https://example.com/g.png',
  'avatar_urlがメタデータから設定される'
);

-- twitter(x)プロバイダは 'x' に正規化される。
insert into auth.users (id, email, raw_app_meta_data)
values (
  '00000000-0000-0000-0000-000000000023',
  'x-user@example.com',
  '{"provider": "twitter"}'
);

select is(
  (select auth_provider from public.users where id = '00000000-0000-0000-0000-000000000023'),
  'x',
  'twitterプロバイダはxに正規化される'
);

select * from finish();
rollback;
