-- group_members: 現役メンバーのみ閲覧可能。参加は自分自身、または既存の現役メンバーによる招待を許可。
-- 更新(脱退・再参加)は自分の行のみ(仕様書 8.1参照)
alter table public.group_members enable row level security;

create policy "group_members_select_active_member" on public.group_members
for select
using (public.is_active_member(group_id, auth.uid()));

create policy "group_members_insert_self_or_inviter" on public.group_members
for insert
with check (
  user_id = auth.uid()
  or public.is_active_member(group_id, auth.uid())
);

create policy "group_members_update_own" on public.group_members
for update
using (user_id = auth.uid());

grant insert on public.group_members to authenticated;
grant update on public.group_members to authenticated;

-- Prevent group_id from being changed on update. Group membership is immutable;
-- users can only update left_at to leave/rejoin, not move rows to other groups.
create function public.prevent_group_members_group_id_change()
returns trigger
language plpgsql
as $$
begin
  if new.group_id <> old.group_id then
    raise exception 'group_members: group_id cannot be changed on update';
  end if;
  return new;
end;
$$;

create trigger trg_prevent_group_members_group_id_change
  before update on public.group_members
  for each row
  execute function public.prevent_group_members_group_id_change();
