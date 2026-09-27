# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Flutter calorie-tracking app ("Cravia"). Users snap a photo of a meal, it's uploaded to Supabase Storage and sent to a Supabase Edge Function that calls Gemini for nutrition analysis, and the result is reviewed/edited before being saved as a meal log row.

## Commands

```bash
flutter pub get                     # install dependencies
flutter analyze                     # static analysis (flutter_lints)
flutter test                        # run all tests
flutter test test/path/to/file.dart # run a single test file
deno test supabase/functions        # edge function unit tests (no local deno? docker run --rm -v "$PWD":/app -w /app denoland/deno deno test supabase/functions)
supabase test db                    # pgTAP database tests in supabase/tests (needs the local stack running)
scripts/check_architecture.sh       # grep-based guard: domain purity, no hardcoded fontSize/Color(0x...) outside core/theme, no data-layer construction outside providers
scripts/run_dev.sh                  # run the dev flavor (local Supabase stack) on a connected device/simulator
scripts/run_prod.sh                 # run the prod flavor (live Supabase project) on a connected device/simulator
```

The app uses Android/iOS build flavors (`dev`/`prod`) — `--flavor` is required for `flutter run`/`flutter build` now that `productFlavors` exist. `dev` and `prod` install side-by-side (separate applicationId/bundle id, "[Dev]Cravia" vs "Cravia" display name). `scripts/run_dev.sh`/`run_prod.sh` wrap the full `--flavor` + `--dart-define-from-file` invocation; the equivalent explicit form is `flutter run --flavor dev --dart-define-from-file=dart_defines/dev.json` / `--flavor prod --dart-define-from-file=dart_defines/prod.json`.

Tests live under `test/`, mirroring the `lib/` path of what they cover. Domain use cases and repositories are tested with `mocktail` mocks against the abstract repository interfaces — no real Supabase/network calls in unit tests.

### Supabase Edge Function (`supabase/functions/analyze-food`)

Deployed via the Supabase MCP tools or `supabase functions deploy analyze-food`. Requires the `GEMINI_API_KEY` secret to be set in the Supabase project. Written in Deno/TypeScript.

### Local Supabase stack

Requires Docker (or a Docker-API-compatible runtime like Colima) running, and the Supabase CLI (`brew install supabase/tap/supabase`).

```bash
supabase start                                                            # boot local Postgres/Auth/Storage/Studio
supabase stop                                                             # tear it down
supabase db reset                                                        # drop, re-run all migrations, re-run seed.sql
supabase functions serve analyze-food --env-file supabase/functions/.env # serve the edge function locally, real Gemini calls
scripts/run_dev.sh                                                        # dev flavor, local Supabase stack
scripts/run_prod.sh                                                       # prod flavor, live Supabase project
# equivalent explicit form:
flutter run --flavor dev  --dart-define-from-file=dart_defines/dev.json
flutter run --flavor prod --dart-define-from-file=dart_defines/prod.json
```

`127.0.0.1` only reaches the local stack from the same machine — override the host for other run targets via `SUPABASE_LOCAL_HOST`:

```bash
flutter run --flavor dev --dart-define-from-file=dart_defines/dev.json --dart-define=SUPABASE_LOCAL_HOST=10.0.2.2       # Android emulator
flutter run --flavor dev --dart-define-from-file=dart_defines/dev.json --dart-define=SUPABASE_LOCAL_HOST=192.168.1.6    # physical device, same Wi-Fi as this Mac — use `ipconfig getifaddr en0` to find your current IP
```

`supabase/functions/.env` (gitignored, not committed) must contain your own `GEMINI_API_KEY=...` for locally-served function calls to reach Gemini. Studio UI: http://127.0.0.1:54323. Inbucket (test email catcher; only relevant if `enable_confirmations` is re-enabled in `supabase/config.toml`): http://127.0.0.1:54324. Seeded login (from `supabase/seed.sql`, applied on `supabase db reset`): `dev@example.com` / `password123`.

## Architecture

The app follows **clean architecture**: each feature is split into `domain` (business rules, no Flutter/Supabase imports), `data` (implements domain interfaces against Supabase), and `presentation` (Riverpod state + widgets). Dependencies only point inward — `presentation` depends on `domain`, `data` depends on `domain`, but `domain` depends on nothing in this app.

```
lib/
  main.dart                    # the only place that touches Supabase.initialize / Supabase.instance
  app/router/                  # app-level wiring, may import every feature: app_router.dart, router_refresh_notifier.dart, splash_screen.dart
  core/                        # cross-cutting, not specific to any feature — must never import a feature
    config/                    # supabase_config.dart, sentry_config.dart
    error/app_exception.dart   # AppException hierarchy thrown by repositories
    providers/core_providers.dart  # supabaseClientProvider
    router/app_route.dart      # AppRoute enum (name + path) — the one router file features import
    theme/                     # app_colors, app_typography, app_spacing tokens
  features/auth/
    domain/repositories/auth_repository.dart        # AuthRepository interface
    data/repositories/supabase_auth_repository.dart # SupabaseAuthRepository impl
    presentation/
      providers/auth_providers.dart  # authRepositoryProvider, authUserIdProvider
      widgets/auth_form_card.dart    # shared email/password form chrome
      screens/                       # LoginScreen, SignupScreen (separate screens, not a mode toggle), ForgotPasswordScreen, ResetPasswordScreen (router parks here while passwordRecoveryProvider is true)
  features/meal_log/
    domain/
      entities/                # MealLog, MealAnalysisItem, PendingMealAnalysis, MealType, MealAnalysisStreamEvent
      repositories/            # abstract MealLogRepository, ImageRepository, FoodAnalysisRepository, ProductRepository
      usecases/                # one class per operation, e.g. AnalyzeMealPhotoUseCase, ConfirmMealLogUseCase
    data/
      models/                  # DTOs: fromMap/toMap <-> toEntity/fromEntity conversions
      datasources/             # thin wrappers around SupabaseClient / flutter_image_compress
      repositories/            # *RepositoryImpl, implement the domain interfaces
    presentation/
      state/                   # MealLogState, ScanSessionState
      notifiers/               # MealLogNotifier (the day's logs), ScanSessionNotifier (scan → review → confirm); use cases + AuthRepository only
      providers/meal_log_providers.dart  # DI wiring: binds datasource -> repo -> usecase -> notifier
      screens/                 # HomeScreen, CameraScanScreen, BarcodeScanScreen, ScanResultScreen, TrendsScreen, edit_meal_sheet
        camera_scan/           # ScanResultScreen's parts (camera frame, ingredients, nutrition card, phase)
        home/                  # HomeScreen's meal sections (section cards, rows, swipe-to-delete, relog sheet)
  features/profile/            # UserProfile + enums, ProfileRepository, AvatarRepository, calorie-target calculation, ProfileScreen
  features/nutrition_goals/    # NutritionGoalsScreen only (presentation) — composes profile, onboarding step widgets and fitness
  features/meal_suggestions/   # PlanScreen + meal ideas, backed by the suggest-meals edge function
  features/…                   # app_shell, ask_ai, fitness, hydration, notifications, onboarding, settings — same layering
  shared/widgets/              # CalorieRing, MacroRing, WeekStrip, ShimmerBox, snackbars — presentation-only, feature-agnostic
```

**Dependency injection** is done with Riverpod providers, not a separate service locator: `core/providers/core_providers.dart` and each feature's `presentation/providers/*_providers.dart` are the composition root, wiring concrete `data` implementations to the `domain` interfaces the `presentation` layer and use cases depend on. A `Notifier` pulls its dependencies from providers via its own `ref` (not constructor injection — `NotifierProvider` only supports a zero-arg constructor).

**Client → Storage → Edge Function → Gemini** is the core data flow for meal logging:

1. `CameraScanScreen` captures a photo with `package:camera`.
2. `ScanSessionNotifier.analyzeCapturedPhoto` calls `AnalyzeMealPhotoUseCase`, which compresses the photo client-side to under 200KB JPEG (`ImageRepository.compressImage`), uploads it to the `food-images` Storage bucket under `<userId>/<timestamp>.jpg`, then calls the `analyze-food` Edge Function via `FoodAnalysisRepository.analyze`.
3. The Edge Function (`supabase/functions/analyze-food/index.ts`) forwards the image to Gemini with a fixed JSON response schema (meal name, per-item macros, health score), retrying on `429`/`503` with exponential backoff (up to 3 attempts).
4. The result becomes a `PendingMealAnalysis` entity — *not* yet persisted. The user reviews/edits it on `ScanResultScreen` (adjust meal name, per-ingredient portion multipliers via `MealAnalysisItem.portion`) before confirming.
5. `ScanSessionNotifier.confirm` hands the reviewed meal to `MealLogNotifier.logMeal`, whose `ConfirmMealLogUseCase` inserts the finalized totals into the `meal_logs` table via `MealLogRepository`. `DiscardPendingMealUseCase` removes the orphaned Storage upload if the user backs out.

**State management**: Riverpod (`flutter_riverpod`). `mealLogProvider` (`MealLogNotifier`/`MealLogState`) holds the selected day's logs and their CRUD side effects (Health mirror; bumping `mealLogChangesProvider`, which reminders and the notification feed watch); `scanSessionProvider` (`ScanSessionNotifier`/`ScanSessionState`) holds one scan → review session and hands the confirmed meal to `MealLogNotifier.logMeal`. Profile data (name, avatar, `dailyCalorieTargetProvider`) is read from `profile_providers.dart`, never copied into meal-log state. Notifiers are thin orchestrators — all Supabase-specific logic lives in `data/`.

**Backend**: Supabase Postgres with `meal_logs` and `profiles` tables (see `MealLogDto` in `meal_log/data/models/` and `UserProfileDto` in `profile/data/models/` for the expected schema, and `supabase/migrations/` for the versioned schema — a `supabase db reset` against the local stack replays these from scratch). Auth is email/password (`AuthRepository.signUpWithEmail`/`signInWithEmail`/`signOut`, `lib/features/auth/`), reactively gated via `AuthRepository.userIdChanges` in the router. `LoginScreen` and `SignupScreen` are separate top-level routes (`AppRoute.login`/`AppRoute.signup`) sharing visual chrome via `AuthFormCard`, not one screen toggling between modes. `main.dart` is the only place allowed to touch `Supabase.initialize`/`Supabase.instance` directly — everywhere else goes through `core/providers/core_providers.dart`.

**Navigation**: `go_router` (`lib/app/router/app_router.dart`), gated by a `redirect` callback that branches on auth state (`authUserIdProvider`) and onboarding completion (`currentUserProfileProvider`), refreshed via `router_refresh_notifier.dart`. While either is still loading, the router parks on `SplashScreen` (`lib/app/router/splash_screen.dart`, mirrors the native launch screen). Every destination is a case of the `AppRoute` enum (`lib/core/router/app_route.dart`) pairing a name with its path — call sites navigate via `AppRoute.x.name`/`.path`, never a raw string literal. `AppShell` (bottom-nav tabs `HomeScreen`/`AskAiScreen`/`PlanScreen` plus a center camera FAB) is a `StatefulShellRoute.indexedStack` branch; `CameraScanScreen`, `BarcodeScanScreen`, `ScanResultScreen`, `SettingsScreen`, `NotificationsScreen`, `ProfileScreen`, `NutritionGoalsScreen`, and `TrendsScreen` are top-level routes pushed above the shell. Raw `Navigator.of(context)` is only used for local dialog/sheet dismissal (`.pop()`), never for route navigation.

**Dependency direction**: `core` never imports a feature, and `lib/app/` is the only place allowed to import all of them. Across features, `domain`/`data` dependencies only point one way (`fitness`, `meal_suggestions`, `notifications` → `meal_log`; `fitness`, `meal_suggestions` → `profile`) — keep it that way, and put a screen that composes several features in its own presentation-only feature (like `nutrition_goals`) rather than creating a cycle. When a downstream feature needs to react to meal changes, it watches `mealLogChangesProvider`; `meal_log` doesn't reach into it. (Graphify's "Import Cycles" check can't see Dart relative imports, so it will always report none — don't rely on it.)

**Adding a new feature**: mirror the `meal_log` structure — domain entities/repositories/usecases first (pure Dart), then data DTOs/datasources/repository impls, then presentation state/notifier/providers/screens. Keep `domain` free of Flutter and Supabase imports so use cases stay unit-testable without mocks for infra.

`PlanScreen` (the Plan tab) shows AI meal ideas for the rest of today (`lib/features/meal_suggestions/`, backed by the `suggest-meals` edge function) plus a summary of the user's targets; the targets themselves are edited on `NutritionGoalsScreen` (pushed from the Plan tab or Settings).

## Config

- `lib/core/config/supabase_config.dart` selects the Supabase URL/publishable (anon) key at build time via `--dart-define=SUPABASE_ENV=local|prod` (defaults to `local`) — both keys are anon keys, safe to be client-side. Normally supplied via `dart_defines/dev.json`/`dart_defines/prod.json` + the matching `--flavor` (or `scripts/run_dev.sh`/`run_prod.sh`); a manual `--dart-define=SUPABASE_ENV=...` still works as an override.
- The Gemini API key lives only as a Supabase Edge Function secret (or, for local dev, `supabase/functions/.env`), never in the Flutter client.
