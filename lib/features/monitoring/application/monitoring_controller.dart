import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/models/monitoring_session.dart';
import '../../../core/models/sensor_reading.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/local_monitoring_session_repository.dart';
import '../../../core/services/monitoring_session_repository.dart';
import '../../../core/services/movement_detection_service.dart';
import '../../../core/services/sensor_data_source.dart';
import '../../../core/services/session_statistics_accumulator.dart';
import '../../../core/services/session_sync_service.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../settings/application/settings_service.dart';

enum MonitoringStatus { stopped, active, paused }

/// Converts a source-agnostic reading stream into UI-ready monitoring state.
///
/// Responsibilities:
/// - Tracks session lifecycle (start / pause / resume / stop).
/// - Measures active elapsed time, excluding paused intervals.
/// - Feeds readings into [MovementDetectionService] for event detection.
/// - Accumulates per-session sensor statistics via [SessionStatisticsAccumulator].
/// - Buffers raw [SensorReading]s during the active session.
/// - On stop, builds a completed [MonitoringSession] and persists both session
///   and readings via [MonitoringSessionRepository] (if provided).
/// - Gracefully captures persistence errors without disrupting monitoring UI.
/// - Automatically initiates cloud synchronization via [SessionSyncService] when
///   [SettingsService.settings.autoCloudSync] is enabled and user is authenticated.
class MonitoringController extends ChangeNotifier {
  MonitoringController(
    this._dataSource, {
    MovementDetectionService? detector,
    this.repository,
    this.fallbackRepository,
    this.settingsService,
    this.syncService,
    this.authRepository,
  }) : _detector = detector ?? MovementDetectionService() {
    _readingSubscription = _dataSource.readings.listen((reading) {
      currentReading = reading;
      if (_isRunning) {
        _detector.processReading(reading);
        _accumulator.add(reading);
        _sessionReadings.add(reading);
      }
      notifyListeners();
    });
  }

  final SensorDataSource _dataSource;
  final MovementDetectionService _detector;
  final MonitoringSessionRepository? repository;
  final LocalMonitoringSessionRepository? fallbackRepository;
  final SettingsService? settingsService;
  final SessionSyncService? syncService;
  final AuthRepository? authRepository;
  final SessionStatisticsAccumulator _accumulator = SessionStatisticsAccumulator();
  final List<SensorReading> _sessionReadings = [];

  late final StreamSubscription<SensorReading> _readingSubscription;
  Timer? _elapsedTimer;

  // Active-duration tracking.
  DateTime? _activeSince;
  Duration _elapsedBeforePause = Duration.zero;

  // Wall-clock start of the current/last session (for MonitoringSession.startTime).
  DateTime? _sessionWallStart;

  /// True when the session is currently emitting data.
  bool get _isRunning => status == MonitoringStatus.active;

  // ── Public state ──────────────────────────────────────────────────────────

  SensorReading? currentReading;
  MonitoringStatus status = MonitoringStatus.stopped;

  /// Active (non-paused) duration of the most recently completed session.
  Duration lastCompletedDuration = Duration.zero;

  /// The most recently finalised [MonitoringSession], or null if none yet.
  MonitoringSession? lastCompletedSession;

  /// Error message if session persistence fails, or null if successful.
  String? persistenceError;

  bool get hasPersistenceError => persistenceError != null;

  /// Sensor readings captured during the most recent session.
  List<SensorReading> get lastSessionReadings =>
      List.unmodifiable(_sessionReadings);

  bool get isActive => status == MonitoringStatus.active;
  bool get isPaused => status == MonitoringStatus.paused;

  // ── Elapsed active time ───────────────────────────────────────────────────

  /// Active (non-paused) elapsed time for the current session.
  Duration get elapsedDuration {
    if (_activeSince == null) return _elapsedBeforePause;
    return _elapsedBeforePause + DateTime.now().difference(_activeSince!);
  }

  // ── Movement detection passthrough ────────────────────────────────────────

  /// Whether the thumb is currently in an active movement phase.
  bool get isMoving => _detector.isMoving;

  /// Total completed movement events in the current session.
  int get movementCount => _detector.movementCount;

  /// Duration of the ongoing movement, or [Duration.zero] when resting.
  Duration get currentMovementDuration => _detector.currentMovementDuration;

  /// Observed movement frequency (movements per minute) for this session.
  double get movementsPerMinute => _detector.movementsPerMinute;

  // ── Session lifecycle ─────────────────────────────────────────────────────

  Future<void> start() async {
    if (status != MonitoringStatus.stopped) return;
    _elapsedBeforePause = Duration.zero;
    _activeSince = DateTime.now();
    _sessionWallStart = _activeSince;
    status = MonitoringStatus.active;
    _detector.reset();
    _accumulator.reset();
    _sessionReadings.clear();
    lastCompletedSession = null;
    persistenceError = null;
    _startElapsedTimer();
    await _dataSource.start();
    notifyListeners();
  }

  Future<void> pause() async {
    if (!isActive) return;
    _elapsedBeforePause = elapsedDuration;
    _activeSince = null;
    _elapsedTimer?.cancel();
    status = MonitoringStatus.paused;
    _detector.markStopped();
    await _dataSource.pause();
    notifyListeners();
  }

  Future<void> resume() async {
    if (!isPaused) return;
    _activeSince = DateTime.now();
    status = MonitoringStatus.active;
    _startElapsedTimer();
    await _dataSource.resume();
    notifyListeners();
  }

  Future<void> stop() async {
    if (status == MonitoringStatus.stopped) return;
    final activeDuration = elapsedDuration;
    _elapsedBeforePause = Duration.zero;
    _activeSince = null;
    _elapsedTimer?.cancel();
    status = MonitoringStatus.stopped;
    lastCompletedDuration = activeDuration;
    _detector.markStopped();
    await _dataSource.stop();
    await _finaliseSession();
    notifyListeners();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _finaliseSession() async {
    final wallStart = _sessionWallStart;
    if (wallStart == null) return;

    final wallEnd = DateTime.now().toUtc();
    // Ensure endTime is never before startTime (e.g. if stop() is called
    // within the same millisecond as start()).
    final safeEnd = wallEnd.isAfter(wallStart.toUtc())
        ? wallEnd
        : wallStart.toUtc().add(const Duration(milliseconds: 1));

    final session = MonitoringSession(
      id: generateUuid(),
      startTime: wallStart,
      endTime: safeEnd,
      movementCount: _detector.movementCount,
      averageIpAngle: _accumulator.averageIpAngle,
      maximumIpAngle: _accumulator.maximumIpAngle,
      averageMcpAngle: _accumulator.averageMcpAngle,
      maximumMcpAngle: _accumulator.maximumMcpAngle,
      averageForce: _accumulator.averageForce,
      peakForce: _accumulator.peakForce,
      averageAngularVelocity: _accumulator.averageAngularVelocity,
      averageMotionMagnitude: _accumulator.averageMotionMagnitude,
    );

    lastCompletedSession = session;
    final readingsToPersist = List<SensorReading>.unmodifiable(_sessionReadings);
    persistenceError = null;

    final repo = repository;
    if (repo != null) {
      try {
        await repo.saveSession(session, readings: readingsToPersist);
      } catch (e) {
        persistenceError = 'Persistence error: $e';
        // Fall back to local persistence if repository is remote and fallback provided
        final fallback = fallbackRepository;
        if (fallback != null && fallback != repo) {
          try {
            await fallback.saveSession(session, readings: readingsToPersist);
          } catch (_) {
            // Ignored, primary persistenceError remains recorded
          }
        }
      }
    }

    // Auto Cloud Sync integration (Step 14)
    final autoSync = settingsService?.settings.autoCloudSync ?? false;
    final isAuth = authRepository?.isAuthenticated ?? false;
    if (autoSync && isAuth && syncService != null) {
      try {
        await syncService!.syncSession(session.id);
      } catch (e) {
        debugPrint('MonitoringController: Auto cloud sync failed non-blockingly: $e');
      }
    }

    _sessionWallStart = null;
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _readingSubscription.cancel();
    super.dispose();
  }
}
