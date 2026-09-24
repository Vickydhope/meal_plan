-- Already exists on prod (created outside migrations); `if not exists` keeps
-- this a no-op there while making `supabase db reset` recreate it locally.
create index if not exists meal_logs_user_id_created_at_idx
  on public.meal_logs (user_id, created_at desc);
