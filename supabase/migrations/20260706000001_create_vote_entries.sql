-- vote_entries: ユーザーの投票を管理する。再投票時は UPSERT で上書きし、最後の一票のみ有効とする(仕様書 5.1参照)。
create table public.vote_entries (
  id uuid primary key default gen_random_uuid(),
  daily_vote_id uuid not null references public.daily_votes (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  photo_id uuid not null references public.photos (id) on delete cascade,
  voted_at timestamptz not null default now(),
  unique (daily_vote_id, user_id)
);
