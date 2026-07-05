-- daily_votes: グループ・日付ごとの投票を管理する。
-- 行は自動作成されず、その日・そのグループで最初の写真が撮影されたタイミング(upload_photo)で status=open として作成される(仕様書 5.1参照)。
create table public.daily_votes (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  vote_date date not null,
  status text not null default 'open'
    check (status in ('open', 'closed')),
  winner_photo_id uuid references public.photos (id) on delete set null,
  closed_at timestamptz,
  unique (group_id, vote_date)
);
