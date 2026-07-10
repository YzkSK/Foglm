-- delete_account_data: アカウント削除(delete_account Edge Function)の本体処理(#104)。
-- 1. 所属中の固定・イベントグループ(mode='group'/'event', left_at is null)それぞれに対して
--    leave_group と同一の脱退処理を一括実行する(作成者権限の委譲・猶予期間・0人時解散も連動)。
-- 2. ソロモードのグループ(mode='solo', created_by=本人)は dissolve_group_data を再利用し、
--    写真Storage・グループ行を完全削除する(ソフト削除の対象外。仕様書 3.1.3/6.1参照)。
-- 3. public.users を匿名化する(deleted_at設定、表示名・アイコン・メール・fcm_tokenをクリア)。
-- 4. Supabase Auth側の認証情報を解放する: auth.identities の本人分を削除し、
--    auth.users.email を再利用不可な値へ書き換えることで、削除前のメールアドレス・SNS
--    アカウントを新規サインアップ用に解放する(仕様書 3.1.3/6.1、PR#150参照)。
create function public.delete_account_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_group_id uuid;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'delete_account_data: authentication required';
  end if;

  -- 1. 固定グループ・イベントグループはleave_groupと同一処理を一括実行
  for v_group_id in
    select gm.group_id
    from public.group_members gm
    join public.groups g on g.id = gm.group_id
    where gm.user_id = v_user_id
      and gm.left_at is null
      and g.mode in ('group', 'event')
  loop
    perform public.leave_group(v_group_id);
  end loop;

  -- 2. ソロモードのグループ・写真は完全削除
  for v_group_id in
    select id from public.groups
    where mode = 'solo' and created_by = v_user_id
  loop
    perform public.dissolve_group_data(v_group_id);
  end loop;

  -- 3. public.usersを匿名化(ソフト削除)
  update public.users
  set deleted_at = now(),
      display_name = '退会したユーザー',
      avatar_url = null,
      email = null,
      fcm_token = null
  where id = v_user_id;

  -- 4. Supabase Auth側の認証情報を解放し、同じメールアドレス・SNSアカウントでの
  -- 新規サインアップ(別IDの新規アカウントとして)を可能にする
  delete from auth.identities where user_id = v_user_id;

  update auth.users
  set email = v_user_id::text || '@deleted.invalid'
  where id = v_user_id;
end;
$$;

revoke execute on function public.delete_account_data() from public;
grant execute on function public.delete_account_data() to authenticated;
