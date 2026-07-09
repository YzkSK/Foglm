-- leave_group: 現役メンバーが0人になった場合、猶予期間を待たずdissolve_group_dataによって
-- 即座に解散(完全削除)されることを検証する(issue #16 / 仕様書 3.2.1・6.2参照)。
begin;
select plan(4);

insert into auth.users (id) values
  ('a1000000-0000-0000-0000-000000000001'), -- 固定グループ: 残り1人からさらに脱退するメンバー
  ('a1000000-0000-0000-0000-000000000002'); -- 固定グループ: 先に脱退済みのメンバー(写真の撮影者)

insert into public.users (id, auth_provider, display_name)
values
  ('a1000000-0000-0000-0000-000000000001', 'email', 'ZeroMember Last'),
  ('a1000000-0000-0000-0000-000000000002', 'email', 'ZeroMember Already Left');

insert into public.groups (id, name, mode, created_by)
values ('a2000000-0000-0000-0000-000000000001', 'ZeroMember Group', 'group', 'a1000000-0000-0000-0000-000000000001');

insert into public.group_members (group_id, user_id, left_at)
values
  ('a2000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', null),
  ('a2000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000002', now() - interval '1 day');

insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
values (
  'a3000000-0000-0000-0000-000000000001',
  'a2000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000002',
  now(), current_date, 'zero_member/original.jpg', 'zero_member/blurred.jpg'
);

insert into storage.objects (bucket_id, name)
values
  ('photo-originals', 'zero_member/original.jpg'),
  ('photo-blurred', 'zero_member/blurred.jpg');

set local role authenticated;
set local request.jwt.claims to '{"sub": "a1000000-0000-0000-0000-000000000001"}';

select lives_ok(
  $$ select public.leave_group('a2000000-0000-0000-0000-000000000001') $$,
  'the last remaining member can leave the group'
);

reset role;

select is_empty(
  $$ select 1 from public.groups where id = 'a2000000-0000-0000-0000-000000000001' $$,
  'leave_group dissolves the group once active members drop to 0'
);

select is_empty(
  $$ select 1 from public.photos where group_id = 'a2000000-0000-0000-0000-000000000001'
     union all
     select 1 from public.group_members where group_id = 'a2000000-0000-0000-0000-000000000001' $$,
  'leave_group cascades and deletes the group''s photos and membership rows'
);

select is_empty(
  $$ select 1 from storage.objects
     where (bucket_id = 'photo-originals' and name = 'zero_member/original.jpg')
        or (bucket_id = 'photo-blurred' and name = 'zero_member/blurred.jpg') $$,
  'leave_group deletes the group''s storage objects on zero-member dissolve'
);

select * from finish();
rollback;
