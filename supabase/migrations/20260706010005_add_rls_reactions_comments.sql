-- reactions: photos経由でグループの現役メンバーのみ閲覧可能。
-- 追加・変更・削除は自分の行のみ許可(仕様書 8.1参照)
alter table public.reactions enable row level security;

create policy "reactions_select_active_member" on public.reactions
for select
using (
  exists (
    select 1 from public.photos p
    where p.id = reactions.photo_id
      and public.is_active_member(p.group_id, auth.uid())
  )
);

create policy "reactions_insert_own" on public.reactions
for insert
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.photos p
    where p.id = reactions.photo_id
      and public.is_active_member(p.group_id, auth.uid())
  )
);

create policy "reactions_update_own" on public.reactions
for update
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.photos p
    where p.id = reactions.photo_id
      and public.is_active_member(p.group_id, auth.uid())
  )
);

create policy "reactions_delete_own" on public.reactions
for delete
using (user_id = auth.uid());

-- comments: photos経由でグループの現役メンバーのみ閲覧可能。追加は自分の行のみ許可、編集・削除は不可(仕様書 8.1参照)
alter table public.comments enable row level security;

create policy "comments_select_active_member" on public.comments
for select
using (
  exists (
    select 1 from public.photos p
    where p.id = comments.photo_id
      and public.is_active_member(p.group_id, auth.uid())
  )
);

create policy "comments_insert_own" on public.comments
for insert
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.photos p
    where p.id = comments.photo_id
      and public.is_active_member(p.group_id, auth.uid())
  )
);

grant select on public.reactions to authenticated;
grant insert on public.reactions to authenticated;
grant update on public.reactions to authenticated;
grant delete on public.reactions to authenticated;

grant select on public.comments to authenticated;
grant insert on public.comments to authenticated;
