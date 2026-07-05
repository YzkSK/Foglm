-- users: Supabase Auth の user id と一致させる (id は auth.users.id への参照)
create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  auth_provider text not null check (auth_provider in ('google', 'apple', 'x', 'instagram', 'email')),
  email text,
  email_verified boolean not null default false,
  display_name text not null,
  avatar_url text,
  fcm_token text,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);
