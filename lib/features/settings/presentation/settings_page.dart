import 'package:flutter/material.dart';

import '../../../core/services/auth_repository.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/local_monitoring_session_repository.dart';
import '../../../core/services/monitoring_session_repository.dart';
import '../../../core/services/session_sync_service.dart';
import '../../../core/services/supabase_session_repository.dart';
import '../../../core/widgets/app_section_card.dart';
import '../application/settings_service.dart';

/// Settings, telemetry baseline configuration, appearance, and local storage management page.
///
/// **Non-Diagnostic Notice**: All parameters configured here represent engineering
/// research baselines and simulation parameters. They are strictly non-clinical.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.authRepository,
    this.onSignOut,
    this.settingsService,
    this.repository,
    this.syncService,
  });

  final AuthRepository? authRepository;
  final VoidCallback? onSignOut;
  final SettingsService? settingsService;
  final MonitoringSessionRepository? repository;
  final SessionSyncService? syncService;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsService _settingsService;
  bool _ownsService = false;
  int _localSessionCount = 0;
  bool _loadingSessionCount = true;

  AuthRepository get _auth => widget.authRepository ?? AuthService();

  @override
  void initState() {
    super.initState();
    if (widget.settingsService != null) {
      _settingsService = widget.settingsService!;
    } else {
      _settingsService = SettingsService(isInitialized: true);
      _ownsService = true;
    }
    _settingsService.addListener(_onSettingsChanged);
    _refreshSessionCount();
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settingsService != widget.settingsService) {
      oldWidget.settingsService?.removeListener(_onSettingsChanged);
      if (widget.settingsService != null) {
        _settingsService = widget.settingsService!;
        _ownsService = false;
      }
      _settingsService.addListener(_onSettingsChanged);
    }
    if (oldWidget.repository != widget.repository) {
      _refreshSessionCount();
    }
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged);
    if (_ownsService) {
      _settingsService.dispose();
    }
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshSessionCount() async {
    if (widget.repository == null) {
      if (mounted) {
        setState(() {
          _localSessionCount = 0;
          _loadingSessionCount = false;
        });
      }
      return;
    }
    try {
      final sessions = await widget.repository!.getSessions();
      if (mounted) {
        setState(() {
          _localSessionCount = sessions.length;
          _loadingSessionCount = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _localSessionCount = 0;
          _loadingSessionCount = false;
        });
      }
    }
  }

  Future<void> _clearLocalCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Local Sessions?'),
        content: const Text(
          'This will remove all locally stored monitoring sessions and telemetry caches. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_clear_cache_button'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final repo = widget.repository;
      if (repo is LocalMonitoringSessionRepository) {
        repo.clear();
      } else if (repo is SupabaseMonitoringSessionRepository) {
        repo.localFallback?.clear();
      } else if (repo != null) {
        final sessions = await repo.getSessions();
        for (final s in sessions) {
          await repo.deleteSession(s.id);
        }
      }

      await _refreshSessionCount();
      messenger.showSnackBar(
        const SnackBar(content: Text('Local session cache cleared.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final settings = _settingsService.settings;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 24),

            // ── 1. Account & Cloud Section ─────────────────────────────────────
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withAlpha(25),
                      child: Icon(
                        Icons.account_circle_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      user != null ? 'Account' : 'Account (Demo Mode)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      user?.email ??
                          'Offline session — not signed in to Supabase cloud.',
                    ),
                    trailing: OutlinedButton(
                      key: const Key('settings_sign_out_button'),
                      onPressed: widget.onSignOut,
                      child: Text(user != null ? 'Sign Out' : 'Sign In'),
                    ),
                  ),
                  const Divider(height: 24),
                  SwitchListTile.adaptive(
                    key: const Key('auto_cloud_sync_switch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Auto Cloud Sync',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Automatically synchronize completed monitoring sessions with Supabase cloud.',
                    ),
                    value: settings.autoCloudSync,
                    onChanged: (val) {
                      _settingsService.updateAutoCloudSync(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 2. Monitoring Preferences & Research Thresholds ───────────────
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.tune_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Monitoring preferences',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Configure experimental telemetry baseline thresholds. '
                    'These parameters govern exposure calculations and are strictly non-diagnostic.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Force Threshold Slider
                  _buildSliderTile(
                    title: 'Force Exceedance Threshold',
                    currentDisplay: '${settings.forceThreshold.toStringAsFixed(1)} N',
                    description:
                        'Minimum force considered a biomechanical exposure event.',
                    value: settings.forceThreshold,
                    min: 0.5,
                    max: 10.0,
                    divisions: 19,
                    onChanged: (v) => _settingsService.updateForceThreshold(v),
                    minLabel: '0.5 N',
                    maxLabel: '10.0 N',
                    theme: theme,
                  ),
                  const SizedBox(height: 16),

                  // Angular Velocity Threshold Slider
                  _buildSliderTile(
                    title: 'Angular Velocity Threshold',
                    currentDisplay:
                        '${settings.angularVelocityThreshold.toStringAsFixed(0)} °/s',
                    description:
                        'Velocity threshold for categorizing rapid motion dynamics.',
                    value: settings.angularVelocityThreshold,
                    min: 10.0,
                    max: 150.0,
                    divisions: 28,
                    onChanged: (v) =>
                        _settingsService.updateAngularVelocityThreshold(v),
                    minLabel: '10 °/s',
                    maxLabel: '150 °/s',
                    theme: theme,
                  ),
                  const SizedBox(height: 16),

                  // Movement Frequency Baseline Slider
                  _buildSliderTile(
                    title: 'Reference Movement Frequency',
                    currentDisplay:
                        '${settings.refMovementsPerMinute.toStringAsFixed(0)} /min',
                    description:
                        'Normalization denominator for research exposure frequency index.',
                    value: settings.refMovementsPerMinute,
                    min: 10.0,
                    max: 80.0,
                    divisions: 14,
                    onChanged: (v) =>
                        _settingsService.updateRefMovementsPerMinute(v),
                    minLabel: '10 /min',
                    maxLabel: '80 /min',
                    theme: theme,
                  ),
                  const SizedBox(height: 20),

                  // Reset Defaults Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      key: const Key('reset_settings_button'),
                      icon: const Icon(Icons.restore, size: 18),
                      label: const Text('Reset to Research Defaults'),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await _settingsService.resetToDefaults();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Settings reset to research default baselines.',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 3. Appearance Section ──────────────────────────────────────────
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.palette_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Appearance',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Customize application theme mode for lab and field readability.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto, size: 18),
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_outlined, size: 18),
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_outlined, size: 18),
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (Set<ThemeMode> newSelection) {
                        _settingsService.updateThemeMode(newSelection.first);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 4. Local Data & Cache Management ──────────────────────────────
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.storage_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Local Storage & Cache',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Manage locally recorded sessions and time-series telemetry.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Stored Sessions'),
                    subtitle: Text(
                      _loadingSessionCount
                          ? 'Checking storage...'
                          : '$_localSessionCount completed session(s) persisted locally.',
                    ),
                    trailing: OutlinedButton.icon(
                      key: const Key('clear_cache_button'),
                      icon: Icon(
                        Icons.delete_sweep_outlined,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      label: Text(
                        'Clear Cache',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                      onPressed: _clearLocalCache,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 5. About & Research Disclaimer ─────────────────────────────────
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.science_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'About this project',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('Software Version', '1.0.0 (Research Prototype)'),
                  const SizedBox(height: 6),
                  _buildInfoRow('Telemetry Stream', 'Simulated (DemoSensorService)'),
                  const SizedBox(height: 6),
                  _buildInfoRow('Target Subsystem', 'Thumb MCP/IP Kinematics'),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF262118)
                          : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF6B5829)
                            : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: isDark
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Engineering Research Prototype: Developed for biomechanical '
                            'telemetry acquisition and joint kinematics analysis. '
                            'Does not provide medical diagnoses, clinical risk assessment, '
                            'or therapeutic recommendations.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0xFF92400E),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String currentDisplay,
    required String description,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String minLabel,
    required String maxLabel,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                currentDisplay,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.white60 : Colors.black45,
          ),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                minLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 11,
                ),
              ),
              Text(
                maxLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ],
      );
}
