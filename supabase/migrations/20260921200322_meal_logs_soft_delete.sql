alter table public.meal_logs add column deleted_at timestamptz;

create index if not exists meal_logs_user_created_live_idx
  on public.meal_logs (user_id, created_at)
  where deleted_at is null;
