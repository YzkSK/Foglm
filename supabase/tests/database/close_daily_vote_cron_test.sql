-- close_daily_vote (cron): 投票締め切りロジックはEdge Function(#175)に移行済み。
-- ここではcronジョブがnet.http_post経由でclose-daily-vote Edge Functionを
-- 呼び出すよう登録されているかのみを確認する。
begin;
select plan(1);

-- Cron registration
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
