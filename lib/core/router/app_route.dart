/// Every named destination in the app, paired with its go_router path.
/// Navigation call sites reference [name]/[path] through this enum rather
/// than raw string literals.
enum AppRoute {
  login('/login'),
  signup('/signup'),
  forgotPassword('/forgot-password'),
  resetPassword('/reset-password'),
  onboarding('/onboarding'),
  splash('/splash'),
  home('/home'),
  askAi('/ask-ai'),
  plan('/plan'),
  cameraScan('/camera-scan'),
  barcodeScan('/barcode-scan'),
  scanResult('/scan-result'),
  settings('/settings'),
  notifications('/notifications'),
  profile('/profile'),
  nutritionGoals('/nutrition-goals'),
  trends('/trends'),
  privacyPolicy('/privacy-policy');

  const AppRoute(this.path);

  final String path;
}
