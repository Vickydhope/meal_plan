-- Periodically reclaims `food-images` Storage objects left behind when a
-- scan is abandoned mid-flow (crash/kill/lost network) after the photo
-- uploads but before a `meal_logs` row is ever inserted - the happy-path
-- cleanup (`DiscardPendingMealUseCase`) can't run in that case.
--
-- Deletion has to happen through the Storage API, not a SQL `delete from
-- storage.objects` - that only removes the metadata row, not the
-- underlying bytes - so this job computes the orphaned paths in SQL, then
-- posts them to the `cleanup-orphaned-food-images` edge function (via
-- pg_net), which calls the real Storage API.
--
-- ## One-time manual setup required before this job can run (not part of
-- this migration - these are per-project secrets, not something safe to
-- commit):
--
-- 1. Deploy the edge function and set its secret:
--      supabase functions deploy cleanup-orphaned-food-images
--      supabase secrets set CRON_SECRET=<a random value you generate>
--
-- 2. Store that same value, plus this project's URL, in Supabase Vault
--    (Dashboard: Project Settings > Vault, or SQL Editor):
--      select vault.create_secret('https://<project-ref>.supabase.co', 'project_url');
--      select vault.create_secret('<the same random value from step 1>', 'cron_secret');
--
-- Until both secrets exist in Vault, `cleanup_orphaned_food_images()` below
-- is a no-op (it exits early rather than calling net.http_post with a null
-- URL/secret).

create extension if not exists pg_net with schema extensions;

create or replace function public.cleanup_orphaned_food_images()
returns void
language plpgsql
security definer
set search_path = public, storage, extensions
as $$
declare
  v_project_url text;
  v_cron_secret text;
  v_paths text[];
begin
  select decrypted_secret into v_project_url
    from vault.decrypted_secrets where name = 'project_url';
  select decrypted_secret into v_cron_secret
    from vault.decrypted_secrets where name = 'cron_secret';

  if v_project_url is null or v_cron_secret is null then
    raise notice 'cleanup_orphaned_food_images: project_url/cron_secret not set in Vault yet - skipping';
    return;
  end if;

  select array_agg(o.name) into v_paths
  from storage.objects o
  where o.bucket_id = 'food-images'
    and o.created_at < now() - interval '24 hours'
    and not exists (
      select 1 from public.meal_logs m where m.image_url = o.name
    );

  if v_paths is null or array_length(v_paths, 1) = 0 then
    return;
  end if;

  perform net.http_post(
    url := v_project_url || '/functions/v1/cleanup-orphaned-food-images',
    body := jsonb_build_object('paths', v_paths),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', v_cron_secret
    ),
    timeout_milliseconds := 10000
  );
end;
$$;

select cron.schedule(
  'cleanup_orphaned_food_images',
  '0 3 * * *',
  $$select public.cleanup_orphaned_food_images()$$
);
