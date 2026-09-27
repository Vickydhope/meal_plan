-- Deleting an auth user (the delete-account function) removes all of their
-- rows. Every other user_id FK already cascades; these two predate that.
alter table public.profiles
  drop constraint profiles_id_fkey,
  add constraint profiles_id_fkey
    foreign key (id) references auth.users (id) on delete cascade;

alter table public.meal_logs
  drop constraint meal_logs_user_id_fkey,
  add constraint meal_logs_user_id_fkey
    foreign key (user_id) references auth.users (id) on delete cascade;
