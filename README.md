<p align="center">
  <img src="assets/logos/app_logo.png" alt="Cravia logo" width="160">
</p>

<h1 align="center">Cravia</h1>

<p align="center"><b>Snap a photo. Know your calories. Hit your goals.</b></p>

<p align="center">Cravia turns the most tedious part of tracking nutrition — logging what you eat — into a five-second photo. No searching food databases, no guessing portion sizes. Point your camera at your plate and let AI do the counting, so you can stay consistent without the chore.</p>

## Why you'll love it

- 📸 **Snap & log in seconds** — photograph any meal and get an instant AI-powered breakdown of calories, macros, and a health score. No photo? Scan a packaged food's barcode or just describe what you ate. Review and tweak before you save — you're always in control.
- 🍽️ **Meal ideas that fit your day** — not sure what to eat next? The Plan tab suggests meals for the rest of today that fit the calories and macros you have left, shaped by your dietary preferences.
- 💬 **Ask AI, your nutrition coach in your pocket** — got a question about a food, a swap, or your progress? Just ask, and get a real answer, right in the app.
- 🎯 **A plan built around you** — tell us your body metrics, activity level, and goal, and Cravia calculates a personalized daily calorie and macro target — not a generic one-size-fits-all number.
- ⌚ **Works with Apple Health & Health Connect** — sync your steps and workouts for a calorie budget that grows with your activity, pull in your weight automatically, and write your meals back to Health.
- 📊 **See your progress at a glance** — a clean daily dashboard with calorie and macro rings, water tracking, and a weekly strip, plus 7- and 30-day trends for calories and weight.
- 🔔 **Stay on track** — meal reminders, streaks, and a weekly recap keep the habit going, and any past meal can be logged again with one tap.
- 👤 **Your plan, your way** — update your metrics or goal anytime, and choose a fixed daily goal or one that adjusts to how active you've been.
- 🔒 **Your data, everywhere you go** — sign in once and your meal history follows you across devices.

Whether you're cutting, bulking, or just trying to eat a little more mindfully, Cravia removes the friction so tracking actually sticks.

## Screenshots

<p align="center">
  <img src="screenshots/app_mockup.jpeg" alt="Cravia app mockup" width="800">
</p>

<p align="center">
  <img src="screenshots/cravia_home.jpg" alt="Home dashboard" width="200">
  <img src="screenshots/cravia_scan.jpg" alt="Scan a meal" width="200">
  <img src="screenshots/cravia_result.jpg" alt="Scan result" width="200">
  <img src="screenshots/cravia_chat.jpg" alt="Ask AI chat" width="200">
</p>

<p align="center">
  <img src="screenshots/cravia_plan.jpg" alt="Nutrition goals" width="200">
  <img src="screenshots/cravia_notification.jpg" alt="Notifications" width="200">
  <img src="screenshots/cravia_settings.jpg" alt="Settings" width="200">
</p>

## Tech stack

- **Flutter** (Dart) — cross-platform mobile client, Android/iOS build flavors (dev/prod).
- **Riverpod** — state management and dependency injection.
- **go_router** — navigation.
- **Clean architecture** — domain/data/presentation layers per feature.
- **Supabase** — Postgres database, Auth, Storage.
- **Supabase Edge Functions** (Deno/TypeScript) — server-side AI orchestration.
- **Gemini** — meal photo analysis, meal ideas, and chat responses.
- **health** — Apple Health / Health Connect sync (activity, weight, meal write-back).
- **mobile_scanner** + **Open Food Facts** — barcode scanning and packaged-food nutrition.
- **flutter_local_notifications** — meal reminders.
- **fl_chart** — trend charts (the calorie and macro rings are custom-painted).
- **Sentry** — crash reporting.
- **mocktail** — unit testing of domain use cases.