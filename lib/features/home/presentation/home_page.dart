import 'package:flutter/material.dart';

import '../../../application/app_navigation_shell.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/monitoring_session.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/monitoring_session_repository.dart';

/// ThumbTrace command centre — the primary landing page after authentication.
///
/// Shows a dynamic greeting, device connection status, primary monitoring CTA,
/// the latest completed session, quick-access research destinations,
/// and a brief non-diagnostic research notice.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.authRepository,
    this.repository,
    this.onNavigate,
  });

  final AuthRepository? authRepository;
  final MonitoringSessionRepository? repository;
  final ValueChanged<AppSection>? onNavigate;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  MonitoringSession? _latestSession;
  bool _loadingSession = true;

  @override
  void initState() {
    super.initState();
    _loadLatestSession();
    widget.repository?.addListener(_onRepositoryChanged);
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      oldWidget.repository?.removeListener(_onRepositoryChanged);
      widget.repository?.addListener(_onRepositoryChanged);
      _loadLatestSession();
    }
  }

  @override
  void dispose() {
    widget.repository?.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  void _onRepositoryChanged() => _loadLatestSession();

  Future<void> _loadLatestSession() async {
    final repo = widget.repository;
    if (repo == null) {
      // No repository — mark loading done synchronously without triggering
      // an async I/O cycle that would cause pumpAndSettle to time out in tests.
      if (mounted) setState(() => _loadingSession = false);
      return;
    }
    try {
      final sessions = await repo.getSessions();
      if (!mounted) return;
      sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
      setState(() {
        _latestSession = sessions.isNotEmpty ? sessions.first : null;
        _loadingSession = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSession = false);
    }
  }

  /// Resolves a friendly display name from the authenticated user.
  ///
  /// Priority: full_name → name → email prefix → 'there'
  String get _displayName {
    final user = widget.authRepository?.currentUser;
    if (user == null) return 'there';
    final meta = user.userMetadata;
    if (meta != null) {
      final fullName = meta['full_name'] as String?;
      if (fullName != null && fullName.trim().isNotEmpty) {
        return fullName.trim().split(' ').first;
      }
      final name = meta['name'] as String?;
      if (name != null && name.trim().isNotEmpty) {
        return name.trim().split(' ').first;
      }
    }
    final email = user.email;
    if (email != null && email.contains('@')) {
      final prefix = email.split('@').first;
      if (prefix.isNotEmpty) return _capitalise(prefix);
    }
    return 'there';
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  void _navigate(AppSection section) => widget.onNavigate?.call(section);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(displayName: _displayName, theme: theme),
            const SizedBox(height: 24),
            _DeviceStatusCard(
              theme: theme,
              onConnect: () => _navigate(AppSection.device),
            ),
            const SizedBox(height: 16),
            _PrimaryCtaCard(
              theme: theme,
              onStartMonitoring: () => _navigate(AppSection.monitoring),
            ),
            const SizedBox(height: 24),
            _LatestSessionSection(
              theme: theme,
              loading: _loadingSession,
              session: _latestSession,
              onViewSession: () => _navigate(AppSection.sessions),
              onConnect: () => _navigate(AppSection.device),
            ),
            const SizedBox(height: 24),
            _ResearchQuickAccess(
              theme: theme,
              onSessions: () => _navigate(AppSection.sessions),
              onAnalytics: () => _navigate(AppSection.analytics),
              onRecommendations: () => _navigate(AppSection.recommendations),
            ),
            const SizedBox(height: 28),
            _ResearchNotice(theme: theme),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.displayName, required this.theme});
  final String displayName;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 6,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.appName,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                AppStrings.tagline,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(160),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 20),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, $displayName',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    ],
  );
}

class _DeviceStatusCard extends StatelessWidget {
  const _DeviceStatusCard({
    required this.theme,
    required this.onConnect,
  });
  final ThemeData theme;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    // No BLE implemented yet — always show disconnected state.
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.watch_outlined,
                color: cs.onSurface.withAlpha(140),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ThumbTrace Glove',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: cs.onSurface.withAlpha(100),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Not connected',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withAlpha(140),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: onConnect,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                textStyle: theme.textTheme.labelMedium,
              ),
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryCtaCard extends StatelessWidget {
  const _PrimaryCtaCard({
    required this.theme,
    required this.onStartMonitoring,
  });
  final ThemeData theme;
  final VoidCallback onStartMonitoring;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Card(
      color: cs.primaryContainer,
      child: InkWell(
        onTap: onStartMonitoring,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: cs.onPrimary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start Monitoring',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Begin a new monitoring session',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onPrimaryContainer.withAlpha(180),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: cs.onPrimaryContainer.withAlpha(160),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LatestSessionSection extends StatelessWidget {
  const _LatestSessionSection({
    required this.theme,
    required this.loading,
    required this.session,
    required this.onViewSession,
    required this.onConnect,
  });
  final ThemeData theme;
  final bool loading;
  final MonitoringSession? session;
  final VoidCallback onViewSession;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Latest Session',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        if (loading)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                ),
              ),
            ),
          )
        else if (session == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.history_outlined,
                    size: 40,
                    color: cs.onSurface.withAlpha(80),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No monitoring sessions yet',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: cs.onSurface.withAlpha(160),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Connect your ThumbTrace device and start\nyour first monitoring session.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withAlpha(120),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          _SessionSummaryCard(
            theme: theme,
            session: session!,
            onView: onViewSession,
          ),
      ],
    );
  }
}

class _SessionSummaryCard extends StatelessWidget {
  const _SessionSummaryCard({
    required this.theme,
    required this.session,
    required this.onView,
  });
  final ThemeData theme;
  final MonitoringSession session;
  final VoidCallback onView;

  String _formatDate(DateTime dt) {
    final months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(DateTime start, DateTime end) {
    final d = end.difference(start);
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final dur = _formatDuration(session.startTime, session.endTime);
    final date = _formatDate(session.startTime.toLocal());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule_outlined, size: 14, color: cs.onSurface.withAlpha(120)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    date,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withAlpha(140),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip(theme: theme, label: 'Duration', value: dur),
                const SizedBox(width: 8),
                _StatChip(
                  theme: theme,
                  label: 'Movements',
                  value: '${session.movementCount}',
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onView,
                child: const Text('View Session'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.theme, required this.label, required this.value});
  final ThemeData theme;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withAlpha(140),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResearchQuickAccess extends StatelessWidget {
  const _ResearchQuickAccess({
    required this.theme,
    required this.onSessions,
    required this.onAnalytics,
    required this.onRecommendations,
  });
  final ThemeData theme;
  final VoidCallback onSessions;
  final VoidCallback onAnalytics;
  final VoidCallback onRecommendations;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Research',
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _QuickCard(
              theme: theme,
              icon: Icons.timer_outlined,
              label: 'Sessions',
              onTap: onSessions,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickCard(
              theme: theme,
              icon: Icons.insights_outlined,
              label: 'Analytics',
              onTap: onAnalytics,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      _QuickCard(
        theme: theme,
        icon: Icons.lightbulb_outline,
        label: 'Recommendations',
        onTap: onRecommendations,
        fullWidth: true,
      ),
    ],
  );
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
    this.fullWidth = false,
  });
  final ThemeData theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: cs.onSurface.withAlpha(120),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResearchNotice extends StatelessWidget {
  const _ResearchNotice({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: cs.onSurface.withAlpha(120)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Research prototype for biomechanical monitoring. Not a diagnostic tool.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withAlpha(140),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
