-- vote_entries: daily_votes経由でグループの現役メンバーのみ閲覧可能。
-- 投票(INSERT)・再投票(UPDATE)は自分の行のみ許可(仕様書 8.1参照)
alter table public.vote_entries enable row level security;

create policy "vote_entries_select_active_member" on public.vote_entries
for select
using (
  exists (
    select 1 from public.daily_votes dv
    where dv.id = vote_entries.daily_vote_id
      and public.is_active_member(dv.group_id, auth.uid())
  )
);

create policy "vote_entries_insert_own" on public.vote_entries
for insert
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.daily_votes dv
    where dv.id = vote_entries.daily_vote_id
      and public.is_active_member(dv.group_id, auth.uid())
  )
);

create policy "vote_entries_update_own" on public.vote_entries
for update
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.daily_votes dv
    where dv.id = vote_entries.daily_vote_id
      and public.is_active_member(dv.group_id, auth.uid())
  )
);

grant select on public.vote_entries to authenticated;
grant insert on public.vote_entries to authenticated;
grant update on public.vote_entries to authenticated;
