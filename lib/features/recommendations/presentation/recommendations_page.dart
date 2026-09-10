import 'package:flutter/material.dart';

import '../../../core/models/monitoring_session.dart';
import '../../../core/models/sensor_reading.dart';
import '../../../core/services/local_monitoring_session_repository.dart';
import '../../../core/services/monitoring_session_repository.dart';
import '../../analytics/application/biomechanical_analysis_service.dart';
import '../../analytics/domain/models/biomechanical_analysis.dart';
import '../../settings/application/settings_service.dart';
import '../application/recommendation_service.dart';
import '../domain/models/research_recommendation.dart';

/// Interactive research-oriented recommendations dashboard.
///
/// Generates deterministic ergonomic observations and session pacing suggestions
/// from measured biomechanical telemetry using [RecommendationService].
///
/// **Non-Diagnostic Notice**:
/// Recommendations are engineering observations and ergonomic suggestions based on
/// observed telemetry. They do NOT provide clinical diagnoses or medical advice.
class RecommendationsPage extends StatefulWidget {
  const RecommendationsPage({
    this.repository,
    this.recommendationService,
    this.biomechanicalAnalysisService,
    this.settingsService,
    super.key,
  });

  final MonitoringSessionRepository? repository;
  final RecommendationService? recommendationService;
  final BiomechanicalAnalysisService? biomechanicalAnalysisService;
  final SettingsService? settingsService;

  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  late final RecommendationService _recommendationService;
  late final BiomechanicalAnalysisService _biomechService;

  List<MonitoringSession> _sessions = [];
  String? _selectedSessionId;
  List<ResearchRecommendation> _recommendations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _recommendationService = widget.recommendationService ?? const RecommendationService();
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
  void didUpdateWidget(RecommendationsPage oldWidget) {
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
      _loadRecommendationsForSession(_selectedSessionId!);
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
          if (_selectedSessionId == null ||
              !_sessions.any((s) => s.id == _selectedSessionId)) {
            _selectedSessionId = _sessions.first.id;
          }
        } else {
          _selectedSessionId = null;
          _recommendations = [];
        }
      });

      if (_selectedSessionId != null) {
        await _loadRecommendationsForSession(_selectedSessionId!);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRecommendationsForSession(String sessionId) async {
    try {
      final settings = widget.settingsService?.settings;
      final biomechConfig = settings != null
          ? BiomechanicalAnalysisConfig(
              forceThreshold: settings.forceThreshold,
              angularVelocityThreshold: settings.angularVelocityThreshold,
            )
          : const BiomechanicalAnalysisConfig();
      final recConfig = settings != null
          ? RecommendationConfig(
              refMovementsPerMinute: settings.refMovementsPerMinute,
            )
          : null;

      final analysis = await _biomechService.analyzeSession(sessionId, config: biomechConfig);
      final recs = _recommendationService.generateRecommendations(analysis, config: recConfig);

      if (mounted && _selectedSessionId == sessionId) {
        setState(() {
          _recommendations = recs;
        });
      }
    } catch (_) {}
  }

  void _onSelectSession(String? newId) {
    if (newId == null || newId == _selectedSessionId) return;
    setState(() => _selectedSessionId = newId);
    _loadRecommendationsForSession(newId);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _sessions.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.repository == null || _sessions.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Recommendations Available',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Record a monitoring session on the Monitor tab to view research-grade biomechanical observations and ergonomic suggestions.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
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
                // 1. Header
                Text(
                  'Recommendations',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Research-oriented ergonomic observations & pacing suggestions',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),

                // 2. Non-Diagnostic Research Disclaimer
                const _ResearchDisclaimerBanner(),
                const SizedBox(height: 16),

                // 3. Session Selector
                _SessionSelectorCard(
                  sessions: _sessions,
                  selectedSessionId: selectedSession.id,
                  onSelected: _onSelectSession,
                ),
                const SizedBox(height: 18),

                // 4. Recommendation Count & Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RESEARCH RECOMMENDATIONS',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_recommendations.length} Available',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 5. Recommendations List or Empty State
                if (_recommendations.isEmpty)
                  _EmptySessionRecommendationsBox()
                else
                  ..._recommendations.map(
                    (rec) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RecommendationCard(recommendation: rec),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.recommendation});

  final ResearchRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (priorityColor, priorityBg, priorityLabel) = switch (recommendation.priority) {
      RecommendationPriority.elevated => (
          const Color(0xFFBE123C),
          const Color(0xFFFFE4E6),
          'Elevated Priority',
        ),
      RecommendationPriority.moderate => (
          const Color(0xFFB45309),
          const Color(0xFFFEF3C7),
          'Moderate Attention',
        ),
      RecommendationPriority.informational => (
          const Color(0xFF0F766E),
          const Color(0xFFCCFBF1),
          'Informational',
        ),
    };

    final categoryIcon = switch (recommendation.category) {
      RecommendationCategory.movement => Icons.repeat_outlined,
      RecommendationCategory.jointMotion => Icons.timeline_outlined,
      RecommendationCategory.force => Icons.touch_app_outlined,
      RecommendationCategory.motionIntensity => Icons.speed_outlined,
      RecommendationCategory.general => Icons.tune_outlined,
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category & Priority Badges Row
            Row(
              children: [
                Icon(categoryIcon, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  recommendation.category.displayName,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: priorityBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: priorityColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: priorityColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        priorityLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: priorityColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              recommendation.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),

            // Description / Ergonomic Pacing Suggestion
            Text(
              recommendation.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF334155),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // Telemetry Driver Box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.analytics_outlined,
                        size: 15,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          recommendation.evidence,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF475569),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (recommendation.metricValue != null &&
                      recommendation.referenceValue != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Observed: ${recommendation.metricValue!.toStringAsFixed(1)} ${recommendation.unit ?? ""}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Reference: ${recommendation.referenceValue!.toStringAsFixed(1)} ${recommendation.unit ?? ""}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySessionRecommendationsBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 36,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          Text(
            'No research recommendations are available for this session yet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'This session contains no recorded sensor samples or active movements.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ResearchDisclaimerBanner extends StatelessWidget {
  const _ResearchDisclaimerBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 16,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Research-oriented recommendations based on observed biomechanical telemetry. '
              'These are not medical advice, diagnosis, or clinical recommendations.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.amber.shade900,
                height: 1.35,
              ),
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(14),
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
                  final durStr = '${dur.inMinutes}m ${(dur.inSeconds % 60)}s';

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
