-- Per-day activity copied up from a device's health store (HealthKit /
-- Health Connect), so other devices on the same account and the ask-ai
-- function can see it. `day` is the uploading device's local calendar day.
create table public.daily_activity (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  steps integer not null default 0 check (steps >= 0),
  active_energy_kcal integer not null default 0 check (active_energy_kcal >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, day)
);

alter table public.daily_activity enable row level security;

create policy daily_activity_select_own on public.daily_activity
  for select using ((select auth.uid()) = user_id);
create policy daily_activity_insert_own on public.daily_activity
  for insert with check ((select auth.uid()) = user_id);
create policy daily_activity_update_own on public.daily_activity
  for update using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy daily_activity_delete_own on public.daily_activity
  for delete using ((select auth.uid()) = user_id);
