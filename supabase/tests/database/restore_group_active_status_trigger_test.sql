-- restore_group_active_status trigger: 現役メンバーが2人以上に戻った際にgroups.solo_sinceをNULLへリセットする(issue #14 / 仕様書6.2参照)。
begin;
select plan(4);

insert into auth.users (id) values
  ('c0000000-0000-0000-0000-000000000001'), -- 固定グループ: 残る現役メンバー
  ('c0000000-0000-0000-0000-000000000002'), -- 固定グループ: 新規招待で参加するメンバー
  ('c0000000-0000-0000-0000-000000000003'); -- 固定グループ: 脱退後に再参加するメンバー

insert into public.users (id, auth_provider, display_name)
values
  ('c0000000-0000-0000-0000-000000000001', 'email', 'Restore Member 1'),
  ('c0000000-0000-0000-0000-000000000002', 'email', 'Restore Member 2'),
  ('c0000000-0000-0000-0000-000000000003', 'email', 'Restore Member 3');

-- Case 1: 新規参加(INSERT)によって2人以上に戻るとsolo_sinceがリセットされる
insert into public.groups (id, name, mode, created_by, solo_since)
values ('d0000000-0000-0000-0000-000000000001', 'Restore Group New Join', 'group', 'c0000000-0000-0000-0000-000000000001', now() - interval '2 days');

insert into public.group_members (group_id, user_id)
values ('d0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001');

insert into public.group_members (group_id, user_id)
values ('d0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002');

select is(
  (select solo_since from public.groups where id = 'd0000000-0000-0000-0000-000000000001'),
  null,
  'new member joining brings active members to 2 and resets solo_since to null'
);

-- Case 2: 脱退済みメンバーの再参加(UPDATE left_at -> NULL)によって2人以上に戻るとsolo_sinceがリセットされる
insert into public.groups (id, name, mode, created_by, solo_since)
values ('d0000000-0000-0000-0000-000000000002', 'Restore Group Rejoin', 'group', 'c0000000-0000-0000-0000-000000000001', now() - interval '3 days');

insert into public.group_members (group_id, user_id)
values ('d0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001');

insert into public.group_members (group_id, user_id, left_at)
values ('d0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000003', now() - interval '1 day');

update public.group_members
set left_at = null, joined_at = now()
where group_id = 'd0000000-0000-0000-0000-000000000002' and user_id = 'c0000000-0000-0000-0000-000000000003';

select is(
  (select solo_since from public.groups where id = 'd0000000-0000-0000-0000-000000000002'),
  null,
  'rejoining member (left_at reset to null) brings active members to 2 and resets solo_since to null'
);

-- Case 3: まだ1人のまま(参加によって2人以上にならない)場合はsolo_sinceを変更しない
-- (このグループはsolo_sinceが未設定の新規グループなので、そもそもNULLのままであることを確認する)
insert into public.groups (id, name, mode, created_by)
values ('d0000000-0000-0000-0000-000000000003', 'Restore Group Still Alone', 'group', 'c0000000-0000-0000-0000-000000000001');

insert into public.group_members (group_id, user_id)
values ('d0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000001');

select is(
  (select solo_since from public.groups where id = 'd0000000-0000-0000-0000-000000000003'),
  null,
  'group with only one active member keeps solo_since null (no false reset needed)'
);

-- Case 4: 現役メンバーが1人のまま(2人に戻らない)無関係な更新(left_atはNULLのまま)では、
-- solo_sinceを勝手にNULLへリセットしない
insert into public.groups (id, name, mode, created_by, solo_since)
values ('d0000000-0000-0000-0000-000000000004', 'Restore Group Unrelated Update', 'group', 'c0000000-0000-0000-0000-000000000001', now() - interval '4 days');

insert into public.group_members (group_id, user_id)
values ('d0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001');

update public.group_members
set joined_at = now()
where group_id = 'd0000000-0000-0000-0000-000000000004' and user_id = 'c0000000-0000-0000-0000-000000000001';

select isnt(
  (select solo_since from public.groups where id = 'd0000000-0000-0000-0000-000000000004'),
  null,
  'unrelated update on the sole active member (still 1 active member) does not clear the pre-set solo_since'
);

select * from finish();
rollback;
