# Tasks

## Active

- [ ] **Set up hosted staging Supabase project** - local/prod split done, staging missing
  - plan.md §3.6
- [ ] **Try Health features on real devices** (activity + weight sync, meal write-back: confirm → appears in Health, edit → replaced, delete → gone, undo → back) - code for §4.1–4.3 is done and dev builds for Android and iOS succeed, but it hasn't run on a device. Check: Health Connect permission sheet + "install Health Connect" path on Android; on iOS, confirm HealthKit shows up under Signing & Capabilities in Xcode (entitlements file is wired via `CODE_SIGN_ENTITLEMENTS`, but the App ID/provisioning profile needs HealthKit enabled) and the Health permission sheet appears. Before Play review: the `ViewPermissionUsageActivity` alias opens the app's main screen — needs a real privacy-policy screen

## Someday

## Done

- [x] ~~Add CI pipeline~~ (2026-09-23) - `.github/workflows/ci.yml` runs `flutter pub get` → `flutter analyze` → `scripts/check_architecture.sh` → `flutter test` on push/PR to main; also fixed 3 pre-existing test failures (missing mocktail `registerFallbackValue` calls in `complete_onboarding_usecase_test.dart`, inverted assertion direction in `calculate_calorie_target_usecase_test.dart`) so the pipeline starts green
  - plan.md §3.4
- [x] ~~Cache signed image URLs client-side~~ (2026-09-23) - `GetSignedImageUrlUseCase` now caches per storage path with a 30s stale buffer before the requested TTL, so `HomeScreen`/`EditMealSheet`'s per-rebuild `FutureBuilder` calls stop re-requesting a fresh signed URL from Storage on every rebuild
  - No repository/datasource/DI changes needed - the use case is a Riverpod singleton per session, so the cache persists naturally
  - 3 new unit tests (cache hit, stale re-fetch, per-path isolation) against the existing mock-repository pattern
  - plan.md §2.2
- [x] ~~Add pagination pattern for historical meal data~~ (2026-09-23) - added `MealLogRepository.fetchLogsPage({userId, before, limit})` (cursor-based on `created_at`) alongside the existing single-day `fetchLogsForDate`, plus a new `FetchMealLogsPageUseCase` and `fetchMealLogsPageUseCaseProvider`
  - Backend-only, as plan.md specified ("ahead of building `PlanScreen`") - `PlanScreen` doesn't consume it yet since it's still the profile/plan-settings editor, not a history view
  - 2 new unit tests against the existing mock-repository pattern
  - plan.md §2.3
- [x] ~~Server-side cleanup of orphaned Storage objects~~ (2026-09-23) - live on the `MealPlan` project: `pg_cron` job (daily 3am) + `cleanup-orphaned-food-images` edge function, deployed via Supabase MCP; Vault secrets and the function's `CRON_SECRET` set (you ran the CLI step)
  - Verified end-to-end against real data: 0 false positives on the project's 16 current `food-images` objects, and a harmless dummy-path test call confirmed the cron secret auth path works (200, correctly reported 0 deleted)
  - plan.md §2.1
- [x] ~~Add crash reporting / observability~~ (2026-09-24) - integrated `sentry_flutter`: `SentryFlutter.init` wraps `main()`, catching uncaught errors, plus a `SentryProviderObserver` reporting any Riverpod provider/notifier that fails to build
  - DSN hardcoded in `core/config/sentry_config.dart` (like `SupabaseConfig`'s anon key — a DSN can only send events, not read data, so it's not a secret), tagged with the existing `SUPABASE_ENV` define so dev/prod events are filterable
  - Verified end-to-end with a standalone smoke test against the real DSN — `Sentry.captureMessage` returned a real (non-empty) event id, confirming the HTTP delivery to Sentry's ingest API actually succeeded
  - plan.md §3.3
- [x] ~~Deploy `analyze-food` lockdown~~ (verified 2026-09-24) - prod `analyze-food` v21 has `verify_jwt`, the 20/hr rate limit and 2MB cap, and matches local source; `add_food_analysis_rate_limit` migration is in prod history
  - plan.md §1.2
- [x] ~~Add `meal_logs(user_id, created_at desc)` index~~ (verified 2026-09-24) - `meal_logs_user_id_created_at_idx` already existed on prod but in no migration; added `20260924000000_add_meal_logs_user_created_idx.sql` (`if not exists`, no-op on prod) so local resets recreate it
  - plan.md §1.5
- [x] ~~Throw `FoodAnalysisException` instead of bare `Exception`~~ (2026-09-24) - non-200 responses from `analyze-food` now throw `FoodAnalysisException` carrying the function's own `{"error": ...}` message (e.g. the 429 hourly-limit text), falling back to the status code; `FoodAnalysisRepositoryImpl` passes that message through as-is instead of prefixing it with "Failed to analyze meal photo:"
  - plan.md §3.2
- [x] ~~Stop leaking raw exceptions into UI state~~ (2026-09-24) - `userMessageFor(err)` in `core/error/app_exception.dart` switches over the sealed `AppException` family: passes through messages already safe (`NotSignedIn`, `FoodAnalysis`, `AskAi`, `AuthFailure`), replaces `MealLogPersistence`/`ImageProcessing` (which embed raw SDK text) with fixed copy, and falls back to "Something went wrong" for anything else
  - Used by every `'$err'` site in `MealLogNotifier`, `AskAiNotifier`, `PlanScreen`, `OnboardingScreen`, `ProfileScreen`, and the catch-alls in `FoodAnalysisRepositoryImpl`/`AskAiRepositoryImpl`. `CameraScanScreen`'s local camera errors left as-is
  - `ask-ai` got the same fix as §3.2: new `AskAiException` + shared `edgeFunctionErrorMessage` helper reading the function's `{"error": ...}` body; `SupabaseAuthRepository`'s non-API fallbacks no longer interpolate `$err`
  - ~~Not covered: `analyze-food`'s server-side `catch` still emits raw `${err}` in its SSE `error` event~~ fixed 2026-09-27 (prod v25): only `UserFacingError` messages pass through, anything else gets generic copy
  - `test/core/error/app_exception_test.dart` covers the mapping and body parsing
  - plan.md §3.1
- [x] ~~Expand test coverage~~ (2026-09-24) - 51 Flutter tests (was 35) + 5 Deno tests
  - `meal_log_notifier_test.dart`: analyze → pending, upload failure → safe message, signed-out guard, confirm prepends log, delete failure rolls back. Overrides repository providers with mocks of the domain interfaces, so real use cases run in between
  - `meal_log_repository_impl_test.dart` (local-midnight range, totals recomputed from portion-adjusted items, error wrapping), `food_analysis_repository_impl_test.dart` (SSE event mapping, error messages)
  - `IncrementalJsonScanner` moved out of `analyze-food/index.ts` into `json_scanner.ts` so it can be imported without starting `Deno.serve`; `json_scanner_test.ts` covers every chunk size, escaped quotes, braces/brackets inside strings, nested objects, partial items. CI gained an `edge-functions` job running `deno test supabase/functions`
  - Not covered: `ImageRepositoryImpl`, profile/avatar/auth/ask-ai repository impls
  - plan.md §3.5
- [x] ~~Fitness: `FitnessRepository` + `health` integration, UI + budget, tests~~ (2026-09-24, not yet device-tested — see Active)
  - `lib/features/fitness/`: `DailyActivity`, `FitnessRepository`, `SetActivitySyncUseCase` (requests permissions before saving the opt-in, so a denial leaves it off), `GetTodayActivityUseCase` (null when off), `HealthFitnessRepositoryImpl`. Active energy is read with an interval (statistics) query so watch + phone sources aren't double-counted
  - Opt-in is a Settings switch "Add exercise calories to budget", off by default, saved with `shared_preferences` (HealthKit doesn't say whether read access was granted, so it can't be derived from permissions). One switch covers both reading activity and adding it to the budget; split it if product wants activity shown without adjusting the budget
  - `HomeScreen` (today only): calorie card target = `dailyTarget + active kcal`, steps/kcal line under the card, pull-to-refresh reloads it. Macro targets stay on the base target. No refresh on app resume yet
  - Native: Android `minSdk` 24→26, `MainActivity` → `FlutterFragmentActivity`, Health Connect read permissions/queries/rationale intent/permission-usage alias; iOS `NSHealthShareUsageDescription` + `Runner.entitlements` (HealthKit) on all 9 Runner build configs
  - `HealthStoreUnavailableException`/`HealthPermissionDeniedException` added to `AppException`; 11 tests in `test/features/fitness/`
  - plan.md §4.1, §4.2, §4.4
- [x] ~~Fix exercise double-counting + sync weight from Health~~ (2026-09-25, not yet device-tested)
  - Double-counting: the stored target is BMR × onboarding activity multiplier, so it already included exercise; adding measured active energy on top counted workouts twice. With sync on, `CalculateActivityAdjustedTargetUseCase` now recomputes the target at the *sedentary* multiplier and adds measured active energy. Removed `DailyActivity.adjustedTarget`
  - Weight: `SyncWeightFromHealthUseCase` reads the latest `WEIGHT` from the last 30 days and, if it's newer than the last plan save (`onboardingCompletedAt`, re-stamped on every save) and differs by ≥0.05 kg, saves it and recomputes the stored target via `completeOnboarding`. So a manual weight edit in `PlanScreen` isn't overwritten by an older scale reading. Runs when `HomeScreen` loads and on pull-to-refresh, with a snackbar when it applies
  - Same Settings switch (now "Sync activity & weight from Health"); Android `READ_WEIGHT` permission added; iOS usage text updated. Anyone who turned the switch on before this change must toggle it off and on to grant weight access
  - 7 new tests (69 total)
- [x] ~~Write meal logs back into HealthKit/Health Connect~~ (2026-09-25, not yet device-tested)
  - Separate Settings switch "Save meals to Health", off by default; turning it on requests nutrition *write* access (`SetMealWriteBackUseCase`)
  - Confirm and undo-delete write the meal (name, meal type, calories, protein, carbs, fat) at its `createdAt`; edit replaces it; delete removes it. `WriteMealToHealthUseCase` always deletes before writing, so the same call covers new/edited/restored meals without duplicates
  - Records are matched by timestamp (±1s), not an id: iOS ignores the plugin's `clientRecordId`. Both stores only let an app delete its own records, so other apps' data is safe. On iOS the per-nutrient samples are deleted too, not just the food correlation, so Apple Health's daily totals drop
  - Best-effort: runs after the meal change succeeds, never blocks or rolls it back; failures go to Sentry, not the UI
  - Not covered: existing history isn't backfilled when the switch is turned on, and edits/deletes made while it's off aren't synced later
  - Android `WRITE_NUTRITION`, iOS `NSHealthUpdateUsageDescription`; 8 new tests (77 total)
  - plan.md §4.3
- [x] ~~Health info across devices + in Ask AI~~ (2026-09-25; verified locally, not deployed)
  - New `daily_activity(user_id, day, steps, active_energy_kcal)` table with RLS (checked locally: own rows only). The device with Health sync on uploads today's reading on every load/refresh (`GetTodayActivityUseCase`); devices without it read the uploaded row. So the budget, steps line and Ask AI match on every device. Weight already synced via `profiles`
  - Sync switch stays per device ("Sync activity & weight from this device") since Health permission is per device; turning it off deletes *today's* uploaded row so the budget stops including it everywhere. If two devices both sync Health, the last upload wins (`ponytail:` note in `ActivityLogRepositoryImpl`)
  - `todayCalorieBudgetProvider` is now the single source for today's budget (`HomeScreen` + Ask AI)
  - `ask-ai`: context builder moved to `context.ts` (+ `context_test.ts`, 5 tests; also fixed type errors that `deno check` had been hiding). Context now includes weight, today's + 7-day activity from `daily_activity`, and the app's budget; the client sends `localDate` + `calorieBudget` (both validated server-side before going into the prompt). Prompt scope widened to exercise/activity/weight
  - Ask AI welcome screen shows two activity prompts when activity is synced
  - Checked end to end on the local stack: seeded activity → Ask AI answered with the right steps and budget
  - Not covered: meal write-back is still per device (meals logged on a tablet aren't written to the phone's Health); history before today isn't backfilled to `daily_activity`
- [x] ~~Deploy to prod via Supabase MCP~~ (2026-09-25)
  - Migrations applied: `add_meal_logs_user_created_idx` (no-op, now in history), `rls_select_auth_uid` (all 8 `profiles`/`meal_logs` policies now `(select auth.uid())`), `daily_activity` (table + RLS). Performance advisor: 0 warnings (was 8 `auth_rls_initplan`)
  - Functions deployed: `ask-ai` v5 (`index.ts` + `context.ts`), `analyze-food` v22 (`index.ts` + `json_scanner.ts`), both `verify_jwt` on. Smoke test with the anon key: both boot and return 401 "Invalid or expired session"
  - plan.md §1.4
- [x] ~~Lock down `cleanup_orphaned_food_images()`~~ (2026-09-25) - it was `SECURITY DEFINER` and callable by anyone with the anon key via `/rest/v1/rpc`; `20260925010000_revoke_cleanup_orphaned_food_images.sql` revokes `execute` from `public`/`anon`/`authenticated` (applied to prod + local). Only `postgres` (the owner, which the `pg_cron` job runs as) and `service_role` keep it. Verified: an anon RPC call now gets 401 `permission denied`, and both SECURITY DEFINER advisor warnings are gone
- [x] ~~Budget never drops below the plan target~~ (2026-09-25, superseded the same day by the fixed/dynamic calorie goal setting below) - with activity sync on, Home showed 2533 vs Plan's 3125 for a real prod user: the budget was sedentary base + measured burn, and just after midnight the synced burn was 0 kcal (30 steps), so it sat ~600 kcal under the plan (and would stay there on devices that record steps but no active energy). `CalculateActivityAdjustedTargetUseCase` now returns `max(plan target at the profile's activity level, sedentary base + measured burn)`: no double-counting, and only activity beyond what the level assumes raises the budget. Home's "+N kcal burned" is now "N kcal burned", since burn no longer always adds to the budget. Tests use the real profile's shape (3125 plan, 0 kcal → 3125; 900 kcal → sedentary + 900). No redeploy needed: Ask AI gets the budget from the app, and its explanation line only appears when the budget is above the plan, where it's still accurate

- [x] ~~Fixed vs dynamic calorie goal~~ (2026-09-25; deployed: `profiles_calorie_mode` migration + `ask-ai` v6 via Supabase MCP) - replaces the automatic "higher of plan and sedentary + burn" rule with an explicit choice on `PlanScreen` ("Calorie goal": Fixed / Dynamic)
  - Fixed (default): plan target from the activity level, every day; Health activity is shown but never changes it. Dynamic: sedentary base + active energy burned today (no floor); falls back to the fixed target when no device has synced activity today, and the Plan screen says to turn on sync in Settings
  - Stored per account in the new `profiles.calorie_mode` column (`fixed`|`dynamic`, check constraint), so every device and Ask AI agree. Saved immediately on toggle via `updateProfile` (partial write), not the ✓ plan save, so weight sync / plan saves (`completeOnboarding`) never reset it. Verified locally: switching keeps other columns, bad values get 400
  - Plan's big number is labelled as the fixed goal while on dynamic; the Calorie goal section shows the sedentary base and today's budget
  - Ask AI context states the mode and quotes the app's budget alongside the fixed target (2 new Deno tests, 11 total)
  - Tests: fixed → plan target, dynamic → sedentary + burn, DTO default/partial-write (81 Flutter tests)
  - Copy pass (2026-09-25): "Dynamic" is shown as "Activity-based" everywhere users see it (enum label, Ask AI context, suggestion chip "goal" not "budget"). Plan's big number shows the inactive-day base in activity-based mode ("Daily calories on an inactive day, plus what you burn") instead of the fixed goal; plain-language explanations per option, including the no-activity-synced fallback and how to fix it; a snackbar confirms each switch with the new number. Home's activity line says "N kcal burned · added to today's goal" only when it actually is. `ask-ai` v7 deployed with the new wording
