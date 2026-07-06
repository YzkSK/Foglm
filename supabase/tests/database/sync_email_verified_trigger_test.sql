begin;
select plan(2);

insert into auth.users (id) values ('00000000-0000-0000-0000-000000000041');
insert into public.users (id, auth_provider, email, email_verified, display_name)
values ('00000000-0000-0000-0000-000000000041', 'email', 'pending@example.com', false, 'pending');

update auth.users
set email_confirmed_at = now()
where id = '00000000-0000-0000-0000-000000000041';

select is(
  (select email_verified from public.users where id = '00000000-0000-0000-0000-000000000041'),
  true,
  'email_confirmed_atが設定されるとpublic.users.email_verifiedがtrueになる'
);

update auth.users
set email_confirmed_at = null
where id = '00000000-0000-0000-0000-000000000041';

select is(
  (select email_verified from public.users where id = '00000000-0000-0000-0000-000000000041'),
  true,
  'email_confirmed_atがNULLに戻ってもemail_verifiedはtrueのまま(一度確認済みなら取り消されない)'
);

select * from finish();
rollback;
