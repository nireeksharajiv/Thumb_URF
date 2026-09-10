import 'package:flutter/material.dart';

import '../../../core/models/monitoring_session.dart';
import '../../../core/models/sensor_reading.dart';
import '../../../core/services/local_monitoring_session_repository.dart';
import '../../../core/services/monitoring_session_repository.dart';
import '../application/analytics_service.dart';
import '../application/biomechanical_analysis_service.dart';
import '../application/research_exposure_index_service.dart';
import '../domain/models/biomechanical_analysis.dart';
import '../domain/models/research_exposure_index.dart';
import '../domain/models/session_analytics.dart';
import '../../settings/application/settings_service.dart';
import 'widgets/analytics_empty_state.dart';
import 'widgets/analytics_overview_card.dart';
import 'widgets/biomech_time_series_chart.dart';
import 'widgets/biomechanical_exposure_card.dart';
import 'widgets/force_motion_card.dart';
import 'widgets/joint_metrics_card.dart';
import 'widgets/research_exposure_index_card.dart';

/// Primary Analytics & Research Telemetry dashboard.
///
/// Displays calculated research-grade biomechanical metrics and raw time-series
/// visualizations for recorded monitoring sessions using [AnalyticsService] and
/// [BiomechanicalAnalysisService].
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({
    this.repository,
    this.analyticsService,
    this.biomechanicalAnalysisService,
    this.settingsService,
    super.key,
  });

  final MonitoringSessionRepository? repository;
  final AnalyticsService? analyticsService;
  final BiomechanicalAnalysisService? biomechanicalAnalysisService;
  final SettingsService? settingsService;

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  late final AnalyticsService _analyticsService;
  late final BiomechanicalAnalysisService _biomechService;

  List<MonitoringSession> _sessions = [];
  String? _selectedSessionId;
  SessionAnalytics? _currentAnalytics;
  BiomechanicalAnalysis? _currentBiomechanicalAnalysis;
  ResearchExposureIndex? _currentExposureIndex;
  List<SensorReading> _currentReadings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _analyticsService = widget.analyticsService ??
        (widget.repository != null ? AnalyticsService(widget.repository!) : AnalyticsService(_DummyRepository()));
    _biomechService = widget.biomechanicalAnalysisService ??
        (widget.repository != null
            ? BiomechanicalAnalysisService(widget.repository!)
            : BiomechanicalAnalysisService(_DummyRepository()));

    _syncFromLocalCache();
    widget.repository?.addListener(_onRepositoryChanged);
    widget.settingsService?.addListener(_onSettingsChanged);
    _loadSessionsAsync();
  }

  @override
  void didUpdateWidget(AnalyticsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      oldWidget.repository?.removeListener(_onRepositoryChanged);
      widget.repository?.addListener(_onRepositoryChanged);
      _syncFromLocalCache();
      _loadSessionsAsync();
    }
    if (oldWidget.settingsService != widget.settingsService) {
      oldWidget.settingsService?.removeListener(_onSettingsChanged);
      widget.settingsService?.addListener(_onSettingsChanged);
      _onSettingsChanged();
    }
  }

  @override
  void dispose() {
    try {
      widget.repository?.removeListener(_onRepositoryChanged);
      widget.settingsService?.removeListener(_onSettingsChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onSettingsChanged() {
    if (_selectedSessionId != null) {
      _loadAnalyticsForSession(_selectedSessionId!);
    }
  }

  void _syncFromLocalCache() {
    final repo = widget.repository;
    if (repo is LocalMonitoringSessionRepository) {
      _sessions = repo.sessions.reversed.toList();
      if (_sessions.isNotEmpty && _selectedSessionId == null) {
        _selectedSessionId = _sessions.first.id;
      }
      _isLoading = false;
    }
  }

  void _onRepositoryChanged() {
    _loadSessionsAsync();
  }

  Future<void> _loadSessionsAsync() async {
    final repo = widget.repository;
    if (repo == null) {
      if (mounted) {
        setState(() {
          _sessions = [];
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final fetched = await repo.getSessions();
      if (!mounted) return;

      setState(() {
        _sessions = fetched;
        _isLoading = false;
        if (_sessions.isNotEmpty) {
          // Keep current selection if still valid, otherwise pick newest
          if (_selectedSessionId == null ||
              !_sessions.any((s) => s.id == _selectedSessionId)) {
            _selectedSessionId = _sessions.first.id;
          }
        } else {
          _selectedSessionId = null;
          _currentAnalytics = null;
          _currentBiomechanicalAnalysis = null;
          _currentExposureIndex = null;
          _currentReadings = [];
        }
      });

      if (_selectedSessionId != null) {
        await _loadAnalyticsForSession(_selectedSessionId!);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAnalyticsForSession(String sessionId) async {
    final repo = widget.repository;
    if (repo == null) return;

    try {
      final settings = widget.settingsService?.settings;
      final biomechConfig = settings != null
          ? BiomechanicalAnalysisConfig(
              forceThreshold: settings.forceThreshold,
              angularVelocityThreshold: settings.angularVelocityThreshold,
            )
          : const BiomechanicalAnalysisConfig();
      final exposureConfig = settings != null
          ? ResearchExposureIndexConfig(
              refMovementsPerMinute: settings.refMovementsPerMinute,
            )
          : null;

      final analytics = await _analyticsService.computeSessionAnalytics(sessionId);
      final biomech = await _biomechService.analyzeSession(sessionId, config: biomechConfig);
      final readings = await repo.getSensorReadings(sessionId);
      final exposureIndex = ResearchExposureIndexService.calculate(biomech, config: exposureConfig);

      if (mounted && _selectedSessionId == sessionId) {
        setState(() {
          _currentAnalytics = analytics;
          _currentBiomechanicalAnalysis = biomech;
          _currentExposureIndex = exposureIndex;
          _currentReadings = readings;
        });
      }
    } catch (_) {}
  }

  void _onSelectSession(String? newId) {
    if (newId == null || newId == _selectedSessionId) return;
    setState(() => _selectedSessionId = newId);
    _loadAnalyticsForSession(newId);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _sessions.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.repository == null || _sessions.isEmpty) {
      return const AnalyticsEmptyState();
    }

    final selectedSession = _sessions.firstWhere(
      (s) => s.id == _selectedSessionId,
      orElse: () => _sessions.first,
    );

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSessionsAsync,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Analytics',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Biomechanical research telemetry & kinematics',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),

                // Session Selector
                _SessionSelectorCard(
                  sessions: _sessions,
                  selectedSessionId: selectedSession.id,
                  onSelected: _onSelectSession,
                ),
                const SizedBox(height: 16),

                if (_currentAnalytics != null) ...[
                  // 1. Session Overview Card
                  AnalyticsOverviewCard(analytics: _currentAnalytics!),
                  const SizedBox(height: 14),

                  // 2. IP and MCP Joint Metrics Card
                  JointMetricsCard(analytics: _currentAnalytics!),
                  const SizedBox(height: 14),

                  // 3. Force and Motion Card
                  ForceMotionCard(analytics: _currentAnalytics!),
                  const SizedBox(height: 14),

                  // 4. Biomechanical Exposure Card
                  if (_currentBiomechanicalAnalysis != null) ...[
                    BiomechanicalExposureCard(analysis: _currentBiomechanicalAnalysis!),
                    const SizedBox(height: 14),
                  ],

                  // 5. Research Exposure Index Card
                  if (_currentExposureIndex != null) ...[
                    ResearchExposureIndexCard(exposureIndex: _currentExposureIndex!),
                    const SizedBox(height: 14),
                  ],

                  // 6. Raw Sensor Readings Time-Series Chart
                  BiomechTimeSeriesChart(
                    key: ValueKey('${selectedSession.id}_${_currentReadings.length}'),
                    readings: _currentReadings,
                  ),
                  const SizedBox(height: 20),

                  // 7. Research / Non-Diagnostic Framing Disclaimer
                  const _ResearchDisclaimerCard(),
                ] else
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionSelectorCard extends StatelessWidget {
  const _SessionSelectorCard({
    required this.sessions,
    required this.selectedSessionId,
    required this.onSelected,
  });

  final List<MonitoringSession> sessions;
  final String selectedSessionId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E9E8)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.history,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            'Session:',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedSessionId,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down),
                items: sessions.map((session) {
                  final start = session.startTime.toLocal();
                  final date =
                      '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')} ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
                  final dur = session.duration;
                  final durStr =
                      '${dur.inMinutes}m ${(dur.inSeconds % 60)}s';

                  return DropdownMenuItem<String>(
                    value: session.id,
                    child: Text(
                      '$date ($durStr · ${session.movementCount} mov)',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: onSelected,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResearchDisclaimerCard extends StatelessWidget {
  const _ResearchDisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: Colors.grey.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Research Prototype: Telemetry data and kinematics metrics are computed for '
              'biomechanical monitoring purposes only. This system does not provide medical diagnoses, '
              'RSI evaluations, or clinical risk determinations.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 11,
                    height: 1.3,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fallback dummy repository for when null is passed to [AnalyticsPage].
class _DummyRepository implements MonitoringSessionRepository {
  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  Future<void> deleteSession(String id) async {}

  @override
  Future<MonitoringSession?> getSessionById(String id) async => null;

  @override
  Future<List<MonitoringSession>> getSessions() async => const [];

  @override
  Future<List<SensorReading>> getSensorReadings(String sessionId) async => const [];

  @override
  Future<void> saveSensorReadings(String sessionId, List<SensorReading> readings) async {}

  @override
  Future<void> saveSession(MonitoringSession session, {List<SensorReading>? readings}) async {}
}
