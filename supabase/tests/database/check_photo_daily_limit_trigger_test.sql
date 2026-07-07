begin;
select plan(17);

-- Fixtures: group mode(上限10枚)・soloモード(上限3枚)・タイムゾーン検証用の3グループ。
insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000071');

insert into public.users (id, auth_provider, display_name)
values ('00000000-0000-0000-0000-000000000071', 'email', 'Test User 71');

insert into public.groups (id, name, mode, created_by)
values
  ('10000000-0000-0000-0000-000000000011', 'Group Mode Test', 'group', '00000000-0000-0000-0000-000000000071'),
  ('10000000-0000-0000-0000-000000000012', 'Solo Mode Test', 'solo', '00000000-0000-0000-0000-000000000071'),
  ('10000000-0000-0000-0000-000000000013', 'Timezone Test', 'group', '00000000-0000-0000-0000-000000000071');

-- groupモード: 1枚目〜10枚目は成功する(上限10枚)。
select lives_ok(
  format(
    $$ insert into public.photos (group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
       values ('10000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000071', '2026-07-07 10:00:00+09', '2000-01-01', 'o/%s.jpg', 'b/%s.jpg') $$,
    n, n
  )
) from generate_series(1, 10) as n;

-- groupモード: 11枚目は上限超過で拒否される。
select throws_ok(
  $$ insert into public.photos (group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
     values ('10000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000071', '2026-07-07 10:00:00+09', '2000-01-01', 'o/11.jpg', 'b/11.jpg') $$,
  'P0001',
  'photos: group 10000000-0000-0000-0000-000000000011 already has 10 photos on 2026-07-07 (max 10)',
  '11枚目は上限超過で拒否される'
);

-- 別の日(taken_date)であれば上限のカウント対象外となり成功する。
select lives_ok(
  $$ insert into public.photos (group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
     values ('10000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000071', '2026-07-08 10:00:00+09', '2000-01-01', 'o/next-day.jpg', 'b/next-day.jpg') $$,
  '別の日の撮影は当日の上限カウントに影響しない'
);

-- soloモード: 1〜3枚目は成功する(上限3枚)。
select lives_ok(
  format(
    $$ insert into public.photos (group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
       values ('10000000-0000-0000-0000-000000000012', '00000000-0000-0000-0000-000000000071', '2026-07-07 10:00:00+09', '2000-01-01', 'so/%s.jpg', 'sb/%s.jpg') $$,
    n, n
  )
) from generate_series(1, 3) as n;

-- soloモード: 4枚目は上限超過で拒否される。
select throws_ok(
  $$ insert into public.photos (group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
     values ('10000000-0000-0000-0000-000000000012', '00000000-0000-0000-0000-000000000071', '2026-07-07 10:00:00+09', '2000-01-01', 'so/4.jpg', 'sb/4.jpg') $$,
  'P0001',
  'photos: group 10000000-0000-0000-0000-000000000012 already has 3 photos on 2026-07-07 (max 3)',
  'soloモードは4枚目で拒否される'
);

-- taken_dateはtaken_at(UTC)を日本時間に変換した日付で自動算出される(渡した値は無視される)。
-- UTC 2026-07-06T15:30:00 は JST 2026-07-07T00:30:00 のため taken_date は 2026-07-07 になる。
insert into public.photos (id, group_id, taken_by, taken_at, taken_date, original_storage_path, blurred_storage_path)
values (
  '20000000-0000-0000-0000-000000000099',
  '10000000-0000-0000-0000-000000000013',
  '00000000-0000-0000-0000-000000000071',
  '2026-07-06 15:30:00+00',
  '1999-01-01',
  'o/tz-check.jpg',
  'b/tz-check.jpg'
);

select is(
  (select taken_date from public.photos where id = '20000000-0000-0000-0000-000000000099'),
  '2026-07-07'::date,
  'taken_dateはtaken_atをAsia/Tokyoに変換した日付から自動算出される'
);

select * from finish();
rollback;
