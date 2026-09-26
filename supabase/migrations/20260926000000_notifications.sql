-- In-app notification feed. Rows are written only by triggers (no insert
-- policy); clients read them and set read_at.
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  type text not null check (type in ('meal', 'streak')),
  title text not null,
  body text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index notifications_user_created_idx
  on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;

create policy notifications_select_own on public.notifications
  for select using ((select auth.uid()) = user_id);
create policy notifications_update_own on public.notifications
  for update using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy notifications_delete_own on public.notifications
  for delete using ((select auth.uid()) = user_id);

create function public.notify_meal_logged()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  -- ponytail: UTC day boundaries; store profiles.timezone if off-by-one
  -- streaks get reported.
  today date := (new.created_at at time zone 'utc')::date;
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

  -- Streaks only move on the first meal of a day.
  if exists (
    select 1 from public.meal_logs
    where user_id = new.user_id
      and id <> new.id
      and deleted_at is null
      and (created_at at time zone 'utc')::date = today
  ) then
    return new;
  end if;

  while exists (
    select 1 from public.meal_logs
    where user_id = new.user_id
      and deleted_at is null
      and (created_at at time zone 'utc')::date = today - streak
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

revoke execute on function public.notify_meal_logged()
  from public, anon, authenticated;

create trigger meal_logs_notify
  after insert on public.meal_logs
  for each row execute function public.notify_meal_logged();
