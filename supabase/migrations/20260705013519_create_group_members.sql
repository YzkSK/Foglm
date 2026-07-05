-- group_members: 脱退は物理削除せず left_at を設定する(履歴として残す)。
-- 再参加は新規行ではなく既存行の left_at を NULL に戻す UPDATE で行う(仕様書 5.1参照)。
create table public.group_members (
  group_id uuid not null references public.groups (id),
  user_id uuid not null references public.users (id),
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
