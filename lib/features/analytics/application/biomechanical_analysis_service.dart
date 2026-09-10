import 'dart:math' as math;

import '../../../core/models/monitoring_session.dart';
import '../../../core/models/sensor_reading.dart';
import '../../../core/services/monitoring_session_repository.dart';
import '../domain/models/biomechanical_analysis.dart';

/// Application service responsible for calculating detailed research-grade
/// biomechanical exposure and loading metrics.
///
/// Consumes sensor readings and sessions strictly through [MonitoringSessionRepository].
/// Decoupled from UI widgets, Supabase SDK, and hardware layers.
class BiomechanicalAnalysisService {
  const BiomechanicalAnalysisService(this._repository);

  final MonitoringSessionRepository _repository;

  /// Analyzes a specific session by [sessionId] using the configured repository.
  Future<BiomechanicalAnalysis> analyzeSession(
    String sessionId, {
    BiomechanicalAnalysisConfig config = const BiomechanicalAnalysisConfig(),
  }) async {
    final session = await _repository.getSessionById(sessionId);
    final readings = await _repository.getSensorReadings(sessionId);

    return analyze(
      sessionId: sessionId,
      session: session,
      readings: readings,
      config: config,
    );
  }

  /// Analyzes all recorded sessions in the repository, ordered newest first.
  Future<List<BiomechanicalAnalysis>> analyzeAllSessions({
    BiomechanicalAnalysisConfig config = const BiomechanicalAnalysisConfig(),
  }) async {
    final sessions = await _repository.getSessions();
    final results = <BiomechanicalAnalysis>[];

    for (final session in sessions) {
      final readings = await _repository.getSensorReadings(session.id);
      results.add(
        analyze(
          sessionId: session.id,
          session: session,
          readings: readings,
          config: config,
        ),
      );
    }

    return List.unmodifiable(results);
  }

  /// Pure, deterministic calculation function computing [BiomechanicalAnalysis]
  /// from a list of [SensorReading]s and optional session metadata.
  ///
  /// Handles:
  /// - Empty reading lists (falls back safely to session metadata if present)
  /// - Single reading lists (excursions = 0, delta angles = 0, durations = 0)
  /// - Non-positive or irregular time intervals (safely skips Δt <= 0)
  /// - Zero-duration sessions (avoids division by zero)
  static BiomechanicalAnalysis analyze({
    required String sessionId,
    MonitoringSession? session,
    DateTime? startTime,
    DateTime? endTime,
    Duration? duration,
    int? movementCount,
    required List<SensorReading> readings,
    BiomechanicalAnalysisConfig config = const BiomechanicalAnalysisConfig(),
  }) {
    // 1. Resolve timing and duration boundaries.
    final effectiveStart = session?.startTime ??
        startTime ??
        (readings.isNotEmpty
            ? readings.first.timestamp
            : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));

    final effectiveEnd = session?.endTime ??
        endTime ??
        (readings.isNotEmpty ? readings.last.timestamp : effectiveStart);

    final rawDuration = session?.duration ??
        duration ??
        effectiveEnd.difference(effectiveStart);

    final effectiveDuration = rawDuration < Duration.zero ? Duration.zero : rawDuration;

    // Handle empty readings edge-case.
    if (readings.isEmpty) {
      if (session != null) {
        final mCount = movementCount ?? session.movementCount;
        final durMs = effectiveDuration.inMilliseconds;
        final mpm = (durMs > 0 && mCount > 0)
            ? (mCount / (durMs / Duration.millisecondsPerMinute))
            : 0.0;

        return BiomechanicalAnalysis(
          sessionId: sessionId,
          startTime: effectiveStart,
          endTime: effectiveEnd,
          duration: effectiveDuration,
          sampleCount: 0,
          config: config,
          movementCount: mCount,
          movementsPerMinute: mpm,
          totalTimeMoving: Duration.zero,
          averageMovementDuration: Duration.zero,
          percentageTimeMoving: 0.0,
          averageRestInterval: Duration.zero,
          movementIntervals: const [],
          ipAngleExcursion: math.max(0.0, session.maximumIpAngle - session.averageIpAngle),
          mcpAngleExcursion: math.max(0.0, session.maximumMcpAngle - session.averageMcpAngle),
          averageIpAngularChange: 0.0,
          averageMcpAngularChange: 0.0,
          cumulativeAbsoluteIpAngularChange: 0.0,
          cumulativeAbsoluteMcpAngularChange: 0.0,
          averageForce: session.averageForce,
          peakForce: session.peakForce,
          cumulativeForceExposure: 0.0,
          forceThresholdExceedanceDuration: Duration.zero,
          forceThresholdExceedancePercentage: 0.0,
          forceSampleExceedancePercentage: 0.0,
          averageAngularVelocity: session.averageAngularVelocity,
          peakAngularVelocity: session.averageAngularVelocity,
          cumulativeAngularVelocityExposure: 0.0,
          angularVelocityThresholdExceedanceDuration: Duration.zero,
          angularVelocityThresholdExceedancePercentage: 0.0,
          angularVelocitySampleExceedancePercentage: 0.0,
        );
      }

      return BiomechanicalAnalysis.empty(
        sessionId: sessionId,
        startTime: effectiveStart,
        endTime: effectiveEnd,
        duration: effectiveDuration,
        movementCount: movementCount ?? 0,
        config: config,
      );
    }

    // 2. Extract movement event intervals using two-sensor agreement algorithm.
    final movementIntervals = _extractMovementIntervals(readings, config);
    final calculatedMovementCount = movementIntervals.length;
    final finalMovementCount = movementCount ??
        (calculatedMovementCount > 0
            ? calculatedMovementCount
            : (session?.movementCount ?? calculatedMovementCount));

    var totalTimeMovingMs = 0;
    for (final interval in movementIntervals) {
      totalTimeMovingMs += interval.duration.inMilliseconds;
    }
    final totalTimeMoving = Duration(milliseconds: totalTimeMovingMs);

    final averageMovementDuration = movementIntervals.isNotEmpty
        ? Duration(milliseconds: (totalTimeMovingMs / movementIntervals.length).round())
        : Duration.zero;

    final sessionDurationMs = effectiveDuration.inMilliseconds;
    final percentageTimeMoving = sessionDurationMs > 0
        ? math.min(100.0, (totalTimeMovingMs / sessionDurationMs) * 100.0)
        : 0.0;

    final averageRestInterval = _calculateAverageRestInterval(movementIntervals);

    final movementsPerMinute = (sessionDurationMs > 0 && finalMovementCount > 0)
        ? (finalMovementCount / (sessionDurationMs / Duration.millisecondsPerMinute))
        : 0.0;

    // 3. Joint Kinematics & Angular Change
    var minIp = readings.first.ipAngle;
    var maxIp = readings.first.ipAngle;
    var minMcp = readings.first.mcpAngle;
    var maxMcp = readings.first.mcpAngle;

    var sumIpDelta = 0.0;
    var sumMcpDelta = 0.0;
    var deltaCount = 0;

    for (var i = 0; i < readings.length; i++) {
      final r = readings[i];
      if (r.ipAngle < minIp) minIp = r.ipAngle;
      if (r.ipAngle > maxIp) maxIp = r.ipAngle;
      if (r.mcpAngle < minMcp) minMcp = r.mcpAngle;
      if (r.mcpAngle > maxMcp) maxMcp = r.mcpAngle;

      if (i > 0) {
        final prev = readings[i - 1];
        sumIpDelta += (r.ipAngle - prev.ipAngle).abs();
        sumMcpDelta += (r.mcpAngle - prev.mcpAngle).abs();
        deltaCount++;
      }
    }

    final ipExcursion = maxIp - minIp;
    final mcpExcursion = maxMcp - minMcp;
    final averageIpChange = deltaCount > 0 ? sumIpDelta / deltaCount : 0.0;
    final averageMcpChange = deltaCount > 0 ? sumMcpDelta / deltaCount : 0.0;

    // 4. Force & Motion Intensity Exposures (Integration & Threshold Exceedance)
    var sumForce = 0.0;
    var peakForce = readings.first.force;
    var sumAngVel = 0.0;
    var peakAngVel = readings.first.angularVelocity.abs();

    var forceSamplesAboveThreshold = 0;
    var angVelSamplesAboveThreshold = 0;

    for (final r in readings) {
      sumForce += r.force;
      if (r.force > peakForce) peakForce = r.force;
      if (r.force >= config.forceThreshold) forceSamplesAboveThreshold++;

      final absOmega = r.angularVelocity.abs();
      sumAngVel += absOmega;
      if (absOmega > peakAngVel) peakAngVel = absOmega;
      if (absOmega >= config.angularVelocityThreshold) angVelSamplesAboveThreshold++;
    }

    final averageForce = sumForce / readings.length;
    final averageAngVel = sumAngVel / readings.length;

    final forceSampleExceedancePercentage =
        (forceSamplesAboveThreshold / readings.length) * 100.0;
    final angVelSampleExceedancePercentage =
        (angVelSamplesAboveThreshold / readings.length) * 100.0;

    // Time-series integration over intervals (trapezoidal rule).
    var cumulativeForceExposure = 0.0;
    var cumulativeAngVelExposure = 0.0;
    var forceExceedanceDurationSec = 0.0;
    var angVelExceedanceDurationSec = 0.0;
    var totalValidIntervalTimeSec = 0.0;

    for (var i = 1; i < readings.length; i++) {
      final prev = readings[i - 1];
      final curr = readings[i];

      final diffMicros = curr.timestamp.difference(prev.timestamp).inMicroseconds;
      if (diffMicros <= 0) {
        // Skip negative or zero time intervals safely.
        continue;
      }

      final dt = diffMicros / 1000000.0;
      totalValidIntervalTimeSec += dt;

      // Force trapezoidal integration (N·s)
      cumulativeForceExposure += ((prev.force + curr.force) / 2.0) * dt;

      // Angular velocity trapezoidal integration (degrees)
      final prevOmega = prev.angularVelocity.abs();
      final currOmega = curr.angularVelocity.abs();
      cumulativeAngVelExposure += ((prevOmega + currOmega) / 2.0) * dt;

      // Force threshold exceedance duration
      forceExceedanceDurationSec += _calculateThresholdExceedanceDuration(
        v0: prev.force,
        v1: curr.force,
        threshold: config.forceThreshold,
        dt: dt,
      );

      // Angular velocity threshold exceedance duration
      angVelExceedanceDurationSec += _calculateThresholdExceedanceDuration(
        v0: prevOmega,
        v1: currOmega,
        threshold: config.angularVelocityThreshold,
        dt: dt,
      );
    }

    final forceThresholdExceedanceDuration =
        Duration(microseconds: (forceExceedanceDurationSec * 1000000.0).round());
    final angVelThresholdExceedanceDuration =
        Duration(microseconds: (angVelExceedanceDurationSec * 1000000.0).round());

    final forceThresholdExceedancePercentage = totalValidIntervalTimeSec > 0
        ? math.min(100.0, (forceExceedanceDurationSec / totalValidIntervalTimeSec) * 100.0)
        : 0.0;

    final angVelThresholdExceedancePercentage = totalValidIntervalTimeSec > 0
        ? math.min(100.0, (angVelExceedanceDurationSec / totalValidIntervalTimeSec) * 100.0)
        : 0.0;

    return BiomechanicalAnalysis(
      sessionId: sessionId,
      startTime: effectiveStart,
      endTime: effectiveEnd,
      duration: effectiveDuration,
      sampleCount: readings.length,
      config: config,
      // 1. Movement Metrics
      movementCount: finalMovementCount,
      movementsPerMinute: movementsPerMinute,
      totalTimeMoving: totalTimeMoving,
      averageMovementDuration: averageMovementDuration,
      percentageTimeMoving: percentageTimeMoving,
      averageRestInterval: averageRestInterval,
      movementIntervals: List.unmodifiable(movementIntervals),
      // 2. Joint Motion Metrics
      ipAngleExcursion: ipExcursion,
      mcpAngleExcursion: mcpExcursion,
      averageIpAngularChange: averageIpChange,
      averageMcpAngularChange: averageMcpChange,
      cumulativeAbsoluteIpAngularChange: sumIpDelta,
      cumulativeAbsoluteMcpAngularChange: sumMcpDelta,
      // 3. Force Exposure Metrics
      averageForce: averageForce,
      peakForce: peakForce,
      cumulativeForceExposure: cumulativeForceExposure,
      forceThresholdExceedanceDuration: forceThresholdExceedanceDuration,
      forceThresholdExceedancePercentage: forceThresholdExceedancePercentage,
      forceSampleExceedancePercentage: forceSampleExceedancePercentage,
      // 4. Motion Intensity Metrics
      averageAngularVelocity: averageAngVel,
      peakAngularVelocity: peakAngVel,
      cumulativeAngularVelocityExposure: cumulativeAngVelExposure,
      angularVelocityThresholdExceedanceDuration: angVelThresholdExceedanceDuration,
      angularVelocityThresholdExceedancePercentage: angVelThresholdExceedancePercentage,
      angularVelocitySampleExceedancePercentage: angVelSampleExceedancePercentage,
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Extracts individual movement intervals using the two-sensor agreement model.
  static List<MovementEventInterval> _extractMovementIntervals(
    List<SensorReading> readings,
    BiomechanicalAnalysisConfig config,
  ) {
    if (readings.length < 2) return const [];

    final intervals = <MovementEventInterval>[];
    bool isMoving = false;
    DateTime? movementStart;
    DateTime? lastActiveTimestamp;

    for (var i = 1; i < readings.length; i++) {
      final prev = readings[i - 1];
      final curr = readings[i];

      final deltaIp = (curr.ipAngle - prev.ipAngle).abs();
      final deltaMcp = (curr.mcpAngle - prev.mcpAngle).abs();
      final flexSignal =
          deltaIp >= config.ipAngleChangeDeg || deltaMcp >= config.mcpAngleChangeDeg;

      final imuSignal = curr.angularVelocity.abs() >= config.angularVelocityThreshold ||
          curr.motionMagnitude >= config.motionMagnitudeG;

      final active = flexSignal && imuSignal;

      if (active) {
        lastActiveTimestamp = curr.timestamp;
        if (!isMoving) {
          movementStart = curr.timestamp;
          isMoving = true;
        }
      } else if (isMoving && lastActiveTimestamp != null) {
        final inactiveDuration = curr.timestamp.difference(lastActiveTimestamp);
        if (inactiveDuration >= config.movementEndDebounce) {
          if (movementStart != null &&
              lastActiveTimestamp.difference(movementStart) >=
                  config.minimumMovementDuration) {
            intervals.add(MovementEventInterval(
              startTime: movementStart,
              endTime: lastActiveTimestamp,
            ));
          }
          isMoving = false;
          movementStart = null;
          lastActiveTimestamp = null;
        }
      }
    }

    // Close any trailing event if monitoring stopped during active motion.
    if (isMoving && movementStart != null && lastActiveTimestamp != null) {
      if (lastActiveTimestamp.difference(movementStart) >= config.minimumMovementDuration) {
        intervals.add(MovementEventInterval(
          startTime: movementStart,
          endTime: lastActiveTimestamp,
        ));
      }
    }

    return intervals;
  }

  /// Calculates the average rest interval between consecutive movement events.
  static Duration _calculateAverageRestInterval(List<MovementEventInterval> intervals) {
    if (intervals.length < 2) return Duration.zero;

    var totalRestMs = 0;
    var restCount = 0;

    for (var i = 1; i < intervals.length; i++) {
      final prevEnd = intervals[i - 1].endTime;
      final currStart = intervals[i].startTime;
      final restDiff = currStart.difference(prevEnd).inMilliseconds;
      if (restDiff > 0) {
        totalRestMs += restDiff;
        restCount++;
      }
    }

    return restCount > 0
        ? Duration(milliseconds: (totalRestMs / restCount).round())
        : Duration.zero;
  }

  /// Computes the duration in seconds where a linearly interpolated signal
  /// exceeds [threshold] during interval [dt].
  static double _calculateThresholdExceedanceDuration({
    required double v0,
    required double v1,
    required double threshold,
    required double dt,
  }) {
    if (dt <= 0) return 0.0;

    final above0 = v0 >= threshold;
    final above1 = v1 >= threshold;

    if (above0 && above1) {
      return dt;
    } else if (!above0 && !above1) {
      return 0.0;
    }

    // Linear interpolation crossing
    final deltaV = (v1 - v0).abs();
    if (deltaV < 1e-9) return 0.0;

    if (!above0 && above1) {
      // Crossing from below to above
      final fractionAbove = (v1 - threshold) / deltaV;
      return math.max(0.0, math.min(dt, fractionAbove * dt));
    } else {
      // Crossing from above to below
      final fractionAbove = (v0 - threshold) / deltaV;
      return math.max(0.0, math.min(dt, fractionAbove * dt));
    }
  }
}
