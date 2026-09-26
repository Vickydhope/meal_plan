-- IANA zone of the user's device (e.g. 'Asia/Kolkata'), written by the app
-- on launch/resume, so streak days follow the user's calendar, not UTC.
alter table public.profiles add column timezone text;

create or replace function public.notify_meal_logged()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  zone text;
  today date;
  streak integer := 0;
begin
  insert into public.notifications (user_id, type, title, body)
  values (
    new.user_id,
    'meal',
    'Meal logged',
    format('"%s" was added to your log — %s kcal.',
      coalesce(new.meal_name, 'Your meal'), coalesce(new.total_calories, 0))
  );

  select p.timezone into zone from public.profiles p where p.id = new.user_id;
  begin
    today := (new.created_at at time zone coalesce(zone, 'UTC'))::date;
  exception when others then
    -- Unknown zone name: fall back rather than failing the meal insert.
    zone := 'UTC';
    today := (new.created_at at time zone zone)::date;
  end;
  zone := coalesce(zone, 'UTC');

  -- Streaks only move on the first meal of a day.
  if exists (
    select 1 from public.meal_logs
    where user_id = new.user_id
      and id <> new.id
      and deleted_at is null
      and (created_at at time zone zone)::date = today
  ) then
    return new;
  end if;

  while exists (
    select 1 from public.meal_logs
    where user_id = new.user_id
      and deleted_at is null
      and (created_at at time zone zone)::date = today - streak
  ) loop
    streak := streak + 1;
  end loop;

  if streak in (3, 7, 14, 30, 60, 100) then
    insert into public.notifications (user_id, type, title, body)
    values (
      new.user_id,
      'streak',
      format('%s-day streak! 🔥', streak),
      format('You''ve logged a meal %s days in a row. Keep it going!', streak)
    );
  end if;

  return new;
end;
$$;
