-- process_scheduled_development(#176): plpgsql関数+pg_cron直接呼び出しをやめ、
-- Deno/TypeScript製のprocess-scheduled-development Edge Functionへロジックを移植し、
-- pg_cronからnet.http_post経由で起動する構成に置き換える(仕様書6.5/6.7参照)。
--
-- 事前準備: Vaultの'project_url'/'service_role_key'secretはclose_daily_voteの
-- Edge Function化(#175)時に登録済みの前提であり、本migrationでは再登録しない。
-- 未登録の環境ではcronジョブの実行時にnet.http_postが失敗する。

-- pg_cronのunschedule(job_name)は対象ジョブが存在しない場合に例外を送出し、
-- "not found"専用の型付き例外を提供していない。migration再適用時にもエラーで
-- 止まらないよう、意図的にwhen othersで例外を握り潰す(直後のcron.scheduleで
-- ジョブは必ず再登録されるため、ここで失敗してもジョブ状態は自己修復する)。
do $$
begin
  perform cron.unschedule('process_scheduled_development_hourly');
exception
  when others then
    null;
end;
$$;

drop function if exists public.process_scheduled_development();

select cron.schedule(
  'process_scheduled_development_hourly',
  '0 * * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
      || '/functions/v1/process-scheduled-development',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' ||
        (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key')
    ),
    body := '{}'::jsonb
  ) as request_id;
  $$
);
