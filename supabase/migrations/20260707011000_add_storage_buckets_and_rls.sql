-- Storageバケット作成(仕様書 8.1参照)
-- 原本: クライアントに一切配信しない。Edge Function(service_role)経由のみでアクセス可能なため、
--       authenticatedロール向けのポリシーは作成しない(RLSにより暗黙的にアクセス拒否)
-- ボヤけ版: グループの現役メンバーのみ署名付きURL経由で閲覧可能
insert into storage.buckets (id, name, public)
values
  ('photo-originals', 'photo-originals', false),
  ('photo-blurred', 'photo-blurred', false)
on conflict (id) do nothing;

create policy "photo_blurred_select_active_member" on storage.objects
for select
to authenticated
using (
  bucket_id = 'photo-blurred'
  and exists (
    select 1 from public.photos
    where photos.blurred_storage_path = storage.objects.name
      and public.is_active_member(photos.group_id, auth.uid())
  )
);
