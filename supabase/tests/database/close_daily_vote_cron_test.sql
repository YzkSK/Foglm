-- close_daily_vote_daily cron(issue #175): Edge Function化後もpg_cronがnet.http_post経由で
-- close-daily-vote Edge Functionを毎日UTC15:00(日本時間24:00)に起動することを確認する。
begin;
select plan(1);

select isnt_empty(
  $$
  select 1 from cron.job
  where jobname = 'close_daily_vote_daily'
    and schedule = '0 15 * * *'
    and command like '%net.http_post%'
    and command like '%close-daily-vote%'
  $$,
  'close_daily_vote_daily is registered as a daily pg_cron job at UTC 15:00 (JST 24:00) invoking the close-daily-vote Edge Function via net.http_post'
);

select * from finish();
rollback;
