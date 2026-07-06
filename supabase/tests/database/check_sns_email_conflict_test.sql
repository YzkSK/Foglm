begin;
select plan(4);

-- Fixtures: googleで登録済みのユーザー2人(小文字と大文字混合)、emailで登録済みのユーザー1人
insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000021'),
  ('00000000-0000-0000-0000-000000000022'),
  ('00000000-0000-0000-0000-000000000023');

insert into auth.identities (id, user_id, provider, identity_data, provider_id, last_sign_in_at, created_at, updated_at)
values
  (
    '00000000-0000-0000-0000-000000000031',
    '00000000-0000-0000-0000-000000000021',
    'google',
    '{"sub": "google-sub-1", "email": "taken-by-google@example.com"}'::jsonb,
    'google-sub-1',
    now(),
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000032',
    '00000000-0000-0000-0000-000000000022',
    'email',
    '{"sub": "00000000-0000-0000-0000-000000000022", "email": "taken-by-email@example.com"}'::jsonb,
    '00000000-0000-0000-0000-000000000022',
    now(),
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000033',
    '00000000-0000-0000-0000-000000000023',
    'google',
    '{"sub": "google-sub-2", "email": "Mixed-Case@Example.com"}'::jsonb,
    'google-sub-2',
    now(),
    now(),
    now()
  );

select is(
  (select public.check_sns_email_conflict('taken-by-google@example.com')),
  'google',
  'SNS(google)で使用済みのメールアドレスはproviderを返す'
);

select is(
  (select public.check_sns_email_conflict('taken-by-email@example.com')),
  null,
  'emailプロバイダで登録済みのアドレスは対象外(NULLを返す)'
);

select is(
  (select public.check_sns_email_conflict('unused@example.com')),
  null,
  '未使用のメールアドレスはNULLを返す'
);

select is(
  (select public.check_sns_email_conflict('mixed-case@example.com')),
  'google',
  '大文字小文字が異なるメールアドレスでも一致する(大文字小文字を区別しない比較)'
);

select * from finish();
rollback;
