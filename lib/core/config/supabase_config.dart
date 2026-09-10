import '../errors/supabase_exceptions.dart';

/// Configuration holder for Supabase connection credentials.
///
/// Reads from compile-time environment defines by default:
/// - `SUPABASE_URL`: e.g. `https://your-project.supabase.co`
/// - `SUPABASE_ANON_KEY`: Supabase publishable/anon public key
///
/// Pass these at build/run time via:
/// ```bash
/// flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_ANON_KEY=your_anon_key
/// ```
///
/// Never provide a Supabase `service_role` key here.
class SupabaseConfig {
  /// Default project URL for the Thumb Biomechanics Monitor backend.
  static const String defaultProjectUrl =
      'https://sbwpabepmshbxsbxjddf.supabase.co';

  const SupabaseConfig({
    this.url = const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: defaultProjectUrl,
    ),
    String? anonKey,
    String? publishableKey,
  })  : anonKey = anonKey ??
            publishableKey ??
            const String.fromEnvironment(
              'SUPABASE_PUBLISHABLE_KEY',
              defaultValue: String.fromEnvironment(
                'SUPABASE_ANON_KEY',
                defaultValue: '',
              ),
            );

  /// Supabase project URL string, defaulting to the project URL or environment define.
  final String url;

  /// Supabase anonymous/publishable key, resolving from parameter or environment defines.
  final String anonKey;

  /// Alias for [anonKey] conforming to Supabase's publishable key terminology.
  String get publishableKey => anonKey;

  /// Whether valid non-empty configuration credentials have been supplied.
  bool get isConfigured {
    if (url.trim().isEmpty || anonKey.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.hasAuthority;
  }

  /// Validates the configuration and throws a [SupabaseConfigException] with
  /// troubleshooting instructions if invalid.
  void validate() {
    if (url.trim().isEmpty) {
      throw const SupabaseConfigException(
        'Missing Supabase URL. Provide it via --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co',
      );
    }
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        !uri.hasAuthority) {
      throw SupabaseConfigException(
        'Invalid Supabase URL "$url". Must be a valid http or https URL.',
      );
    }
    if (anonKey.trim().isEmpty) {
      throw const SupabaseConfigException(
        'Missing Supabase publishable/anon key. Provide it via --dart-define=SUPABASE_ANON_KEY=<key>',
      );
    }
  }
}
