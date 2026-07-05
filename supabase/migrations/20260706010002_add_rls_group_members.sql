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
