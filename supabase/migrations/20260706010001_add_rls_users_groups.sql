-- users: 自分の行、または同じグループの現役メンバー同士のみ閲覧可能(仕様書 8.1参照)
alter table public.users enable row level security;

create policy "users_select_own_or_shared_active_group" on public.users
for select
using (
  id = auth.uid()
  or exists (
    select 1
    from public.group_members gm_self
    join public.group_members gm_other
      on gm_self.group_id = gm_other.group_id
    where gm_self.user_id = auth.uid()
      and gm_self.left_at is null
      and gm_other.user_id = public.users.id
      and gm_other.left_at is null
  )
);

create policy "users_update_own" on public.users
for update
using (id = auth.uid())
with check (id = auth.uid());

grant select on public.users to authenticated;
grant update on public.users to authenticated;
grant select on public.group_members to authenticated;

-- groups: 現役メンバーのみ閲覧可能。作成・更新・削除は作成者のみ(仕様書 8.1参照)
alter table public.groups enable row level security;

create policy "groups_select_active_member" on public.groups
for select
using (public.is_active_member(id, auth.uid()));

create policy "groups_insert_own" on public.groups
for insert
with check (created_by = auth.uid());

create policy "groups_update_owner" on public.groups
for update
using (created_by = auth.uid());

create policy "groups_delete_owner" on public.groups
for delete
using (created_by = auth.uid());

grant select on public.groups to authenticated;
grant insert on public.groups to authenticated;
grant update on public.groups to authenticated;
grant delete on public.groups to authenticated;
