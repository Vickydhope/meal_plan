create table public.ask_ai_requests (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index ask_ai_requests_user_id_created_at_idx
  on public.ask_ai_requests (user_id, created_at desc);

alter table public.ask_ai_requests enable row level security;

create policy "Users can view their own ask-ai requests"
  on public.ask_ai_requests
  for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy "Users can log their own ask-ai requests"
  on public.ask_ai_requests
  for insert
  to authenticated
  with check (user_id = (select auth.uid()));

-- Rolling window is computed at query time by the edge function, so this
-- table only needs periodic pruning to stay small, not a reset job.
select cron.schedule(
  'ask_ai_requests_cleanup',
  '0 3 * * *',
  $$delete from public.ask_ai_requests where created_at < now() - interval '7 days'$$
);
