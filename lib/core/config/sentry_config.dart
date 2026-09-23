/// Sentry crash-reporting config. A DSN only lets a client *send* events to
/// this project — unlike `SupabaseConfig`'s service-role-style secrets, it's
/// safe to ship in the client, so (mirroring `SupabaseConfig._prodAnonKey`)
/// it's a hardcoded constant here rather than routed through a dart_define.
class SentryConfig {
  static const String dsn =
      'https://8f2188c8af7667f173682852d08649be@o4512137086369792.ingest.us.sentry.io/4512137108193280';

  /// Reuses the existing `SUPABASE_ENV` define (`local`/`prod`) as Sentry's
  /// environment tag, rather than introducing a second env switch — local
  /// dev runs still report (useful for verifying the integration works),
  /// just tagged distinctly so they're filterable in the Sentry dashboard.
  static const String environment = String.fromEnvironment(
    'SUPABASE_ENV',
    defaultValue: 'local',
  );
}
