-- Water drunk per local calendar day, from the Home screen's water card
-- (editable for today only).
create table public.daily_water (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  ml integer not null check (ml between 0 and 10000),
  updated_at timestamptz not null default now(),
  primary key (user_id, day)
);

alter table public.daily_water enable row level security;

create policy daily_water_select_own on public.daily_water
  for select using ((select auth.uid()) = user_id);
create policy daily_water_insert_own on public.daily_water
  for insert with check ((select auth.uid()) = user_id);
create policy daily_water_update_own on public.daily_water
  for update using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
