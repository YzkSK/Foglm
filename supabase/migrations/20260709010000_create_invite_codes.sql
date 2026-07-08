-- invite_codes: mode=group(固定グループ)の招待コード発行を表す(仕様書 5.1/6.2参照)。
-- 1グループにつき有効なコードは常に1件のみ(group_idにUNIQUE制約)。
-- 再発行は同じ行をUPDATEで置き換える(create_invite_code関数が担当)。
create table public.invite_codes (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null unique references public.groups (id) on delete cascade,
  code text not null unique,
  created_by uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now()
);

-- 閲覧は対象グループの現役メンバーのみ(招待画面S05での表示用)。
-- INSERT/UPDATEはcreate_invite_code関数(security definer)経由のみに限定し、直接の書き込みは許可しない。
alter table public.invite_codes enable row level security;

create policy "invite_codes_select_active_member" on public.invite_codes
for select
using (public.is_active_member(group_id, auth.uid()));

grant select on public.invite_codes to authenticated;
