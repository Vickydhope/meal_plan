# Tasks

## Active

- [ ] **(Stretch) Write confirmed meal logs back into HealthKit/Health Connect** - read-only activity sync ships first (§4.1-4.2); this is the write-back follow-up
  - plan.md §4.3

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
