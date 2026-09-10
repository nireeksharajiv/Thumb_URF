import 'package:flutter/widgets.dart';

import '../core/config/supabase_config.dart';
import '../core/services/supabase_service.dart';
import 'thumb_biomech_app.dart';

/// Prepares core services and returns whether Supabase was initialized.
Future<bool> initApplicationServices({SupabaseConfig? supabaseConfig}) async {
  WidgetsFlutterBinding.ensureInitialized();
  return SupabaseService.instance.initialize(config: supabaseConfig);
}

/// Initializes core application infrastructure before launching the root widget.
///
/// Ensures Flutter bindings are bound and Supabase is initialized before [runApp]
/// when valid credentials are provided. If unconfigured, the app falls back
/// gracefully to offline / Demo Mode.
Future<void> bootstrap({SupabaseConfig? supabaseConfig}) async {
  await initApplicationServices(supabaseConfig: supabaseConfig);
  runApp(const ThumbBiomechApp());
}
