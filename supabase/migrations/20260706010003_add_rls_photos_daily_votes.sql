-- photos: 現役メンバーのみ閲覧可能。書き込みはEdge Function(service_role)経由のみのためポリシーなし(仕様書 8.1参照)
alter table public.photos enable row level security;

create policy "photos_select_active_member" on public.photos
for select
using (public.is_active_member(group_id, auth.uid()));

grant select on public.photos to authenticated;

-- daily_votes: 現役メンバーのみ閲覧可能。書き込みはEdge Function/cron経由のみのためポリシーなし
alter table public.daily_votes enable row level security;

create policy "daily_votes_select_active_member" on public.daily_votes
for select
using (public.is_active_member(group_id, auth.uid()));

grant select on public.daily_votes to authenticated;
