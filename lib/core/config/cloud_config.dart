/// Build-time configuration for optional Supabase Cloud Sync and Google Sign-In.
///
/// Supply values via `--dart-define` at build/run time so credentials are never
/// hardcoded into source control:
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_URL=https://<project>.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=<anon-key> \
///   --dart-define=GOOGLE_WEB_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
/// ```
abstract final class CloudConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// `true` when both Supabase URL and Anon Key are supplied via `--dart-define`.
  static bool get isSupabaseConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  /// `true` when Supabase and Google Web Client ID are configured.
  static bool get isGoogleSignInConfigured =>
      isSupabaseConfigured && googleWebClientId.trim().isNotEmpty;
}
