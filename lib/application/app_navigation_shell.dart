import 'package:flutter/material.dart';

import '../core/services/auth_repository.dart';
import '../core/services/demo_sensor_service.dart';
import '../core/services/local_monitoring_session_repository.dart';
import '../core/services/monitoring_session_repository.dart';
import '../core/services/session_sync_service.dart';
import '../core/services/supabase_service.dart';
import '../core/services/supabase_session_repository.dart';
import '../features/analytics/presentation/analytics_page.dart';
import '../features/device/presentation/device_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/monitoring/application/monitoring_controller.dart';
import '../features/monitoring/presentation/live_monitoring_page.dart';
import '../features/recommendations/presentation/recommendations_page.dart';
import '../features/sessions/presentation/sessions_page.dart';
import '../features/settings/application/settings_service.dart';
import '../features/settings/presentation/settings_page.dart';
import '../services/ble/ble_sensor_service.dart';

enum AppSection {
  home,
  monitoring,
  device,
  sessions,
  analytics,
  recommendations,
  settings,
}

/// Root navigation shell.
///
/// Creates the [MonitoringSessionRepository] and [MonitoringController] once so that
/// a monitoring session survives navigation between tabs.
/// Automatically resolves [SupabaseMonitoringSessionRepository] when authenticated
/// or [LocalMonitoringSessionRepository] when running offline.
///
/// Primary navigation: Home · Monitor · Connect · Settings.
/// Sessions, Analytics, and Recommendations are secondary destinations
/// reached from Home and session flows.
class AppNavigationShell extends StatefulWidget {
  const AppNavigationShell({
    super.key,
    this.authRepository,
    this.onSignOut,
    this.repository,
    this.syncService,
    this.settingsService,
  });

  final AuthRepository? authRepository;
  final VoidCallback? onSignOut;
  final MonitoringSessionRepository? repository;
  final SessionSyncService? syncService;
  final SettingsService? settingsService;

  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell> {
  var _section = AppSection.home;

  // Shared services — outlive any individual page widget.
  late final MonitoringSessionRepository _repository;
  late final LocalMonitoringSessionRepository _localFallback;
  late final DemoSensorService _sensorService;
  late final MonitoringController _controller;
  SessionSyncService? _syncService;
  late final SettingsService _settingsService;
  bool _ownsSettings = false;
  late final BleSensorService _bleService;

  @override
  void initState() {
    super.initState();
    final local = LocalMonitoringSessionRepository();
    _localFallback = local;
    local.init();

    if (widget.repository != null) {
      _repository = widget.repository!;
    } else {
      final isAuth = widget.authRepository?.isAuthenticated ?? false;
      final isConfigured = SupabaseService.instance.isInitialized;
      if (isAuth && isConfigured) {
        _repository = SupabaseMonitoringSessionRepository(
          client: SupabaseService.instance.clientOrNull,
          authRepository: widget.authRepository,
          localFallback: local,
        );
      } else {
        _repository = local;
      }
    }

    if (widget.syncService != null) {
      _syncService = widget.syncService;
    } else {
      final cloudRepo = _repository is SupabaseMonitoringSessionRepository
          ? _repository
          : SupabaseMonitoringSessionRepository(
              client: SupabaseService.instance.clientOrNull,
              authRepository: widget.authRepository,
              localFallback: _localFallback,
            );
      _syncService = SessionSyncService(
        localRepository: _localFallback,
        cloudRepository: cloudRepo,
        authRepository: widget.authRepository,
      );
    }

    if (widget.settingsService != null) {
      _settingsService = widget.settingsService!;
    } else {
      _settingsService = SettingsService(isInitialized: true);
      _ownsSettings = true;
    }

    _sensorService = DemoSensorService();
    _bleService = BleSensorService();
    _controller = MonitoringController(
      _sensorService,
      repository: _repository,
      fallbackRepository: _localFallback,
      settingsService: _settingsService,
      syncService: _syncService,
      authRepository: widget.authRepository,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _sensorService.dispose();
    _bleService.dispose();
    if (widget.syncService == null) {
      _syncService?.dispose();
    }
    if (_repository is ChangeNotifier) {
      (_repository as ChangeNotifier).dispose();
    }
    if (_ownsSettings) {
      _settingsService.dispose();
    }
    super.dispose();
  }

  /// Maps the current [_section] to the bottom-nav selected index.
  /// Only the four primary tabs (home=0, monitor=1, connect=2, settings=3)
  /// are reflected in the bar; secondary sections keep the last primary index.
  int get _primaryIndex => switch (_section) {
    AppSection.home => 0,
    AppSection.monitoring => 1,
    AppSection.device => 2,
    _ => 3,
  };

  void _selectSection(AppSection section) =>
      setState(() => _section = section);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: switch (_section) {
      AppSection.home => HomePage(
          authRepository: widget.authRepository,
          repository: _repository,
          onNavigate: _selectSection,
          bleService: _bleService,
        ),
      AppSection.monitoring => LiveMonitoringPage(
          controller: _controller,
          repository: _repository,
          bleService: _bleService,
        ),
      AppSection.device => DevicePage(bleService: _bleService),
      AppSection.sessions => SessionsPage(
          repository: _repository,
          syncService: _syncService,
        ),
      AppSection.analytics => AnalyticsPage(
          repository: _repository,
          settingsService: _settingsService,
        ),
      AppSection.recommendations => RecommendationsPage(
          repository: _repository,
          settingsService: _settingsService,
        ),
      AppSection.settings => SettingsPage(
          authRepository: widget.authRepository,
          onSignOut: widget.onSignOut,
          settingsService: _settingsService,
          repository: _repository,
          syncService: _syncService,
        ),
    },
    bottomNavigationBar: NavigationBar(
      selectedIndex: _primaryIndex,
      onDestinationSelected: (index) => _selectSection(switch (index) {
        0 => AppSection.home,
        1 => AppSection.monitoring,
        2 => AppSection.device,
        _ => AppSection.settings,
      }),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.monitor_heart_outlined),
          selectedIcon: Icon(Icons.monitor_heart),
          label: 'Monitor',
        ),
        NavigationDestination(
          icon: Icon(Icons.bluetooth_outlined),
          selectedIcon: Icon(Icons.bluetooth),
          label: 'Connect',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    ),
  );
}
