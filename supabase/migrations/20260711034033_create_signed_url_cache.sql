-- signed_url_cache: get-photo-url Edge Functionが発行した署名付きURLを(bucket, path)単位で
-- キャッシュする(issue #167)。createSignedUrlは呼び出しごとにトークンが変わり、同一写真でも
-- URLが毎回変わるためCDNキャッシュのヒット率が上がらない問題への対応。
-- クライアント(anon/authenticated)からの直接アクセスは想定しないため、RLSは有効にした上で
-- ポリシーを追加しない(service_roleはRLSをバイパスするため、get-photo-url経由のみ読み書き可能)。
create table public.signed_url_cache (
  bucket text not null,
  path text not null,
  signed_url text not null,
  expires_at timestamptz not null,
  updated_at timestamptz not null default now(),
  primary key (bucket, path)
);

alter table public.signed_url_cache enable row level security;

grant select, insert, update, delete on public.signed_url_cache to service_role;
