create table public.food_analysis_requests (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index food_analysis_requests_user_id_created_at_idx
  on public.food_analysis_requests (user_id, created_at desc);

alter table public.food_analysis_requests enable row level security;

create policy "Users can view their own analysis requests"
  on public.food_analysis_requests
  for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy "Users can log their own analysis requests"
  on public.food_analysis_requests
  for insert
  to authenticated
  with check (user_id = (select auth.uid()));

-- Rolling window is computed at query time by the edge function, so this
-- table only needs periodic pruning to stay small, not a reset job.
create extension if not exists pg_cron with schema extensions;

select cron.schedule(
  'food_analysis_requests_cleanup',
  '0 3 * * *',
  $$delete from public.food_analysis_requests where created_at < now() - interval '7 days'$$
);
