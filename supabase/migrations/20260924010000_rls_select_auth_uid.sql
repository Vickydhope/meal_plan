-- Wrap auth.uid() in a scalar subquery so Postgres evaluates it once per
-- statement (initPlan) instead of once per row. Same semantics.
alter policy profiles_select_own on public.profiles
  using ((select auth.uid()) = id);
alter policy profiles_insert_own on public.profiles
  with check ((select auth.uid()) = id);
alter policy profiles_update_own on public.profiles
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
alter policy profiles_delete_own on public.profiles
  using ((select auth.uid()) = id);

alter policy meal_logs_select_own on public.meal_logs
  using ((select auth.uid()) = user_id);
alter policy meal_logs_insert_own on public.meal_logs
  with check ((select auth.uid()) = user_id);
alter policy meal_logs_update_own on public.meal_logs
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
alter policy meal_logs_delete_own on public.meal_logs
  using ((select auth.uid()) = user_id);
