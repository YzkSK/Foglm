-- close-daily-vote(#184 review): pg_cronのhttp_postヘッダーに X-Cron-Secret を追加し、
-- Edge Function側の認可チェックと対応する(セキュリティレビュー指摘対応)。
--
-- 事前準備(このmigration適用前にVaultへ以下secretを追加登録しておくこと):
--   - 'cron_secret' : pg_cronとEdge Function間で共有する任意のランダム文字列
--                     例: select vault.create_secret(gen_random_uuid()::text, 'cron_secret');
-- 'project_url' / 'service_role_key' は既存のmigrationで登録済みであること。

-- 既存ジョブをいったん削除して再登録する(ヘッダー追加のため)。
-- pg_cronのunscheduleは対象がなければ例外を送出するため、when othersで握り潰す。
do $$
begin
  perform cron.unschedule('close_daily_vote_daily');
exception
  when others then
    null;
end;
$$;

select cron.schedule(
  'close_daily_vote_daily',
  '0 15 * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
      || '/functions/v1/close-daily-vote',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-Cron-Secret',
        (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
    ),
    body := '{}'::jsonb
  ) as request_id;
  $$
);
