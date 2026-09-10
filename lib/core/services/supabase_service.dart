import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../errors/supabase_exceptions.dart';

/// Centralized service managing the [SupabaseClient] lifecycle.
///
/// Ensures Supabase is initialized before application usage when credentials are
/// provided, while allowing the app to run completely offline/demo mode when
/// credentials are omitted.
class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  bool _isInitialized = false;
  SupabaseClient? _client;

  /// Whether Supabase has been initialized in this application process.
  bool get isInitialized => _isInitialized;

  /// Returns the current [SupabaseClient] if initialized, or `null` if unconfigured.
  SupabaseClient? get clientOrNull => _client;

  /// Returns the active [SupabaseClient], or throws a [SupabaseConfigException]
  /// if called before successful initialization.
  SupabaseClient get client {
    final c = _client;
    if (c == null) {
      throw const SupabaseConfigException(
        'Supabase is not initialized. Check your SUPABASE_URL and SUPABASE_ANON_KEY configuration.',
      );
    }
    return c;
  }

  /// Initializes the Supabase client if [config] is configured.
  ///
  /// Returns `true` if initialization succeeded, or `false` if unconfigured/skipped.
  /// This never throws; errors during initialization are caught, logged, and return `false`.
  Future<bool> initialize({SupabaseConfig? config}) async {
    final cfg = config ?? const SupabaseConfig();
    if (!cfg.isConfigured) {
      debugPrint('[SupabaseService] Unconfigured — continuing in offline / demo mode.');
      return false;
    }

    try {
      // ignore: deprecated_member_use
      final supabase = await Supabase.initialize(
        url: cfg.url.trim(),
        // ignore: deprecated_member_use
        anonKey: cfg.anonKey.trim(),
      );
      _client = supabase.client;
      _isInitialized = true;
      debugPrint('[SupabaseService] Supabase initialized successfully.');
      return true;
    } catch (e, st) {
      debugPrint('[SupabaseService] Initialization failed: $e\n$st');
      return false;
    }
  }

  /// Allows injecting a mock or fake [SupabaseClient] during automated tests.
  @visibleForTesting
  void setClientForTesting(SupabaseClient? testClient) {
    _client = testClient;
    _isInitialized = testClient != null;
  }
}
