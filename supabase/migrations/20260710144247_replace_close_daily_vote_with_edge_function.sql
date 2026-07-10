-- close_daily_vote(#175): plpgsql関数+pg_cron直接呼び出しをやめ、Deno/TypeScript製の
-- close-daily-vote Edge Functionへロジックを移植し、pg_cronからnet.http_post経由で
-- 起動する構成に置き換える(仕様書6.4/6.7参照)。
--
-- 事前準備(このmigration適用前にVaultへ以下2つのsecretを登録しておくこと。未登録でも
-- migration自体は成功するが、cronジョブの実行時にnet.http_postが失敗する):
--   - 'project_url'      : このSupabaseプロジェクトのAPI URL (例: ローカルなら supabase status の API_URL)
--   - 'service_role_key' : このSupabaseプロジェクトのservice_role key
-- 登録例(SQL editorまたはpsqlで実行):
--   select vault.create_secret('http://127.0.0.1:54321', 'project_url');
--   select vault.create_secret('<service_role_key>', 'service_role_key');
create extension if not exists pg_net with schema extensions;

do $$
begin
  perform cron.unschedule('close_daily_vote_daily');
exception
  when others then
    null;
end;
$$;

drop function if exists public.close_daily_vote();

select cron.schedule(
  'close_daily_vote_daily',
  '0 15 * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
      || '/functions/v1/close-daily-vote',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' ||
        (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key')
    ),
    body := '{}'::jsonb
  ) as request_id;
  $$
);
