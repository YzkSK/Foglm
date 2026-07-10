begin;
select plan(18);

-- =====================================================================
-- Fixtures
-- =====================================================================
insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000051'), -- fixed group: active member who leaves
  ('00000000-0000-0000-0000-000000000052'), -- fixed group: other active member
  ('00000000-0000-0000-0000-000000000053'), -- event group: active member who leaves
  ('00000000-0000-0000-0000-000000000054'), -- fixed group: already left member
  ('00000000-0000-0000-0000-000000000055'), -- solo group owner
  ('00000000-0000-0000-0000-000000000061'), -- fixed group with multiple members: creator who leaves
  ('00000000-0000-0000-0000-000000000062'), -- fixed group with multiple members: remaining member
  ('00000000-0000-0000-0000-000000000063'), -- fixed group with multiple members: remaining member
  ('00000000-0000-0000-0000-000000000064'), -- fixed group: sole member/creator who leaves
  ('00000000-0000-0000-0000-000000000065'), -- event group: creator who leaves
  ('00000000-0000-0000-0000-000000000066'); -- event group: remaining member

insert into public.users (id, auth_provider, display_name)
values
  ('00000000-0000-0000-0000-000000000051', 'email', 'Leave Group Member 1'),
  ('00000000-0000-0000-0000-000000000052', 'email', 'Leave Group Member 2'),
  ('00000000-0000-0000-0000-000000000053', 'email', 'Leave Event Group Member'),
  ('00000000-0000-0000-0000-000000000054', 'email', 'Leave Group Already Left'),
  ('00000000-0000-0000-0000-000000000055', 'email', 'Leave Group Solo Owner'),
  ('00000000-0000-0000-0000-000000000061', 'email', 'Delegation Creator'),
  ('00000000-0000-0000-0000-000000000062', 'email', 'Delegation Member 2'),
  ('00000000-0000-0000-0000-000000000063', 'email', 'Delegation Member 3'),
  ('00000000-0000-0000-0000-000000000064', 'email', 'Delegation Sole Creator'),
  ('00000000-0000-0000-0000-000000000065', 'email', 'Delegation Event Creator'),
  ('00000000-0000-0000-0000-000000000066', 'email', 'Delegation Event Member');

insert into public.groups (id, name, mode, created_by)
values
  ('31000000-0000-0000-0000-000000000001', 'Leave Group Fixed', 'group', '00000000-0000-0000-0000-000000000051'),
  ('31000000-0000-0000-0000-000000000003', 'Leave Group Solo', 'solo', '00000000-0000-0000-0000-000000000055'),
  ('32000000-0000-0000-0000-000000000001', 'Leave Group Creator Delegation', 'group', '00000000-0000-0000-0000-000000000061'),
  ('32000000-0000-0000-0000-000000000002', 'Leave Group Creator Alone', 'group', '00000000-0000-0000-0000-000000000064');

insert into public.groups (id, name, mode, created_by, start_date, end_date)
values
  ('31000000-0000-0000-0000-000000000002', 'Leave Group Event', 'event', '00000000-0000-0000-0000-000000000053', current_date, current_date + 7),
  ('32000000-0000-0000-0000-000000000003', 'Leave Event Group Creator Delegation', 'event', '00000000-0000-0000-0000-000000000065', current_date, current_date + 7);

insert into public.group_members (group_id, user_id, left_at)
values
  ('31000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000051', null),
  ('31000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000052', null),
  ('31000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000054', now() - interval '1 day'),
  ('31000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000053', null),
  ('31000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000055', null),
  ('32000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000061', null),
  ('32000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000062', null),
  ('32000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000063', null),
  ('32000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000064', null),
  ('32000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000065', null),
  ('32000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000066', null);

-- =====================================================================
-- 1. 固定グループ(mode=group)から現役メンバーが脱退できる
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000051"}';

select lives_ok(
  $$ select public.leave_group('31000000-0000-0000-0000-000000000001') $$,
  'an active member can leave a fixed group'
);

reset role;

-- 脱退後は自分の行もRLS(is_active_member)で見えなくなるため、
-- postgres(RLSバイパス)でleft_atが設定されたことを確認する。
select isnt_empty(
  $$ select 1 from public.group_members
     where group_id = '31000000-0000-0000-0000-000000000001'
       and user_id = '00000000-0000-0000-0000-000000000051'
       and left_at is not null $$,
  'leave_group sets left_at for the caller'
);

-- postgres(RLSバイパス)で脱退後の閲覧不可を確認するため写真を用意
insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
values
  ('31000000-0000-0000-0000-000000000101', '31000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000052',
   now(), current_date, 'leave_group/original.jpg', 'leave_group/blurred.jpg');

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000051"}';

select is_empty(
  $$ select 1 from public.photos where id = '31000000-0000-0000-0000-000000000101' $$,
  'a member can no longer see photos after leaving the group'
);

-- =====================================================================
-- 2. 既に脱退済みのメンバーが再度呼び出すとエラーになる
-- =====================================================================
select throws_ok(
  $$ select public.leave_group('31000000-0000-0000-0000-000000000001') $$,
  null,
  null,
  'leave_group rejects a caller who already left'
);

reset role;

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000054"}';

select throws_ok(
  $$ select public.leave_group('31000000-0000-0000-0000-000000000001') $$,
  null,
  null,
  'leave_group rejects a previously-left member who is not currently active'
);

reset role;

-- =====================================================================
-- 3. イベントグループ(mode=event)からも脱退できる
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000053"}';

select lives_ok(
  $$ select public.leave_group('31000000-0000-0000-0000-000000000002') $$,
  'an active member can leave an event group'
);

reset role;

select isnt_empty(
  $$ select 1 from public.group_members
     where group_id = '31000000-0000-0000-0000-000000000002'
       and user_id = '00000000-0000-0000-0000-000000000053'
       and left_at is not null $$,
  'leave_group sets left_at for the caller in an event group'
);

reset role;

-- =====================================================================
-- 4. ソロモード(mode=solo)は脱退できない
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000055"}';

select throws_ok(
  $$ select public.leave_group('31000000-0000-0000-0000-000000000003') $$,
  null,
  null,
  'leave_group rejects leaving a solo group'
);

reset role;

-- =====================================================================
-- 5. メンバーでないユーザーやグループが存在しない場合は拒否される
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000052"}';

select throws_ok(
  $$ select public.leave_group('99999999-0000-0000-0000-000000000000') $$,
  null,
  null,
  'leave_group rejects a non-existent group'
);

select throws_ok(
  $$ select public.leave_group(null) $$,
  null,
  null,
  'leave_group rejects a null group_id'
);

reset role;

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000052"}';

select throws_ok(
  $$ select public.leave_group('31000000-0000-0000-0000-000000000002') $$,
  null,
  null,
  'leave_group rejects a user who is not a member of the group at all'
);

reset role;

-- =====================================================================
-- 6. anonロールは実行できない
-- =====================================================================
set local role anon;

select throws_ok(
  $$ select public.leave_group('31000000-0000-0000-0000-000000000002') $$,
  null,
  null,
  'anon role cannot execute leave_group function'
);

reset role;

-- =====================================================================
-- 7. 作成者権限の自動委譲(#15)
-- =====================================================================

-- 固定グループで作成者が脱退すると、残っている現役メンバーへcreated_byが委譲される
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000061"}';

select lives_ok(
  $$ select public.leave_group('32000000-0000-0000-0000-000000000001') $$,
  'the creator can leave a fixed group with other active members'
);

reset role;

select ok(
  (select created_by from public.groups where id = '32000000-0000-0000-0000-000000000001')
    in ('00000000-0000-0000-0000-000000000062', '00000000-0000-0000-0000-000000000063'),
  'leave_group delegates created_by to a remaining active member'
);

-- 固定グループで作成者が唯一のメンバーとして脱退した場合(残り0人)は委譲せず、
-- 即座に解散(グループ行ごと完全削除)される(#16)
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000064"}';

select lives_ok(
  $$ select public.leave_group('32000000-0000-0000-0000-000000000002') $$,
  'the sole creator can leave a fixed group'
);

reset role;

select is_empty(
  $$ select 1 from public.groups where id = '32000000-0000-0000-0000-000000000002' $$,
  'leave_group dissolves the group immediately once no active members remain'
);

-- イベントグループには解散機能がないため、作成者脱退時も委譲しない
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-000000000065"}';

select lives_ok(
  $$ select public.leave_group('32000000-0000-0000-0000-000000000003') $$,
  'the creator can leave an event group with other active members'
);

reset role;

select is(
  (select created_by from public.groups where id = '32000000-0000-0000-0000-000000000003'),
  '00000000-0000-0000-0000-000000000065'::uuid,
  'leave_group does not delegate created_by for an event group'
);

select * from finish();
rollback;
