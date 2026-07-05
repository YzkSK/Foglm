-- group_members: 脱退は物理削除せず left_at を設定する(履歴として残す)。
-- 再参加は新規行ではなく既存行の left_at を NULL に戻す UPDATE で行う(仕様書 5.1参照)。
create table public.group_members (
  group_id uuid not null references public.groups (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  primary key (group_id, user_id)
);

-- 現役メンバー(left_at IS NULL)が6人を超える新規参加・再参加を拒否する。
-- アプリ側の事前チェックは早期エラー表示用の補助であり、最終的な制約はここで担保する。
create function public.check_group_member_limit()
returns trigger
language plpgsql
as $$
declare
  active_count integer;
begin
  if new.left_at is not null then
    return new;
  end if;

  -- left_atがNULL→NULLのまま(参加・脱退・再参加を伴わない更新)であれば
  -- ロック取得・カウントは不要なのでスキップする。
  if TG_OP = 'UPDATE' and old.left_at is null then
    return new;
  end if;

  -- group_id単位でアドバイザリロックを取得し、同時参加リクエストによる
  -- カウント→判定のすり抜け(上限超過)を防ぐ(仕様書 5.2.2の排他制御方式と同様)。
  perform pg_advisory_xact_lock(hashtextextended(new.group_id::text, 0));

  select count(*) into active_count
  from public.group_members
  where group_id = new.group_id
    and left_at is null
    and user_id <> new.user_id;

  if active_count >= 6 then
    raise exception 'group_members: group % already has % active members (max 6)', new.group_id, active_count;
  end if;

  return new;
end;
$$;

create trigger trg_check_group_member_limit
  before insert or update on public.group_members
  for each row
  execute function public.check_group_member_limit();
