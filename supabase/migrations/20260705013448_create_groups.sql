-- groups: 固定グループ(group) / ソロモード(solo) / イベントグループ(event) を1テーブルで表現する
create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  mode text not null check (mode in ('group', 'solo', 'event')),
  start_date date,
  end_date date,
  status text not null default 'active' check (status in ('active', 'archived')),
  -- 脱退により現役メンバーが1人になった時刻。作成時はNULL(仕様書 5.1参照)
  solo_since timestamptz,
  created_by uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now()
);
