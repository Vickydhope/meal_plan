-- Free-text dietary preferences ("vegetarian, no nuts") that the
-- suggest-meals function respects. Kept short: it goes into every prompt.
alter table public.profiles
  add column diet_notes text check (char_length(diet_notes) <= 200);

-- One row per suggest-meals call, for its hourly rate limit — same shape as
-- food_analysis_requests / ask_ai_requests.
create table public.meal_suggestion_requests (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index meal_suggestion_requests_user_id_created_at_idx
  on public.meal_suggestion_requests (user_id, created_at desc);

alter table public.meal_suggestion_requests enable row level security;

create policy meal_suggestion_requests_select_own
  on public.meal_suggestion_requests
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy meal_suggestion_requests_insert_own
  on public.meal_suggestion_requests
  for insert to authenticated
  with check (user_id = (select auth.uid()));

-- The window is computed at query time; this only keeps the table small.
select cron.schedule(
  'meal_suggestion_requests_cleanup',
  '0 3 * * *',
  $$delete from public.meal_suggestion_requests where created_at < now() - interval '7 days'$$
);
