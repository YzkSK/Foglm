-- photos: 撮影された写真を管理する(仕様書 5.1参照)
create table public.photos (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  taken_by uuid references public.users (id) on delete set null,
  taken_at timestamptz not null,
  -- taken_at を日本時間(Asia/Tokyo)に変換した日付部分。フィルム上限・投票対象の判定に使用(仕様書 5.2.1参照)
  taken_date date not null,
  original_storage_path text not null,
  blurred_storage_path text not null,
  status text not null default 'pending_vote'
    check (status in ('pending_vote', 'selected_today', 'waiting_random', 'developed')),
  develop_scheduled_at timestamptz,
  developed_at timestamptz
);

-- フィルム上限(group_id × taken_dateの件数)判定・排他制御での参照に使用(仕様書 5.2.2参照)
create index idx_photos_group_id_taken_date on public.photos (group_id, taken_date);
