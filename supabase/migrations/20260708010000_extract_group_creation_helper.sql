-- create_group と create_event_group に重複していた「認証チェック→名前バリデーション→
-- groups挿入→group_members登録(作成者を必ずメンバーに登録する不変条件)」を
-- 内部ヘルパー関数 _create_group_and_register_creator に集約する(issue#131)。
-- create_group/create_event_group はモード固有のバリデーション(イベントの日付検証等)のみを行う
-- 薄いラッパーとし、以後グループ作成系RPCが増えても不変条件の登録漏れが起きないようにする。
-- クライアントから直接呼ばれないため public/authenticated への実行権限は付与しない。
create function public._create_group_and_register_creator(
  p_name text,
  p_mode text,
  p_start_date date default null,
  p_end_date date default null
)
returns public.groups
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group public.groups;
begin
  if auth.uid() is null then
    raise exception 'create group: authentication required';
  end if;

  -- btrim() は半角スペースしか除去しないため、タブ・改行・全角スペースのみの
  -- 名前が空文字判定をすり抜けないよう、空白文字全般を正規表現で判定する。
  if p_name is null or p_name ~ '^[\s　]*$' then
    raise exception 'create group: name must not be empty';
  end if;

  insert into public.groups (name, mode, start_date, end_date, created_by)
  values (btrim(p_name), p_mode, p_start_date, p_end_date, auth.uid())
  returning * into v_group;

  insert into public.group_members (group_id, user_id)
  values (v_group.id, auth.uid());

  return v_group;
end;
$$;

revoke execute on function public._create_group_and_register_creator(text, text, date, date) from public;

-- create_group: 固定グループ(mode=group)を作成するモード固有のラッパー(仕様書 3.2/6.2 create_group参照)。
-- 共通の不変条件(作成者のgroup_members登録等)は _create_group_and_register_creator に委譲する。
-- 既知の制限事項: 冪等性キーや (created_by, name) の一意制約は設けていないため、
-- クライアントの二重送信(タイムアウトによる再送・連打など)があった場合、
-- 同名グループが複数作成されうる。仕様書にも同名グループ禁止の定めがないため、
-- 現時点では対応せずクライアント側の二重送信防止に委ねる。
create or replace function public.create_group(p_name text)
returns public.groups
language plpgsql
security definer
set search_path = public
as $$
begin
  return public._create_group_and_register_creator(p_name, 'group');
end;
$$;

revoke execute on function public.create_group(text) from public;
grant execute on function public.create_group(text) to authenticated;

-- create_event_group: イベントグループ(mode=event)を開始日・終了日を指定して作成するモード固有のラッパー
-- (仕様書 3.11/6.2 create_event_group参照)。日付検証のみここで行い、
-- 共通の不変条件は _create_group_and_register_creator に委譲する。
create or replace function public.create_event_group(p_name text, p_start_date date, p_end_date date)
returns public.groups
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_start_date is null or p_end_date is null then
    raise exception 'create_event_group: start_date and end_date must not be null';
  end if;

  if p_end_date < p_start_date then
    raise exception 'create_event_group: end_date must not be before start_date';
  end if;

  return public._create_group_and_register_creator(p_name, 'event', p_start_date, p_end_date);
end;
$$;

revoke execute on function public.create_event_group(text, date, date) from public;
grant execute on function public.create_event_group(text, date, date) to authenticated;
