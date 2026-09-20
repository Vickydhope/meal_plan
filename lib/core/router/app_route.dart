/// Every named destination in the app, paired with its go_router path.
/// Navigation call sites reference [name]/[path] through this enum rather
/// than raw string literals.
enum AppRoute {
  landing('/landing'),
  onboarding('/onboarding'),
  authLoading('/loading'),
  home('/home'),
  askAi('/ask-ai'),
  plan('/plan'),
  cameraScan('/camera-scan'),
  settings('/settings'),
  notifications('/notifications'),
  profile('/profile');

  const AppRoute(this.path);

  final String path;
}
