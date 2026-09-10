import '../models/sensor_reading.dart';
import 'movement_detection_config.dart';

/// Analyses a stream of [SensorReading]s and identifies repetitive thumb
/// movement events.
///
/// ## Detection logic
/// A reading is classified as *active* when **both** of the following
/// conditions hold simultaneously:
///
/// 1. The flex-sensor signal crosses a threshold:
///    `|ΔipAngle| >= ipAngleChangeDeg`
///    OR `|ΔmcpAngle| >= mcpAngleChangeDeg`
///
/// 2. The IMU signal confirms motion:
///    `|angularVelocity| >= angularVelocityDegPerSec`
///    OR `motionMagnitude >= motionMagnitudeG`
///
/// Requiring both sensors to agree reduces false positives from single-sensor
/// noise.
///
/// ## Event lifecycle
/// - Movement **starts** on the first active reading after a resting period.
/// - The event stays open while active readings continue arriving.
/// - Movement **ends** once no active reading arrives for
///   [MovementDetectionConfig.movementEndDebounce] (timestamp-based — no
///   wall-clock timers).
/// - The completed event increments [movementCount] only if its measured
///   duration meets [MovementDetectionConfig.minimumMovementDuration].
///
/// ## Testability
/// All timing is computed from [SensorReading.timestamp] values, not
/// wall-clock time, so tests can supply deterministic hand-crafted timestamps.
///
/// **This is a biomechanical movement detector — not a medical diagnostic
/// instrument.**
class MovementDetectionService {
  MovementDetectionService({
    double? ipAngleChangeDeg,
    double? mcpAngleChangeDeg,
    double? angularVelocityDegPerSec,
    double? motionMagnitudeG,
    Duration? minimumMovementDuration,
    Duration? movementEndDebounce,
  }) : _ipAngle = ipAngleChangeDeg ?? MovementDetectionConfig.ipAngleChangeDeg,
       _mcpAngle =
           mcpAngleChangeDeg ?? MovementDetectionConfig.mcpAngleChangeDeg,
       _angularVelocity =
           angularVelocityDegPerSec ??
           MovementDetectionConfig.angularVelocityDegPerSec,
       _motionMagnitude =
           motionMagnitudeG ?? MovementDetectionConfig.motionMagnitudeG,
       _minDuration =
           minimumMovementDuration ??
           MovementDetectionConfig.minimumMovementDuration,
       _debounce =
           movementEndDebounce ?? MovementDetectionConfig.movementEndDebounce;

  // ── Effective thresholds (set at construction, defaults from config) ──────

  final double _ipAngle;
  final double _mcpAngle;
  final double _angularVelocity;
  final double _motionMagnitude;
  final Duration _minDuration;
  final Duration _debounce;

  // ── Internal state ───────────────────────────────────────────────────────

  SensorReading? _previousReading;
  bool _isMoving = false;
  DateTime? _movementStart;
  DateTime? _lastActiveTimestamp;
  int _movementCount = 0;
  DateTime? _sessionStart;
  DateTime? _latestTimestamp;

  // ── Public interface ─────────────────────────────────────────────────────

  /// Whether the thumb is currently in an active movement phase.
  bool get isMoving => _isMoving;

  /// Total completed movement events since [reset] was last called.
  int get movementCount => _movementCount;

  /// Duration of the ongoing movement event, or [Duration.zero] when resting.
  ///
  /// Based on sensor timestamps (deterministic in tests).
  Duration get currentMovementDuration {
    if (!_isMoving || _movementStart == null || _lastActiveTimestamp == null) {
      return Duration.zero;
    }
    return _lastActiveTimestamp!.difference(_movementStart!);
  }

  /// Observed movement frequency since [reset], in movements per minute.
  double get movementsPerMinute {
    final start = _sessionStart;
    final latest = _latestTimestamp;
    if (start == null || latest == null || _movementCount == 0) return 0;
    final elapsedMs = latest.difference(start).inMilliseconds;
    if (elapsedMs < 1) return 0;
    final minutes = elapsedMs / Duration.millisecondsPerMinute;
    return _movementCount / minutes;
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Resets all counters and internal state for a new monitoring session.
  void reset() {
    _previousReading = null;
    _isMoving = false;
    _movementStart = null;
    _lastActiveTimestamp = null;
    _movementCount = 0;
    _sessionStart = null;
    _latestTimestamp = null;
  }

  /// Closes any open movement event without waiting for the debounce period.
  ///
  /// Call when monitoring is paused or stopped so that an in-progress
  /// movement is correctly finalised rather than left open indefinitely.
  void markStopped() {
    if (_isMoving) {
      _closeMovementEvent(_lastActiveTimestamp);
    }
  }

  /// Processes one [SensorReading] from the sensor data source.
  ///
  /// Readings must arrive in chronological order.
  void processReading(SensorReading reading) {
    _latestTimestamp = reading.timestamp;
    _sessionStart ??= reading.timestamp;

    final prev = _previousReading;
    _previousReading = reading;

    if (prev == null) {
      // Need at least two readings to compute angle deltas.
      return;
    }

    final active = _isReadingActive(reading, prev);

    if (active) {
      _lastActiveTimestamp = reading.timestamp;
      if (!_isMoving) {
        _movementStart = reading.timestamp;
        _isMoving = true;
      }
    } else if (_isMoving) {
      // Debounce: close the event only after sustained inactivity.
      final sinceActive = reading.timestamp.difference(_lastActiveTimestamp!);
      if (sinceActive >= _debounce) {
        _closeMovementEvent(_lastActiveTimestamp);
      }
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  bool _isReadingActive(SensorReading reading, SensorReading previous) {
    final deltaIp = (reading.ipAngle - previous.ipAngle).abs();
    final deltaMcp = (reading.mcpAngle - previous.mcpAngle).abs();
    final flexSignal =
        deltaIp >= _ipAngle || deltaMcp >= _mcpAngle;

    final imuSignal =
        reading.angularVelocity.abs() >= _angularVelocity ||
        reading.motionMagnitude >= _motionMagnitude;

    return flexSignal && imuSignal;
  }

  void _closeMovementEvent(DateTime? endTimestamp) {
    final start = _movementStart;
    final end = endTimestamp;
    if (start != null && end != null) {
      if (end.difference(start) >= _minDuration) {
        _movementCount++;
      }
    }
    _isMoving = false;
    _movementStart = null;
    _lastActiveTimestamp = null;
  }
}
