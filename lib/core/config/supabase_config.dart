/// Supabase project config, selected at build/run time via `--dart-define`.
///
/// Defaults to the **local** Supabase stack (`supabase start`) so a bare
/// `flutter run` never touches production data. Point at prod explicitly:
///
///   flutter run --dart-define=SUPABASE_ENV=prod
///
/// `127.0.0.1` only reaches the local stack from the same machine (iOS
/// Simulator, desktop). Override the host for other targets:
///   - Android emulator: --dart-define=SUPABASE_LOCAL_HOST=10.0.2.2
///   - Physical device (same Wi-Fi as this Mac): --dart-define=SUPABASE_LOCAL_HOST=`your Mac's LAN IP, e.g. 192.168.1.6`
class SupabaseConfig {
  static const String _env = String.fromEnvironment(
    'SUPABASE_ENV',
    defaultValue: 'local',
  );

  static const String _localHost = String.fromEnvironment(
    'SUPABASE_LOCAL_HOST',
    defaultValue: '127.0.0.1',
  );
  static String get _localUrl => 'http://$_localHost:54321';
  // Fixed demo publishable key printed by every `supabase start` run against
  // this project's config.toml — not a secret, safe to commit.
  static const String _localAnonKey =
      'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';

  static const String _prodUrl = 'https://rchzdxmmvixeyoiulqsd.supabase.co';
  static const String _prodAnonKey =
      'sb_publishable_oWUh65jlz2e8MaTOAwLlcA_VvLVs6ul';

  static String get url => _env == 'prod' ? _prodUrl : _localUrl;
  static String get anonKey => _env == 'prod' ? _prodAnonKey : _localAnonKey;
}
