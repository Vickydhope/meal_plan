-- How the daily calorie budget is set: 'fixed' = the plan target from the
-- self-reported activity level; 'dynamic' = the target at a sedentary level
-- plus the active energy synced from a health app that day. Per account (not
-- per device) so every device and Ask AI use the same budget.
alter table public.profiles
  add column calorie_mode text not null default 'fixed'
    check (calorie_mode in ('fixed', 'dynamic'));
