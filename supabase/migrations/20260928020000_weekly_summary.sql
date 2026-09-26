-- Weekly roundup in the notification feed: every Monday at 08:00 in the
-- user's own time zone, a summary of the previous Monday–Sunday.
alter table public.notifications
  drop constraint notifications_type_check,
  add constraint notifications_type_check
    check (type in ('meal', 'streak', 'weekly'));

-- Sends the summary to every user whose local time (per profiles.timezone,
-- UTC if unset or unknown) is Monday 08:xx at [at] and who hasn't had one
-- in the last 6 days. [at] is a parameter only so tests can pick the
-- moment; the cron job uses the default. Returns how many were sent.
create function public.send_weekly_summaries(at timestamptz default now())
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  -- ponytail: mirrors the app's fixed water goal (water_card.dart); move
  -- both to a profile column if the goal becomes user-adjustable.
  water_goal_ml constant integer := 2500;
  sent integer;
begin
  with users as (
    select p.id, p.daily_calorie_target as target,
           coalesce(z.name, 'UTC') as zone
    from public.profiles p
    left join pg_catalog.pg_timezone_names z on z.name = p.timezone
  ),
  due as (
    select u.*, (at at time zone u.zone)::date as today
    from users u
    where extract(isodow from at at time zone u.zone) = 1
      and extract(hour from at at time zone u.zone) = 8
      and not exists (
        select 1 from public.notifications n
        where n.user_id = u.id
          and n.type = 'weekly'
          and n.created_at > at - interval '6 days'
      )
  ),
  -- Calories per local day over the 7 days before today (Mon..Sun).
  days as (
    select d.id as user_id,
           (m.created_at at time zone d.zone)::date as day,
           sum(m.total_calories) as kcal
    from due d
    join public.meal_logs m
      on m.user_id = d.id
     and m.deleted_at is null
     and m.created_at >= ((d.today - 7)::timestamp at time zone d.zone)
     and m.created_at < (d.today::timestamp at time zone d.zone)
    group by 1, 2
  ),
  water as (
    select d.id as user_id,
           count(*) filter (where w.ml >= water_goal_ml) as goal_days
    from due d
    join public.daily_water w
      on w.user_id = d.id and w.day >= d.today - 7 and w.day < d.today
    group by 1
  ),
  summary as (
    select d.id,
           count(x.day) as logged,
           round(avg(x.kcal)) as avg_kcal,
           count(x.day) filter (
             where d.target is not null
               and abs(x.kcal - d.target) <= d.target * 0.1
           ) as on_target,
           coalesce(max(wt.goal_days), 0) as water_days
    from due d
    left join days x on x.user_id = d.id
    left join water wt on wt.user_id = d.id
    group by d.id
  )
  insert into public.notifications (user_id, type, title, body)
  select
    id,
    'weekly',
    'Your week in review',
    concat_ws(' · ',
      case when logged > 0 then format(
        'Logged %s of 7 days, avg %s kcal',
        logged, to_char(avg_kcal, 'FM999,999')
      ) end,
      case when logged > 0 then format(
        'on target %s %s', on_target,
        case when on_target = 1 then 'day' else 'days' end
      ) end,
      case when water_days > 0 then format(
        'water goal %s %s', water_days,
        case when water_days = 1 then 'day' else 'days' end
      ) end
    )
  -- Nothing logged all week: stay quiet rather than nag.
  from summary
  where logged > 0 or water_days > 0;

  get diagnostics sent = row_count;
  return sent;
end;
$$;

-- Writes to every user's feed; only the cron job (as postgres) runs it.
revoke execute on function public.send_weekly_summaries(timestamptz)
  from public, anon, authenticated;

-- Hourly, since "Monday 08:00" arrives at a different UTC hour per zone.
select cron.schedule(
  'weekly_summaries',
  '5 * * * *',
  $$select public.send_weekly_summaries()$$
);
