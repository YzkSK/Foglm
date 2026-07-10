-- delete_account_data: アカウント削除(delete_account Edge Function)本体処理を検証する
-- (issue #104 / 仕様書 3.1.3・6.1参照)。
begin;
select plan(15);

insert into auth.users (id, email)
values
  ('a1000000-0000-0000-0000-000000000001', 'user-a@example.com'), -- A: 削除するアカウント
  ('a1000000-0000-0000-0000-000000000002', 'user-b@example.com'), -- B: 固定グループの他メンバー(作成者委譲を受ける)
  ('a1000000-0000-0000-0000-000000000003', 'user-c@example.com'); -- C: イベントグループの他メンバー

insert into public.users (id, auth_provider, email, display_name, avatar_url, fcm_token)
values
  ('a1000000-0000-0000-0000-000000000001', 'email', 'user-a@example.com', 'Account A', 'avatar-a.png', 'fcm-a-token'),
  ('a1000000-0000-0000-0000-000000000002', 'email', 'user-b@example.com', 'Account B', 'avatar-b.png', 'fcm-b-token'),
  ('a1000000-0000-0000-0000-000000000003', 'email', 'user-c@example.com', 'Account C', 'avatar-c.png', 'fcm-c-token');

insert into auth.identities (provider_id, user_id, identity_data, provider)
values (
  'a1000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000001',
  '{"sub": "a1000000-0000-0000-0000-000000000001", "email": "user-a@example.com"}',
  'email'
);

-- G1: 固定グループ。Aが作成者、Bも現役メンバー(Aの脱退で作成者権限がBへ委譲される)
insert into public.groups (id, name, mode, created_by)
values ('a2000000-0000-0000-0000-000000000001', 'G1 Fixed Group', 'group', 'a1000000-0000-0000-0000-000000000001');

-- G2: 固定グループ。Aのみが現役メンバー(Aの脱退でメンバー0人になり即座解散される)
insert into public.groups (id, name, mode, created_by)
values ('a2000000-0000-0000-0000-000000000002', 'G2 Fixed Group', 'group', 'a1000000-0000-0000-0000-000000000001');

-- G3: イベントグループ。Cが作成者、Aも現役メンバー
insert into public.groups (id, name, mode, created_by, start_date, end_date)
values ('a2000000-0000-0000-0000-000000000003', 'G3 Event Group', 'event', 'a1000000-0000-0000-0000-000000000003', current_date, current_date + 7);

insert into public.group_members (group_id, user_id)
values
  ('a2000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001'),
  ('a2000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000002'),
  ('a2000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000001'),
  ('a2000000-0000-0000-0000-000000000003', 'a1000000-0000-0000-0000-000000000001'),
  ('a2000000-0000-0000-0000-000000000003', 'a1000000-0000-0000-0000-000000000003');

-- Aのソロモード空間(ensure_solo_spaceトリガーによりpublic.users挿入時に自動作成済み)に
-- 写真・Storageオブジェクトを紐付け、完全削除されることを検証できるようにする
insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
values (
  'a3000000-0000-0000-0000-000000000001',
  (select id from public.groups where mode = 'solo' and created_by = 'a1000000-0000-0000-0000-000000000001'),
  'a1000000-0000-0000-0000-000000000001',
  now(), current_date, 'delete_account/solo_original.jpg', 'delete_account/solo_blurred.jpg'
);

insert into storage.objects (bucket_id, name)
values
  ('photo-originals', 'delete_account/solo_original.jpg'),
  ('photo-blurred', 'delete_account/solo_blurred.jpg');

-- =====================================================================
-- 1. 未認証・anonロールは実行できない
-- =====================================================================
set local role authenticated;

select throws_ok(
  $$ select public.delete_account_data() $$,
  null,
  null,
  'delete_account_data rejects a call without an authenticated user'
);

reset role;
set local role anon;

select throws_ok(
  $$ select public.delete_account_data() $$,
  null,
  null,
  'anon role cannot execute delete_account_data function'
);

reset role;

-- =====================================================================
-- 2. 本人が呼び出すと正常に完了する
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "a1000000-0000-0000-0000-000000000001"}';

select lives_ok(
  $$ select public.delete_account_data() $$,
  'the account owner can execute delete_account_data'
);

reset role;

-- =====================================================================
-- 3. G1(固定グループ): Aは脱退し、作成者権限はBへ委譲される
-- =====================================================================
select ok(
  (select left_at is not null from public.group_members
   where group_id = 'a2000000-0000-0000-0000-000000000001' and user_id = 'a1000000-0000-0000-0000-000000000001'),
  'G1: A left the group'
);

select is(
  (select created_by from public.groups where id = 'a2000000-0000-0000-0000-000000000001'),
  'a1000000-0000-0000-0000-000000000002'::uuid,
  'G1: creator role was delegated to remaining active member B'
);

select ok(
  (select left_at is null from public.group_members
   where group_id = 'a2000000-0000-0000-0000-000000000001' and user_id = 'a1000000-0000-0000-0000-000000000002'),
  'G1: B remains an active member'
);

-- =====================================================================
-- 4. G2(固定グループ、Aのみ現役): メンバー0人となり即座解散される
-- =====================================================================
select is_empty(
  $$ select 1 from public.groups where id = 'a2000000-0000-0000-0000-000000000002' $$,
  'G2: the group was dissolved immediately since no active members remain'
);

-- =====================================================================
-- 5. G3(イベントグループ): Aは脱退するが、作成者委譲・解散は連動しない
-- =====================================================================
select ok(
  (select left_at is not null from public.group_members
   where group_id = 'a2000000-0000-0000-0000-000000000003' and user_id = 'a1000000-0000-0000-0000-000000000001'),
  'G3: A left the event group'
);

select isnt_empty(
  $$ select 1 from public.groups where id = 'a2000000-0000-0000-0000-000000000003' $$,
  'G3: the event group itself is not dissolved by a member deletion'
);

-- =====================================================================
-- 6. ソロモードのグループ・写真・Storageは完全削除される
-- =====================================================================
select is_empty(
  $$ select 1 from public.groups where mode = 'solo' and created_by = 'a1000000-0000-0000-0000-000000000001' $$,
  'the solo group is completely deleted'
);

select is_empty(
  $$ select 1 from public.photos where id = 'a3000000-0000-0000-0000-000000000001' $$,
  'the solo photo is completely deleted'
);

select is_empty(
  $$ select 1 from storage.objects
     where (bucket_id = 'photo-originals' and name = 'delete_account/solo_original.jpg')
        or (bucket_id = 'photo-blurred' and name = 'delete_account/solo_blurred.jpg') $$,
  'the solo photo storage objects are completely deleted'
);

-- =====================================================================
-- 7. public.usersが匿名化され、auth側の認証情報も解放される
-- =====================================================================
select ok(
  (select deleted_at is not null and display_name = '退会したユーザー' and avatar_url is null
     and email is null and fcm_token is null
   from public.users where id = 'a1000000-0000-0000-0000-000000000001'),
  'public.users is anonymized (deleted_at set, display_name/avatar_url/email/fcm_token cleared)'
);

select is_empty(
  $$ select 1 from auth.identities where user_id = 'a1000000-0000-0000-0000-000000000001' $$,
  'the auth.identities row for the deleted account is removed'
);

select is(
  (select email from auth.users where id = 'a1000000-0000-0000-0000-000000000001'),
  'a1000000-0000-0000-0000-000000000001@deleted.invalid',
  'auth.users.email is rewritten to a non-reusable value, freeing it up for a new sign-up'
);

select * from finish();
rollback;
