-- restore_group_active_status trigger(#14): 新規参加・再参加によって固定グループの現役メンバーが
-- 2人以上に戻った際、groups.solo_since を NULL にリセットする(1週間経過判定への算入を止める)。
-- 対象はleft_atがNULLになる操作(新規参加・再参加)のみ。現役のままの無関係な更新はスキップする
-- (check_group_member_limitトリガーと同様の判定方式。仕様書 6.2 restore_group_active_status参照)。
create function public.restore_group_active_status()
returns trigger
language plpgsql
as $$
declare
  v_active_count integer;
begin
  if new.left_at is not null then
    return new;
  end if;

  if TG_OP = 'UPDATE' and old.left_at is null then
    return new;
  end if;

  select count(*) into v_active_count
  from public.group_members
  where group_id = new.group_id
    and left_at is null;

  if v_active_count >= 2 then
    update public.groups
    set solo_since = null
    where id = new.group_id
      and mode = 'group'
      and solo_since is not null;
  end if;

  return new;
end;
$$;

create trigger trg_restore_group_active_status
  after insert or update on public.group_members
  for each row
  execute function public.restore_group_active_status();
