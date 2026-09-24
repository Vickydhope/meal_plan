# Production Readiness Plan — Calorie Tracker

Source: architecture/scalability/code-quality review, 2026-09-19.
Status legend: `[ ]` not started · `[~]` in progress · `[x]` done

---

## 1. Critical blockers

### 1.1 Replace anonymous-only auth with email/password sign-up & login
- **Status:** [x]
- **Problem:** `landing_screen.dart` buttons were labeled "Sign up with Apple/Google" but both called `signInAnonymously()`. There was no real identity — uninstalling the app or clearing storage permanently lost all meal logs, with no recovery path and no cross-device sync. (Decision: email/password chosen over Apple/Google — no external OAuth console setup required, ships faster; Google/Apple can be added later as additional providers without changing the account model.)
- **Work done:**
  - `AuthRepository` (`lib/core/auth/auth_repository.dart`) gained `signUpWithEmail`, `signInWithEmail`, `signOut`, and a reactive `userIdChanges` stream.
  - `SupabaseAuthRepository` implements these against `supabase_flutter`'s `auth.signUp`/`signInWithPassword`/`signOut`/`onAuthStateChange`, mapping raw `AuthApiException` codes (`invalid_credentials`, `user_already_exists`, `weak_password`, `email_not_confirmed`, rate limiting) to user-safe messages via a new `AuthFailureException` (`lib/core/error/app_exception.dart`) — named to avoid colliding with `supabase_flutter`'s own `AuthException`.
  - `landing_screen.dart` rewritten as an email/password form with a sign-up/login toggle, validation, loading state, error display, and an "check your email to confirm" message when email confirmation is required.
  - `main.dart` now routes reactively via a `StreamBuilder` on `AuthRepository.userIdChanges` (`_AuthGate`) instead of a one-shot `currentSession` check at startup, so sign-in/sign-out/session-expiry all update the UI without a manual `Navigator` call.
  - Added a "Log out" action on `PlanScreen` (previously a stub with no way to sign out).
  - `flutter analyze` passes with 0 new issues; `flutter test` currently fails in this environment due to a pre-existing, unrelated native-asset build hook error in the `objective_c` package (reproduces identically on unmodified `main` — not caused by this change).
- **Follow-ups still open:** enable "leaked password protection" in Supabase Auth settings (flagged by the security advisor); consider adding Apple/Google as additional providers later; no automated tests added yet for the new auth repository/landing screen (tracked under 3.5).
- **Expected result:** A user can sign up and log in with email/password, their data survives reinstall/device change, and the UI reacts automatically to auth state changes.

### 1.2 Lock down the `analyze-food` edge function (auth + rate limiting)
- **Status:** [x]
- **Problem:** The function never validates the caller's JWT or checks identity/quota. Anyone with the public anon key can call it directly and drive unbounded Gemini API cost. Confirmed via code inspection: `food_analysis_remote_data_source.dart` calls the function with a raw `http.Request` (not `supabase.functions.invoke`, since the SSE response doesn't fit that API), manually sets `Authorization: Bearer <session.accessToken ?? anonKey>` — so a logged-in user's JWT *is* sent today, but the function itself never checks it, and nothing stops a request with just the anon key (no session) or a scripted flood of authenticated requests.
- **Work:**
  1. **Enforce JWT verification.** No `supabase/config.toml` exists in the repo, so `verify_jwt` is whatever the dashboard/platform default is — implicit and un-reviewable. Add `supabase/config.toml` with an explicit `[functions.analyze-food]` section setting `verify_jwt = true`, so a disabled check would show up as a diff in review instead of a silent dashboard toggle.
  2. **Per-user rate limiting — 20 requests/hour, rolling window, log-table based** (per product decision):
     - New migration: `food_analysis_requests(id bigint generated always as identity primary key, user_id uuid not null references auth.users(id), created_at timestamptz not null default now())` with an index on `(user_id, created_at desc)`.
     - RLS: enable RLS, policy allowing `insert`/`select` only where `user_id = (select auth.uid())` (per the 1.4 pattern) — no anon/public access, no separate service-role secret needed in the function.
     - In `index.ts`: after parsing the request, create a `supabase-js` client scoped to the incoming `Authorization` header (so RLS applies as the calling user), call `auth.getUser()` to get `user_id` from the verified JWT, then `select count(*) from food_analysis_requests where created_at > now() - interval '1 hour'`. If `>= 20`, return `429` with a user-safe "You've hit the hourly limit, try again later" message *before* calling Gemini. If under the limit, `insert` a row for this request, then proceed to `callGeminiStream`.
     - Insert happens on every accepted attempt (not just successes) so retried/failed Gemini calls still count against quota — they still cost money via the Gemini request itself.
     - No `pg_cron` needed for this design (rolling window is computed at query time); add a periodic cleanup (`delete ... where created_at < now() - interval '7 days'`) as a lightweight `pg_cron` job so the table doesn't grow unbounded, but it's not required for correctness.
  3. **Server-side payload size cap.** Client compresses to <200KB JPEG, but the function should not trust that. After parsing the JSON body, compute the decoded byte size of `image` (base64 length × 0.75) and reject with `413` if it exceeds a fixed ceiling (e.g. 2MB) before ever calling Gemini.
  4. Ship the new table/policies as part of the same migration group as 1.3/1.4/1.5 (schema versioning work), since it's new schema plus RLS.
- **Work done:**
  - `supabase/config.toml` added with `[functions.analyze-food] verify_jwt = true`, made explicit instead of relying on the dashboard default.
  - `supabase/migrations/20260920010000_add_food_analysis_rate_limit.sql`: new `food_analysis_requests(id, user_id, created_at)` table, composite index on `(user_id, created_at desc)`, RLS policies scoping select/insert to `user_id = (select auth.uid())`, and a `pg_cron` job (`food_analysis_requests_cleanup`, daily at 03:00) pruning rows older than 7 days.
  - `supabase/functions/analyze-food/index.ts`: now requires an `Authorization` header, builds a request-scoped `supabase-js` client from it (not the service role) so `auth.getUser()` and the rate-limit query run under RLS as the calling user; returns `401` if the header is missing or the session is invalid. Queries `food_analysis_requests` for a count in the trailing 1-hour rolling window and returns `429` at `>= 20`. Rejects payloads over 2MB decoded (`image.length * 0.75`) with `413`, checked before any Gemini call. Logs a request row *before* calling Gemini so retried/failed attempts still count against quota.
  - Not deployed yet — `mcp__claude_ai_Supabase__apply_migration`/`deploy_edge_function` (or `supabase db push` / `supabase functions deploy analyze-food`) still need to be run against the project, and the client-side raw-`Exception` handling on non-200 responses (tracked separately under 3.2) means a `429`/`401`/`413` will currently surface to the user as a generic error rather than a friendly message.
- **Expected result:** Only requests with a valid, verified JWT reach Gemini; a single user is capped at 20 analyses/hour regardless of retries or scripting; oversized payloads are rejected before hitting the Gemini API.

### 1.3 Check database schema/migrations into the repo
- **Status:** [x] (done as part of 3.6)
- **Problem:** `profiles`/`meal_logs` schema exists only in the remote Supabase project — no version control, no reproducible dev/staging environment, no rollback path, no PR review for schema changes.
- **Work done:** `supabase/migrations/` now holds a baseline schema migration plus incremental migrations (rate limiting, avatar support, soft delete, storage cleanup); migration workflow documented in CLAUDE.md's "Local Supabase stack" section.
- **Expected result:** Schema changes are versioned, reviewable, and reproducible from a clean project via `supabase db push`/CLI.

### 1.4 Fix RLS policy performance (`auth.uid()` re-evaluation)
- **Status:** [ ]
- **Problem:** Supabase performance advisor flags all 8 RLS policies on `profiles`/`meal_logs` for re-evaluating `auth.uid()` per row instead of once per query.
- **Work:** Rewrite each policy to use `(select auth.uid())` instead of a bare `auth.uid()` call. Ship as part of the migration from 1.3.
- **Expected result:** Advisor performance warnings cleared; RLS checks scale with row count instead of degrading linearly.

### 1.5 Add missing index on `meal_logs(user_id, created_at)`
- **Status:** [ ]
- **Problem:** Every query filters by `user_id` and orders by `created_at` with no composite index — will degrade to scans as per-user row counts grow.
- **Work:** Add `create index on meal_logs (user_id, created_at desc);` in the same migration.
- **Expected result:** Date-range queries stay fast as `meal_logs` grows past a few thousand rows per user.

---

## 2. Scalability

### 2.1 Server-side cleanup of orphaned Storage objects
- **Status:** [x] (2026-09-23, live on production)
- **Problem:** `DiscardPendingMealUseCase` only cleans up uploaded images on the happy path. Crashes/kills/lost network mid-flow leave orphaned files in `food-images` indefinitely — unbounded storage cost growth.
- **Work:** Added a `pg_cron` job (`supabase/migrations/20260923000000_cleanup_orphaned_food_images.sql`) that runs daily at 3am, finds `food-images` objects older than 24h with no matching `meal_logs.image_url`, and posts the orphaned paths to a new `cleanup-orphaned-food-images` edge function (via `pg_net`), which calls the real Storage API to delete them — a raw SQL `delete from storage.objects` only removes metadata, not the underlying bytes, so the edge function is required for an actual fix, not just the migration.
- **Deployed and verified end-to-end** on the live `MealPlan` project: migration applied, Vault secrets (`project_url`, `cron_secret`) set, edge function deployed with its `CRON_SECRET` matching. Confirmed the detection query has 0 false positives against real data (all 16 current `food-images` objects older than 24h have matching `meal_logs` rows), and confirmed the cron-secret auth path works via a harmless dummy-path invocation (200, correctly reported 0 deleted).
- **Expected result:** Orphaned images are automatically reclaimed; storage cost tracks actual logged meals, not upload attempts.

### 2.2 Cache signed image URLs client-side
- **Status:** [x] (2026-09-23)
- **Problem:** `getSignedImageUrl` is re-requested on every view instead of being cached for its TTL.
- **Work done:** `GetSignedImageUrlUseCase` caches per storage path with a 30s stale buffer before the requested TTL; 3 new unit tests (cache hit, stale re-fetch, per-path isolation).
- **Expected result:** Fewer redundant Storage API calls per session; lower cost and latency as usage grows.

### 2.3 Add pagination pattern for historical meal data
- **Status:** [x] (2026-09-23)
- **Problem:** No pagination exists anywhere in `MealLogRepository`; fine for single-day views today, but `PlanScreen` will need multi-week/month history.
- **Work done:** Added `MealLogRepository.fetchLogsPage({userId, before, limit})` (cursor-based on `created_at`) plus `FetchMealLogsPageUseCase`; backend-only, `PlanScreen` doesn't consume it yet. 2 new unit tests.
- **Expected result:** Historical/plan views can be built without a full-table fetch per user.

---

## 3. Code quality

### 3.1 Stop leaking raw exceptions into user-facing state
- **Status:** [ ]
- **Problem:** `MealLogNotifier.confirmMealLog/updateMealLog/commitDeleteMealLog` set `state.error` to `'$err'` directly, exposing internal exception text (e.g. raw `PostgrestException`) to the UI.
- **Work:** Catch `AppException` subtypes specifically and map each to a user-safe message; fall back to a generic "Something went wrong" for unexpected errors instead of interpolating `$err`.
- **Expected result:** Users never see raw exception/stack internals; error messages are consistent and safe across the app.

### 3.2 Fix inconsistent exception typing in food analysis data source
- **Status:** [ ]
- **Problem:** `FoodAnalysisRemoteDataSource.streamAnalyzeFood` throws a bare `Exception(...)` on non-200 responses instead of `FoodAnalysisException`, breaking the "presentation only catches `AppException`" contract used elsewhere.
- **Work:** Replace the bare `Exception` with `FoodAnalysisException`.
- **Expected result:** All repository/data-source failures surface as `AppException` subtypes, consistent with the rest of the codebase.

### 3.3 Add crash reporting / observability
- **Status:** [x] (2026-09-24)
- **Problem:** No Sentry/Crashlytics/analytics anywhere in the app — production issues are invisible beyond user reports.
- **Work:** Integrated `sentry_flutter`. `SentryFlutter.init` wraps `main()`'s `appRunner`, installing `FlutterError.onError`/`PlatformDispatcher.onError` for uncaught errors. `SentryProviderObserver` (`core/error/`) hooks Riverpod's `ProviderObserver.providerDidFail`, so any provider/notifier that throws during build (as opposed to an error a notifier already catches and surfaces via `state.error`) is reported too. DSN lives in `core/config/sentry_config.dart`, hardcoded like `SupabaseConfig`'s anon key — a DSN can only *send* events, not read data, so it's not a secret. Events are tagged with the existing `SUPABASE_ENV` define as the Sentry `environment`, so local dev runs stay filterable from prod.
- **Verified:** a standalone smoke test against the real DSN confirmed end-to-end delivery (`Sentry.captureMessage` awaits `HttpTransport.send`, which returned a real, non-empty event id).
- **Expected result:** Crashes and unhandled errors in production are visible and traceable without relying on user reports.

### 3.4 Add CI pipeline
- **Status:** [x] (2026-09-23)
- **Problem:** No `.github/workflows` — `flutter analyze`/`flutter test` aren't gated anywhere; regressions can merge silently.
- **Work done:** `.github/workflows/ci.yml` runs `flutter pub get` → `flutter analyze` → `scripts/check_architecture.sh` → `flutter test` on push/PR to main; also fixed 3 pre-existing test failures so the pipeline starts green.
- **Expected result:** Analysis/test failures block merges automatically instead of relying on manual runs.

### 3.5 Expand test coverage beyond domain use cases
- **Status:** [ ]
- **Problem:** Only use cases and one widget test are covered — no tests for `MealLogNotifier` (most stateful class), `*RepositoryImpl` classes, or the edge function's `IncrementalJsonScanner`.
- **Work:** Add notifier tests (state transitions via mocked use cases), repository-impl tests, and Deno unit tests for `IncrementalJsonScanner`'s partial-JSON parsing.
- **Expected result:** Regressions in state management, repository error-wrapping, and streaming JSON parsing are caught before release.

### 3.6 Support multiple environments (dev/staging/prod config)
- **Status:** [~]
- **Problem:** `SupabaseConfig` hardcoded a single project URL/key, so all local development and testing hit production data.
- **Work done:**
  - `lib/core/config/supabase_config.dart` now branches on a compile-time `SUPABASE_ENV` `--dart-define` (`local` by default, `prod` opt-in) instead of a single hardcoded pair.
  - A full local Supabase stack (Postgres/Auth/Storage/Studio, run via the Supabase CLI + Docker/Colima) is now the default `flutter run` target — see the new "Local Supabase stack" section in `CLAUDE.md`.
  - Added a baseline schema migration (`supabase/migrations/20260919000000_remote_schema.sql`, hand-captured from the remote project via the Supabase MCP tools since `supabase login`/`db pull` needed interactive browser auth unavailable in this environment) so `supabase db reset` now replays the full schema (`profiles`, `meal_logs`, `food-images` bucket + RLS) from scratch, not just the two incremental `alter table` migrations that existed before.
  - Added `supabase/seed.sql` (auto-applied on `supabase db reset`) seeding a dev user (`dev@example.com`/`password123`) with a profile and sample meal logs.
  - `supabase/config.toml` filled out with full `[api]`/`[db]`/`[studio]`/`[auth]`/etc. sections; local auth email confirmation disabled for lower-friction dev sign-up.
  - `analyze-food` can now be served locally too (`supabase functions serve analyze-food --env-file supabase/functions/.env`), still calling the real Gemini API.
- **Follow-up still open:** this only covers *local* vs. *prod* — a separate hosted **staging** Supabase project (for QA/PR-preview environments distinct from a developer's own machine) is not set up.
- **Expected result:** Development and testing no longer touch production data by default; environments are switchable at build time via `--dart-define=SUPABASE_ENV=prod`.

---

## 4. Fitness tracker / wearable integration (Google Fit / Apple Health)

### 4.1 Add a `FitnessRepository` domain interface and `health`-package-backed implementation
- **Status:** [ ]
- **Problem:** The app only tracks calories consumed; it has no visibility into activity (steps, active energy burned, workouts), so calorie targets/`PlanScreen` can't account for exercise, and there's no story for syncing with a phone's step counter, an Apple Watch, or a Wear OS/Fitbit-class band.
- **Work:**
  - Add the `health` package (wraps Apple HealthKit on iOS and Health Connect on Android — Google's replacement for the deprecated Google Fit API; both platforms funnel wearable data, e.g. Apple Watch or a Wear OS band, into these same platform stores, so the app never talks to a specific wearable vendor directly).
  - New domain layer (mirroring `meal_log`): `lib/features/fitness/domain/entities/daily_activity.dart` (`steps`, `activeEnergyBurnedKcal`, `date`) and `lib/features/fitness/domain/repositories/fitness_repository.dart` with methods like `Future<bool> requestPermissions()` and `Future<DailyActivity> getTodayActivity()`.
  - `lib/features/fitness/data/repositories/health_fitness_repository_impl.dart` implements it against the `health` package's `Health()` client.
  - Platform setup: iOS `Info.plist` `NSHealthShareUsageDescription`/`NSHealthUpdateUsageDescription` + HealthKit capability in Xcode project; Android `AndroidManifest.xml` Health Connect permissions (`android.permission.health.READ_STEPS`, `READ_ACTIVE_CALORIES_BURNED`) and a check for the Health Connect app being installed (prompt to install from Play Store if missing, same pattern the `health` package's example app uses).
  - Read-only for this milestone — no writing meal data back into HealthKit/Health Connect yet (see 4.3).
- **Expected result:** The app can, with user consent, read today's step count and active-energy-burned from whichever platform health store the OS aggregates wearable data into (Apple Watch on iOS, Wear OS/most Android bands via Health Connect), independent of the specific device brand.

### 4.2 Surface activity data in the UI and factor it into the calorie budget
- **Status:** [ ]
- **Problem:** `CalorieRing`/`MacroRing` on `HomeScreen` currently only reflect calories logged from meals; there's no "calories burned" adjustment, which is the main reason users want fitness-tracker sync in a calorie app.
- **Work:**
  - Add a permission-request/opt-in flow (e.g. a card on `HomeScreen` or a `SettingsScreen` toggle — `lib/features/settings/` already exists) since HealthKit/Health Connect both require explicit user consent per data type.
  - Extend `MealLogState`/`MealLogNotifier` (or a new `fitnessProvider`) to hold today's `DailyActivity` and expose an adjusted "remaining calories" figure (`dailyCalorieTarget - consumed + activeEnergyBurnedKcal`, following the common "eat back your exercise calories" pattern — confirm with product whether that offset should be on by default or opt-in).
  - Show steps/active calories as a small stat alongside the existing rings, refreshed on pull-to-refresh/app resume rather than a continuous background sync (avoids `WorkManager`/`BGTaskScheduler` complexity for v1).
- **Expected result:** Users who grant permission see their burned calories reflected in their daily budget without leaving the app.

### 4.3 (Stretch) Write confirmed meal logs back into HealthKit / Health Connect nutrition records
- **Status:** [ ]
- **Problem:** Some users track everything from one place (Apple Health/Google Fit as the hub) and would want this app's meal logs to appear there too, not just read activity data one-way.
- **Work:** On `ConfirmMealLogUseCase` success, optionally call `Health().writeMeal(...)` (calories + macros) if the user has opted in and granted write permission for nutrition data types.
- **Expected result:** Confirmed meals are mirrored into the platform health store for users who want a single aggregated view.

### 4.4 Tests
- **Status:** [ ]
- **Problem:** `FitnessRepository` needs the same unit-test coverage convention as the rest of the domain layer (mocktail against the abstract interface, no real platform calls).
- **Work:** Add `test/features/fitness/` covering the calorie-budget-adjustment logic and repository error mapping (permission-denied, Health Connect not installed) as `AppException` subtypes, consistent with 3.1/3.2.
- **Expected result:** Activity-sync logic is regression-tested without needing a device/simulator with HealthKit or Health Connect installed.

---

## Suggested execution order

1. 1.3 → 1.4 → 1.5 (one migration covers schema versioning, RLS fix, and index)
2. 1.2 (edge function lockdown)
3. 1.1 (real auth)
4. 3.1 (storage cleanup — depends on nothing above, can run in parallel)
5. 3.2, 3.3, 3.4 (quality-of-life, can run in parallel)
6. 2.1, 2.2, 2.3, 3.5, 3.6 (as capacity allows)
7. Section 4 (fitness tracker sync) is a new-feature track, independent of the production-readiness items above — sequence it whenever product priority calls for it, not blocked by 1.x-3.x
