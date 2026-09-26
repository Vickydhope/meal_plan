-- Body-weight history for the Trends screen. `profiles.weight_kg` only holds
-- the current value, so every change to it is copied here by trigger (plan
-- edits, onboarding, Health sync — no app code needed per write path), and
-- the app imports past readings from HealthKit / Health Connect directly.
create table public.weight_logs (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  weight_kg numeric not null check (weight_kg > 0),
  logged_at timestamptz not null default now(),
  -- Makes re-importing the same Health readings a no-op; also serves the
  -- per-user date-range query.
  unique (user_id, logged_at)
);

alter table public.weight_logs enable row level security;

create policy weight_logs_select_own on public.weight_logs
  for select using ((select auth.uid()) = user_id);
create policy weight_logs_insert_own on public.weight_logs
  for insert with check ((select auth.uid()) = user_id);

create function public.log_profile_weight()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- on conflict: a second weight change in the same transaction shares
  -- now(); dropping it beats aborting the profile save.
  insert into public.weight_logs (user_id, weight_kg)
  values (new.id, new.weight_kg)
  on conflict (user_id, logged_at) do nothing;
  return new;
end;
$$;

create trigger profiles_log_weight_insert
  after insert on public.profiles
  for each row when (new.weight_kg is not null)
  execute function public.log_profile_weight();

create trigger profiles_log_weight_update
  after update of weight_kg on public.profiles
  for each row when (
    new.weight_kg is not null and new.weight_kg is distinct from old.weight_kg
  )
  execute function public.log_profile_weight();

-- Seed each existing user's current weight so the chart isn't empty.
insert into public.weight_logs (user_id, weight_kg, logged_at)
select id, weight_kg, coalesce(onboarding_completed_at, now())
from public.profiles
where weight_kg is not null;
