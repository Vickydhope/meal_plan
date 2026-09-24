-- SECURITY DEFINER + the default EXECUTE grant made this callable by anyone
-- with the public anon key via /rest/v1/rpc. Only the pg_cron job (runs as
-- postgres, the owner) should run it.
revoke execute on function public.cleanup_orphaned_food_images()
  from public, anon, authenticated;
