-- Runs automatically on `supabase db reset`. Seeds one dev user so local
-- testing doesn't start from a totally empty database. Login:
--   dev@example.com / password123

do $$
declare
  seed_user_id uuid := '11111111-1111-1111-1111-111111111111';
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data, is_super_admin,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values (
    '00000000-0000-0000-0000-000000000000',
    seed_user_id,
    'authenticated',
    'authenticated',
    'dev@example.com',
    crypt('password123', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    false,
    '', '', '', ''
  )
  on conflict (id) do nothing;

  insert into auth.identities (
    id, provider_id, user_id, identity_data, provider,
    last_sign_in_at, created_at, updated_at
  ) values (
    seed_user_id, seed_user_id, seed_user_id,
    jsonb_build_object('sub', seed_user_id::text, 'email', 'dev@example.com'),
    'email', now(), now(), now()
  )
  on conflict (provider_id, provider) do nothing;

  insert into public.profiles (
    id, username, full_name, daily_calorie_target,
    sex, date_of_birth, height_cm, weight_kg,
    activity_level, goal, onboarding_completed_at
  ) values (
    seed_user_id, 'devuser', 'Dev User', 2200,
    'male', '1995-06-15', 178.0, 76.0,
    'moderate', 'maintain', now()
  )
  on conflict (id) do nothing;

  insert into public.meal_logs (
    id, user_id, image_url, meal_name,
    total_calories, total_protein, total_carbs, total_fats,
    health_score, meal_type, raw_json_data, created_at
  ) values
  (
    gen_random_uuid(), seed_user_id, null, 'Grilled Chicken Bowl',
    550, 42, 55, 15, 8, 'lunch',
    '{"items":[{"food_name":"Grilled chicken","estimated_weight_g":150,"calories":250,"protein_g":38,"carbs_g":0,"fats_g":8},{"food_name":"Rice","estimated_weight_g":180,"calories":300,"protein_g":4,"carbs_g":55,"fats_g":7}]}'::jsonb,
    now() - interval '1 day'
  ),
  (
    gen_random_uuid(), seed_user_id, null, 'Greek Yogurt & Berries',
    280, 20, 30, 6, 9, 'breakfast',
    '{"items":[{"food_name":"Greek yogurt","estimated_weight_g":200,"calories":180,"protein_g":18,"carbs_g":10,"fats_g":5},{"food_name":"Mixed berries","estimated_weight_g":80,"calories":100,"protein_g":2,"carbs_g":20,"fats_g":1}]}'::jsonb,
    now()
  );
end $$;
