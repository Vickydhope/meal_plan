-- Baseline schema, captured from the remote project (rchzdxmmvixeyoiulqsd) as
-- of 2026-09-20 via the Supabase MCP tools (`supabase login`/`db pull` were
-- not available in this environment). Ordered before the two pre-existing
-- migrations, which both `alter table public.profiles`/reference
-- `public.meal_logs` and depend on these tables existing first.

create table public.profiles (
  id uuid primary key references auth.users (id),
  username text,
  daily_calorie_target integer,
  created_at timestamptz not null default now(),
  sex text check (sex in ('male', 'female')),
  date_of_birth date,
  height_cm numeric,
  weight_kg numeric,
  activity_level text check (activity_level in ('sedentary', 'light', 'moderate', 'active', 'very_active')),
  goal text check (goal in ('lose', 'maintain', 'gain')),
  onboarding_completed_at timestamptz,
  full_name text,
  phone text
);

comment on column public.profiles.onboarding_completed_at is
  'Set once, when the user finishes the 6-step onboarding flow. Null means onboarding is still pending.';

alter table public.profiles enable row level security;

create policy profiles_select_own on public.profiles
  for select using (auth.uid() = id);
create policy profiles_insert_own on public.profiles
  for insert with check (auth.uid() = id);
create policy profiles_update_own on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);
create policy profiles_delete_own on public.profiles
  for delete using (auth.uid() = id);

create table public.meal_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id),
  image_url text,
  total_calories integer,
  total_protein integer,
  total_carbs integer,
  total_fats integer,
  raw_json_data jsonb,
  created_at timestamptz not null default now(),
  meal_name text,
  health_score smallint,
  meal_type text not null default 'other'
    check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack', 'other'))
);

alter table public.meal_logs enable row level security;

create policy meal_logs_select_own on public.meal_logs
  for select using (auth.uid() = user_id);
create policy meal_logs_insert_own on public.meal_logs
  for insert with check (auth.uid() = user_id);
create policy meal_logs_update_own on public.meal_logs
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy meal_logs_delete_own on public.meal_logs
  for delete using (auth.uid() = user_id);

insert into storage.buckets (id, name, public, file_size_limit)
values ('food-images', 'food-images', false, 512000)
on conflict (id) do nothing;

create policy food_images_select_own on storage.objects
  for select using (
    bucket_id = 'food-images' and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy food_images_insert_own on storage.objects
  for insert with check (
    bucket_id = 'food-images' and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy food_images_update_own on storage.objects
  for update using (
    bucket_id = 'food-images' and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy food_images_delete_own on storage.objects
  for delete using (
    bucket_id = 'food-images' and (storage.foldername(name))[1] = auth.uid()::text
  );
