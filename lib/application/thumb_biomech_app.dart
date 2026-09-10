import 'package:flutter/material.dart';

import '../core/services/auth_repository.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../features/settings/application/settings_service.dart';

class ThumbBiomechApp extends StatefulWidget {
  const ThumbBiomechApp({
    super.key,
    this.authRepository,
    this.initialDemoMode,
    this.settingsService,
  });

  final AuthRepository? authRepository;
  final bool? initialDemoMode;
  final SettingsService? settingsService;

  @override
  State<ThumbBiomechApp> createState() => _ThumbBiomechAppState();
}

class _ThumbBiomechAppState extends State<ThumbBiomechApp> {
  late final SettingsService _settingsService;
  bool _ownsService = false;

  @override
  void initState() {
    super.initState();
    if (widget.settingsService != null) {
      _settingsService = widget.settingsService!;
    } else {
      _settingsService = SettingsService();
      _ownsService = true;
      _settingsService.init();
    }
  }

  @override
  void dispose() {
    if (_ownsService) {
      _settingsService.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _settingsService,
    builder: (context, _) => MaterialApp(
      title: 'ThumbBiomech Monitor Glove',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _settingsService.settings.themeMode,
      home: AuthGate(
        authRepository: widget.authRepository,
        initialDemoMode: widget.initialDemoMode,
      ),
    ),
  );
}
