-- Run with `supabase test db` against the local stack (seeded user from
-- seed.sql). Everything happens in a transaction that's rolled back.
begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

-- A clean slate for the seeded user, in a non-UTC zone.
delete from public.daily_water where user_id = '11111111-1111-1111-1111-111111111111';
delete from public.meal_logs where user_id = '11111111-1111-1111-1111-111111111111';
delete from public.notifications where type = 'weekly';
update public.profiles
  set timezone = 'Asia/Kolkata', daily_calorie_target = 2000
  where id = '11111111-1111-1111-1111-111111111111';

-- Week of Mon 21 .. Sun 27 Sep (Kolkata): 3 logged days, 2 on target.
insert into public.meal_logs
  (user_id, meal_name, total_calories, total_protein, total_carbs, total_fats, created_at)
values
  ('11111111-1111-1111-1111-111111111111', 'A', 1900, 0, 0, 0, '2026-09-21 09:00+05:30'),
  ('11111111-1111-1111-1111-111111111111', 'B', 1200, 0, 0, 0, '2026-09-23 09:00+05:30'),
  ('11111111-1111-1111-1111-111111111111', 'C',  900, 0, 0, 0, '2026-09-23 20:00+05:30'),
  ('11111111-1111-1111-1111-111111111111', 'D', 3000, 0, 0, 0, '2026-09-27 23:30+05:30'),
  -- Just outside the week on either side:
  ('11111111-1111-1111-1111-111111111111', 'X', 5000, 0, 0, 0, '2026-09-28 00:10+05:30'),
  ('11111111-1111-1111-1111-111111111111', 'Y', 5000, 0, 0, 0, '2026-09-20 23:50+05:30');
insert into public.daily_water (user_id, day, ml) values
  ('11111111-1111-1111-1111-111111111111', '2026-09-22', 2500),
  ('11111111-1111-1111-1111-111111111111', '2026-09-24', 1000),
  ('11111111-1111-1111-1111-111111111111', '2026-09-28', 3000);

-- Monday 28 Sep: 07:30 / 08:30 Kolkata = 02:00 / 03:00 UTC.
select is(public.send_weekly_summaries('2026-09-28 02:00+00'), 0,
  'not sent before 08:00 local');
select is(public.send_weekly_summaries('2026-09-28 03:00+00'), 1,
  'sent at 08:xx local on Monday');
select is(public.send_weekly_summaries('2026-09-28 03:40+00'), 0,
  'not sent twice in a week');
select is(
  (select body from public.notifications where type = 'weekly'),
  'Logged 3 of 7 days, avg 2,333 kcal · on target 2 days · water goal 1 day',
  'summarizes only that Monday–Sunday in the user''s zone');

delete from public.meal_logs where user_id = '11111111-1111-1111-1111-111111111111';
delete from public.daily_water where user_id = '11111111-1111-1111-1111-111111111111';
select is(public.send_weekly_summaries('2026-10-05 03:00+00'), 0,
  'quiet week sends nothing');

select is(
  has_function_privilege('authenticated', 'public.send_weekly_summaries(timestamptz)', 'execute'),
  false, 'app users cannot trigger summaries');
select isnt(
  (select jobid from cron.job where jobname = 'weekly_summaries'), null,
  'hourly cron job is scheduled');

select * from finish();
rollback;
