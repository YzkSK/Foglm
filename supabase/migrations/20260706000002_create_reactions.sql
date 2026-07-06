-- reactions: 写真へのリアクションを管理する。mode=group/eventの写真にのみ使用する(仕様書 5.1参照)。
create table public.reactions (
  id uuid primary key default gen_random_uuid(),
  photo_id uuid not null references public.photos (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  -- 1人1枚につき1リアクションまで。再選択時は UPSERT で上書き(仕様書 5.1参照)
  unique (photo_id, user_id)
);
