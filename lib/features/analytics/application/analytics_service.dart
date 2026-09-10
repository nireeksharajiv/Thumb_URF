
import '../../../core/models/monitoring_session.dart';
import '../../../core/models/sensor_reading.dart';
import '../../../core/services/monitoring_session_repository.dart';
import '../domain/models/session_analytics.dart';

/// Application service responsible for calculating research-relevant
/// biomechanical metrics from stored [SensorReading] time-series data
/// and [MonitoringSession] summaries.
///
/// Decoupled from UI widgets and hardware implementations.
/// Accesses data purely through the [MonitoringSessionRepository] abstraction.
class AnalyticsService {
  const AnalyticsService(this._repository);

  final MonitoringSessionRepository _repository;

  /// Computes comprehensive [SessionAnalytics] for a specific session by [sessionId].
  ///
  /// Obtains the [MonitoringSession] metadata (if exists) and all associated raw
  /// [SensorReading] time-series samples via the configured repository.
  /// Works uniformly across Local storage, Supabase, and Demo mode.
  Future<SessionAnalytics> computeSessionAnalytics(String sessionId) async {
    final session = await _repository.getSessionById(sessionId);
    final readings = await _repository.getSensorReadings(sessionId);

    return calculate(
      sessionId: sessionId,
      session: session,
      readings: readings,
    );
  }

  /// Computes [SessionAnalytics] for all sessions currently available in the repository,
  /// ordered newest first.
  Future<List<SessionAnalytics>> computeAllSessionsAnalytics() async {
    final sessions = await _repository.getSessions();
    final results = <SessionAnalytics>[];

    for (final session in sessions) {
      final readings = await _repository.getSensorReadings(session.id);
      results.add(
        calculate(
          sessionId: session.id,
          session: session,
          readings: readings,
        ),
      );
    }

    return List.unmodifiable(results);
  }

  /// Deterministic, pure calculation function that computes [SessionAnalytics]
  /// from a batch of [SensorReading]s and optional session metadata.
  ///
  /// Handles empty datasets, single-reading datasets, zero-duration sessions,
  /// and missing values safely without throwing exceptions or dividing by zero.
  static SessionAnalytics calculate({
    required String sessionId,
    MonitoringSession? session,
    DateTime? startTime,
    DateTime? endTime,
    Duration? duration,
    int? movementCount,
    required List<SensorReading> readings,
  }) {
    // 1. Resolve session metadata & timing.
    final effectiveStart = session?.startTime ??
        startTime ??
        (readings.isNotEmpty ? readings.first.timestamp : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));

    final effectiveEnd = session?.endTime ??
        endTime ??
        (readings.isNotEmpty ? readings.last.timestamp : effectiveStart);

    final rawDuration = session?.duration ??
        duration ??
        effectiveEnd.difference(effectiveStart);

    final effectiveDuration = rawDuration < Duration.zero ? Duration.zero : rawDuration;
    final effectiveMovements = session?.movementCount ?? movementCount ?? 0;

    // Filter to only finite, valid readings to ensure resilience.
    final validReadings = readings
        .where((r) =>
            r.ipAngle.isFinite &&
            r.mcpAngle.isFinite &&
            r.force.isFinite &&
            r.angularVelocity.isFinite &&
            r.motionMagnitude.isFinite)
        .toList();

    final sampleCount = validReadings.length;

    // 2. Compute movements per minute safely.
    final double movementsPerMinute;
    if (effectiveDuration.inMicroseconds > 0 && effectiveMovements > 0) {
      final durationInMinutes =
          effectiveDuration.inMicroseconds / (60.0 * 1000000.0);
      movementsPerMinute = effectiveMovements / durationInMinutes;
    } else {
      movementsPerMinute = 0.0;
    }

    // 3. Handle empty readings edge case.
    if (sampleCount == 0) {
      if (session != null) {
        // Fall back gracefully to session summary values if available
        return SessionAnalytics(
          sessionId: sessionId,
          startTime: effectiveStart,
          endTime: effectiveEnd,
          duration: effectiveDuration,
          sampleCount: 0,
          movementCount: effectiveMovements,
          movementsPerMinute: movementsPerMinute,
          averageIpAngle: session.averageIpAngle,
          minimumIpAngle: session.averageIpAngle,
          maximumIpAngle: session.maximumIpAngle,
          ipAngleExcursion: session.maximumIpAngle - session.averageIpAngle >= 0
              ? session.maximumIpAngle - session.averageIpAngle
              : 0.0,
          averageMcpAngle: session.averageMcpAngle,
          minimumMcpAngle: session.averageMcpAngle,
          maximumMcpAngle: session.maximumMcpAngle,
          mcpAngleExcursion: session.maximumMcpAngle - session.averageMcpAngle >= 0
              ? session.maximumMcpAngle - session.averageMcpAngle
              : 0.0,
          averageForce: session.averageForce,
          peakForce: session.peakForce,
          averageAngularVelocity: session.averageAngularVelocity,
          peakAngularVelocity: session.averageAngularVelocity,
          averageMotionMagnitude: session.averageMotionMagnitude,
          peakMotionMagnitude: session.averageMotionMagnitude,
        );
      }

      return SessionAnalytics.empty(
        sessionId: sessionId,
        startTime: effectiveStart,
        endTime: effectiveEnd,
        duration: effectiveDuration,
        movementCount: effectiveMovements,
      );
    }

    // 4. Compute metrics from raw SensorReading samples.
    var sumIp = 0.0;
    var minIp = double.infinity;
    var maxIp = -double.infinity;

    var sumMcp = 0.0;
    var minMcp = double.infinity;
    var maxMcp = -double.infinity;

    var sumForce = 0.0;
    var peakForce = -double.infinity;

    var sumAngVel = 0.0;
    var peakAngVel = 0.0;

    var sumMotionMag = 0.0;
    var peakMotionMag = -double.infinity;

    for (final r in validReadings) {
      // IP Angle
      sumIp += r.ipAngle;
      if (r.ipAngle < minIp) minIp = r.ipAngle;
      if (r.ipAngle > maxIp) maxIp = r.ipAngle;

      // MCP Angle
      sumMcp += r.mcpAngle;
      if (r.mcpAngle < minMcp) minMcp = r.mcpAngle;
      if (r.mcpAngle > maxMcp) maxMcp = r.mcpAngle;

      // Force
      sumForce += r.force;
      if (r.force > peakForce) peakForce = r.force;

      // Angular Velocity (absolute magnitude for rotational speed)
      final absAngVel = r.angularVelocity.abs();
      sumAngVel += absAngVel;
      if (absAngVel > peakAngVel) peakAngVel = absAngVel;

      // Motion Magnitude
      sumMotionMag += r.motionMagnitude;
      if (r.motionMagnitude > peakMotionMag) peakMotionMag = r.motionMagnitude;
    }

    final averageIp = sumIp / sampleCount;
    final averageMcp = sumMcp / sampleCount;
    final averageForce = sumForce / sampleCount;
    final averageAngVel = sumAngVel / sampleCount;
    final averageMotionMag = sumMotionMag / sampleCount;

    // Angle excursion: observed range (maximum - minimum)
    final ipExcursion = maxIp - minIp;
    final mcpExcursion = maxMcp - minMcp;

    return SessionAnalytics(
      sessionId: sessionId,
      startTime: effectiveStart,
      endTime: effectiveEnd,
      duration: effectiveDuration,
      sampleCount: sampleCount,
      movementCount: effectiveMovements,
      movementsPerMinute: movementsPerMinute,
      averageIpAngle: averageIp,
      minimumIpAngle: minIp,
      maximumIpAngle: maxIp,
      ipAngleExcursion: ipExcursion >= 0 ? ipExcursion : 0.0,
      averageMcpAngle: averageMcp,
      minimumMcpAngle: minMcp,
      maximumMcpAngle: maxMcp,
      mcpAngleExcursion: mcpExcursion >= 0 ? mcpExcursion : 0.0,
      averageForce: averageForce,
      peakForce: peakForce,
      averageAngularVelocity: averageAngVel,
      peakAngularVelocity: peakAngVel,
      averageMotionMagnitude: averageMotionMag,
      peakMotionMagnitude: peakMotionMag,
    );
  }
}
