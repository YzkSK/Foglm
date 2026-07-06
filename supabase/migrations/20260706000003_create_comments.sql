-- comments: 写真へのコメントを管理する。mode=group/eventの写真にのみ使用する(仕様書 5.1参照)。
-- リアクションと異なり、1人が複数件投稿できる。
create table public.comments (
  id uuid primary key default gen_random_uuid(),
  photo_id uuid not null references public.photos (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);
