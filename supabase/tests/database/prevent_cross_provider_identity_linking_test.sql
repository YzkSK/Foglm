begin;
select plan(3);

-- 既存ユーザー: メール・パスワード方式で登録済み。
insert into auth.users (id, email, raw_app_meta_data)
values (
  '00000000-0000-0000-0000-000000000041',
  'linked-user@example.com',
  '{"provider": "email"}'
);

-- Supabase Authの自動アカウントリンクを模した、同一ユーザーへのgoogleアイデンティティ追加はブロックされる。
select throws_like(
  $$
    insert into auth.identities (provider_id, user_id, identity_data, provider)
    values (
      'google-sub-1',
      '00000000-0000-0000-0000-000000000041',
      '{"sub": "google-sub-1", "email": "linked-user@example.com"}',
      'google'
    )
  $$,
  'DUPLICATE_ACCOUNT%',
  '既存アカウントと異なるプロバイダのアイデンティティ追加(自動リンク)は拒否される'
);

-- 新規サインアップ: auth.users作成直後、同じプロバイダの最初のアイデンティティ追加は許可される。
insert into auth.users (id, email, raw_app_meta_data)
values (
  '00000000-0000-0000-0000-000000000042',
  'google-user@example.com',
  '{"provider": "google"}'
);

insert into auth.identities (provider_id, user_id, identity_data, provider)
values (
  'google-sub-2',
  '00000000-0000-0000-0000-000000000042',
  '{"sub": "google-sub-2", "email": "google-user@example.com"}',
  'google'
);

select isnt_empty(
  $$ select 1 from auth.identities where user_id = '00000000-0000-0000-0000-000000000042' $$,
  '新規サインアップ直後の同一プロバイダのアイデンティティ追加は許可される'
);

-- twitterプロバイダは x に正規化されるため、既存auth_provider='x'のユーザーへのtwitterアイデンティティ追加は許可される。
insert into auth.users (id, email, raw_app_meta_data)
values (
  '00000000-0000-0000-0000-000000000043',
  'x-user@example.com',
  '{"provider": "twitter"}'
);

insert into auth.identities (provider_id, user_id, identity_data, provider)
values (
  'x-sub-1',
  '00000000-0000-0000-0000-000000000043',
  '{"sub": "x-sub-1", "email": "x-user@example.com"}',
  'twitter'
);

select isnt_empty(
  $$ select 1 from auth.identities where user_id = '00000000-0000-0000-0000-000000000043' $$,
  'twitterプロバイダは正規化されて既存アカウントと一致するため許可される'
);

select * from finish();
rollback;
