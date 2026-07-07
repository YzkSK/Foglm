-- create_group: 固定グループ(mode=group)を作成し、作成者をgroup_membersに登録するRPC(仕様書 3.2/6.2 create_group参照)。
-- groups の SELECT ポリシー(groups_select_active_member)は group_members に現役メンバー行が
-- 存在することを要求するため、groups への INSERT 直後(まだ group_members 登録前)は
-- RETURNING句の可視性チェックでRLS違反になってしまう。そのため security definer とし、
-- created_by/user_id は常に呼び出し元の auth.uid() に固定して安全性を担保する(仕様書 8.1参照)。
-- 既知の制限事項: 冪等性キーや (created_by, name) の一意制約は設けていないため、
-- クライアントの二重送信(タイムアウトによる再送・連打など)があった場合、
-- 同名グループが複数作成されうる。仕様書にも同名グループ禁止の定めがないため、
-- 現時点では対応せずクライアント側の二重送信防止に委ねる。
create function public.create_group(p_name text)
returns public.groups
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group public.groups;
begin
  if auth.uid() is null then
    raise exception 'create_group: authentication required';
  end if;

  -- btrim() は半角スペースしか除去しないため、タブ・改行・全角スペースのみの
  -- 名前が空文字判定をすり抜けないよう、空白文字全般を正規表現で判定する。
  if p_name is null or p_name ~ '^[\s　]*$' then
    raise exception 'create_group: name must not be empty';
  end if;

  insert into public.groups (name, mode, created_by)
  values (btrim(p_name), 'group', auth.uid())
  returning * into v_group;

  insert into public.group_members (group_id, user_id)
  values (v_group.id, auth.uid());

  return v_group;
end;
$$;

revoke execute on function public.create_group(text) from public;
grant execute on function public.create_group(text) to authenticated;
