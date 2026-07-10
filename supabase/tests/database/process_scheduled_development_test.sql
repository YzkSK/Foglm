-- process_scheduled_development_hourly cron(issue #176): Edge Function化後もpg_cronが
-- net.http_post経由でprocess-scheduled-development Edge Functionを毎時0分に起動することを確認する。
begin;
select plan(1);

select isnt_empty(
  $$
  select 1 from cron.job
  where jobname = 'process_scheduled_development_hourly'
    and schedule = '0 * * * *'
    and command like '%net.http_post%'
    and command like '%process-scheduled-development%'
  $$,
  'process_scheduled_development_hourly is registered as an hourly pg_cron job invoking the process-scheduled-development Edge Function via net.http_post'
);

select * from finish();
rollback;
