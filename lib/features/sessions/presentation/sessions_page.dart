import 'package:flutter/material.dart';

import '../../../core/models/monitoring_session.dart';
import '../../../core/models/sensor_reading.dart';
import '../../../core/models/sync_status.dart';
import '../../../core/services/local_monitoring_session_repository.dart';
import '../../../core/services/monitoring_session_repository.dart';
import '../../../core/services/session_sync_service.dart';

/// Displays the history of completed monitoring sessions.
///
/// Shows an empty state when no sessions exist, or a list of [_SessionCard]
/// widgets (newest first) when sessions are available.
/// Supports tapping on a session to inspect detailed biomechanical summaries
/// and delete sessions safely.
class SessionsPage extends StatefulWidget {
  const SessionsPage({
    this.repository,
    this.syncService,
    super.key,
  });

  final MonitoringSessionRepository? repository;
  final SessionSyncService? syncService;

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  List<MonitoringSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _syncFromLocalCache();
    widget.repository?.addListener(_onRepositoryChanged);
    widget.syncService?.addListener(_onSyncChanged);
    _loadSessionsAsync();
  }

  @override
  void didUpdateWidget(SessionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      oldWidget.repository?.removeListener(_onRepositoryChanged);
      widget.repository?.addListener(_onRepositoryChanged);
      _syncFromLocalCache();
      _loadSessionsAsync();
    }
    if (oldWidget.syncService != widget.syncService) {
      oldWidget.syncService?.removeListener(_onSyncChanged);
      widget.syncService?.addListener(_onSyncChanged);
    }
  }

  @override
  void dispose() {
    try {
      widget.repository?.removeListener(_onRepositoryChanged);
      widget.syncService?.removeListener(_onSyncChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onSyncChanged() {
    if (mounted) setState(() {});
  }

  void _syncFromLocalCache() {
    final repo = widget.repository;
    if (repo is LocalMonitoringSessionRepository) {
      _sessions = repo.sessions.reversed.toList();
    }
  }

  void _onRepositoryChanged() {
    final repo = widget.repository;
    if (repo is LocalMonitoringSessionRepository) {
      setState(() {
        _sessions = repo.sessions.reversed.toList();
      });
    } else {
      _loadSessionsAsync();
    }
  }

  Future<void> _loadSessionsAsync() async {
    final repo = widget.repository;
    if (repo == null) return;
    try {
      final fetched = await repo.getSessions();
      if (mounted) {
        setState(() {
          _sessions = fetched;
        });
      }
    } catch (_) {
      // Keep existing local/cached state on error
    }
  }

  void _openSessionDetails(MonitoringSession session) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SessionDetailsSheet(
        session: session,
        repository: widget.repository,
        syncService: widget.syncService,
        onDeleted: () {
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.repository == null && _sessions.isEmpty) {
      return const _EmptyState();
    }

    return _sessions.isEmpty
        ? const _EmptyState()
        : _SessionList(
            sessions: _sessions,
            syncService: widget.syncService,
            onSessionTap: _openSessionDetails,
          );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private widgets
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sessions',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Biomechanical monitoring session history',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No completed sessions yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start a monitoring session on the Monitor tab.\nCompleted sessions will appear here.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      );
}

class _SessionList extends StatelessWidget {
  const _SessionList({
    required this.sessions,
    this.syncService,
    required this.onSessionTap,
  });

  final List<MonitoringSession> sessions;
  final SessionSyncService? syncService;
  final ValueChanged<MonitoringSession> onSessionTap;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sessions',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Biomechanical monitoring session history · ${sessions.length} record${sessions.length == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (syncService != null)
                      TextButton.icon(
                        key: const Key('sync_all_button'),
                        icon: const Icon(Icons.sync, size: 18),
                        label: const Text('Sync All'),
                        onPressed: () async {
                          final count = await syncService!.syncAllUnsynced();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  count > 0
                                      ? 'Synchronized $count session(s) to cloud'
                                      : 'All sessions are already up to date',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverList.separated(
                itemCount: sessions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _SessionCard(
                  session: sessions[index],
                  syncService: syncService,
                  onTap: () => onSessionTap(sessions[index]),
                ),
              ),
            ),
          ],
        ),
      );
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    this.syncService,
    this.onTap,
  });

  final MonitoringSession session;
  final SessionSyncService? syncService;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final start = session.startTime.toLocal();
    final dateLabel =
        '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}';
    final timeLabel =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';

    final dur = session.duration;
    final durLabel =
        '${dur.inMinutes.toString().padLeft(2, '0')}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}';

    final durMinutes = dur.inSeconds > 0 ? dur.inSeconds / 60.0 : 0.0;
    final freqLabel = durMinutes > 0
        ? '${(session.movementCount / durMinutes).toStringAsFixed(1)} /min'
        : '—';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: label + sync badge + date/time chip.
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Completed session',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                    ),
                  ),
                  if (syncService != null) ...[
                    const SizedBox(width: 8),
                    _SyncBadge(
                      syncService: syncService,
                      sessionId: session.id,
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '$dateLabel  $timeLabel',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, size: 18, color: Colors.black45),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Core stats in a two-column grid.
              _StatGrid(
                stats: [
                  _Stat('Duration', durLabel),
                  _Stat('Movements', '${session.movementCount}'),
                  _Stat('Frequency', freqLabel),
                  _Stat(
                    'Avg force',
                    '${session.averageForce.toStringAsFixed(2)} N',
                  ),
                  _Stat(
                    'Peak force',
                    '${session.peakForce.toStringAsFixed(2)} N',
                  ),
                  _Stat(
                    'Avg IP angle',
                    '${session.averageIpAngle.toStringAsFixed(1)}°',
                  ),
                  _Stat(
                    'Max IP angle',
                    '${session.maximumIpAngle.toStringAsFixed(1)}°',
                  ),
                  _Stat(
                    'Avg MCP angle',
                    '${session.averageMcpAngle.toStringAsFixed(1)}°',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status badge showing current cloud synchronization state.
class _SyncBadge extends StatelessWidget {
  const _SyncBadge({
    required this.syncService,
    required this.sessionId,
  });

  final SessionSyncService? syncService;
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    if (syncService == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: syncService!,
      builder: (context, _) {
        final state = syncService!.getSyncState(sessionId);
        final Color color;
        final IconData icon;
        final String label;

        switch (state) {
          case SyncState.synced:
            color = Colors.green.shade700;
            icon = Icons.cloud_done_outlined;
            label = 'Synced';
            break;
          case SyncState.syncing:
            color = Colors.blue.shade700;
            icon = Icons.cloud_upload_outlined;
            label = 'Syncing...';
            break;
          case SyncState.syncFailed:
            color = Colors.red.shade700;
            icon = Icons.cloud_off_outlined;
            label = 'Sync failed';
            break;
          case SyncState.localOnly:
            color = Colors.grey.shade600;
            icon = Icons.cloud_outlined;
            label = 'Local only';
            break;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withAlpha(80)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state == SyncState.syncing)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(icon, size: 12, color: color),
                ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Detailed bottom sheet showing full session metrics and sensor reading samples.
class _SessionDetailsSheet extends StatefulWidget {
  const _SessionDetailsSheet({
    required this.session,
    this.repository,
    this.syncService,
    this.onDeleted,
  });

  final MonitoringSession session;
  final MonitoringSessionRepository? repository;
  final SessionSyncService? syncService;
  final VoidCallback? onDeleted;

  @override
  State<_SessionDetailsSheet> createState() => _SessionDetailsSheetState();
}

class _SessionDetailsSheetState extends State<_SessionDetailsSheet> {
  bool _isSyncing = false;

  Future<void> _handleSync() async {
    final service = widget.syncService;
    if (service == null) return;

    setState(() => _isSyncing = true);
    final syncInfo = await service.syncSession(widget.session.id);
    if (!mounted) return;
    setState(() => _isSyncing = false);

    final success = syncInfo.state == SyncState.synced;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Session synchronized with cloud database.'
              : 'Sync failed: ${syncInfo.errorMessage ?? "Unknown error"}',
        ),
        backgroundColor: success ? Colors.green.shade800 : Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.session.startTime.toLocal();
    final end = widget.session.endTime.toLocal();
    final dur = widget.session.duration;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Session Summary',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (widget.repository != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete session',
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('Delete Session?'),
                          content: const Text(
                            'Are you sure you want to delete this monitoring session and all its stored readings?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dCtx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () => Navigator.of(dCtx).pop(true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        widget.repository!.deleteSession(widget.session.id);
                        widget.onDeleted?.call();
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Session ID: ${widget.session.id}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                    fontFamily: 'monospace',
                  ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            _DetailRow('Started', start.toString().split('.')[0]),
            _DetailRow('Ended', end.toString().split('.')[0]),
            _DetailRow(
              'Duration',
              '${dur.inMinutes}m ${dur.inSeconds % 60}s (${dur.inSeconds} seconds)',
            ),
            _DetailRow('Total Movements', widget.session.movementCount.toString()),
            _DetailRow(
              'Movement Frequency',
              dur.inSeconds > 0
                  ? '${(widget.session.movementCount / (dur.inSeconds / 60.0)).toStringAsFixed(1)} movements/min'
                  : '—',
            ),
            const SizedBox(height: 12),
            Text(
              'Biomechanical Metrics',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            _DetailRow('Avg IP Angle', '${widget.session.averageIpAngle.toStringAsFixed(1)}°'),
            _DetailRow('Max IP Angle', '${widget.session.maximumIpAngle.toStringAsFixed(1)}°'),
            _DetailRow('Avg MCP Angle', '${widget.session.averageMcpAngle.toStringAsFixed(1)}°'),
            _DetailRow('Max MCP Angle', '${widget.session.maximumMcpAngle.toStringAsFixed(1)}°'),
            _DetailRow('Average Force', '${widget.session.averageForce.toStringAsFixed(2)} N'),
            _DetailRow('Peak Force', '${widget.session.peakForce.toStringAsFixed(2)} N'),
            _DetailRow(
              'Avg Angular Velocity',
              '${widget.session.averageAngularVelocity.toStringAsFixed(1)} °/s',
            ),
            _DetailRow(
              'Avg Motion Magnitude',
              widget.session.averageMotionMagnitude.toStringAsFixed(2),
            ),

            if (widget.repository != null) ...[
              const SizedBox(height: 8),
              FutureBuilder<List<SensorReading>>(
                future: widget.repository!.getSensorReadings(widget.session.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Checking recorded sensor readings...'),
                        ],
                      ),
                    );
                  }
                  final count = snapshot.data?.length ?? 0;
                  return _DetailRow(
                    'Stored Sensor Readings',
                    '$count samples recorded',
                  );
                },
              ),
            ],

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Cloud Synchronization',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (widget.syncService != null) ...[
              ListenableBuilder(
                listenable: widget.syncService!,
                builder: (context, _) {
                  final syncInfo = widget.syncService!.getSyncInfo(widget.session.id);
                  final state = syncInfo?.state ?? SyncState.localOnly;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Cloud Status', style: Theme.of(context).textTheme.bodyMedium),
                          _SyncBadge(
                            syncService: widget.syncService,
                            sessionId: widget.session.id,
                          ),
                        ],
                      ),
                      if (syncInfo?.syncedAt != null) ...[
                        const SizedBox(height: 4),
                        _DetailRow(
                          'Last Synced',
                          syncInfo!.syncedAt!.toLocal().toString().split('.')[0],
                        ),
                      ],
                      if (state == SyncState.syncFailed && syncInfo?.errorMessage != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  syncInfo!.errorMessage!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('sync_session_button'),
                          onPressed: _isSyncing ? null : _handleSync,
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.cloud_upload_outlined),
                          label: Text(
                            _isSyncing
                                ? 'Synchronizing...'
                                : (state == SyncState.synced
                                    ? 'Re-sync to Cloud'
                                    : (state == SyncState.syncFailed
                                        ? 'Retry Cloud Sync'
                                        : 'Sync to Cloud')),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ] else ...[
              _DetailRow('Cloud Status', 'Local persistence (Offline)'),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      );
}

/// A two-column grid of labelled statistics.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});
  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 0,
        runSpacing: 8,
        children: stats
            .map(
              (s) => SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.label,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      s.value,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      );
}

class _Stat {
  const _Stat(this.label, this.value);
  final String label;
  final String value;
}
