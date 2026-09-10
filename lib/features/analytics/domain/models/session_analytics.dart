import 'package:flutter/foundation.dart';

/// Immutable domain model representing calculated biomechanical analytics
/// for a single monitoring session.
///
/// Contains aggregate session statistics derived from raw [SensorReading]s
/// and [MonitoringSession] metadata.
@immutable
class SessionAnalytics {
  const SessionAnalytics({
    required this.sessionId,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.sampleCount,
    required this.movementCount,
    required this.movementsPerMinute,
    required this.averageIpAngle,
    required this.minimumIpAngle,
    required this.maximumIpAngle,
    required this.ipAngleExcursion,
    required this.averageMcpAngle,
    required this.minimumMcpAngle,
    required this.maximumMcpAngle,
    required this.mcpAngleExcursion,
    required this.averageForce,
    required this.peakForce,
    required this.averageAngularVelocity,
    required this.peakAngularVelocity,
    required this.averageMotionMagnitude,
    required this.peakMotionMagnitude,
  });

  /// Factory constructor for empty/zero-data sessions.
  factory SessionAnalytics.empty({
    required String sessionId,
    DateTime? startTime,
    DateTime? endTime,
    Duration? duration,
    int movementCount = 0,
  }) {
    final start = startTime ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final end = endTime ?? start;
    final dur = duration ?? end.difference(start);

    return SessionAnalytics(
      sessionId: sessionId,
      startTime: start,
      endTime: end,
      duration: dur < Duration.zero ? Duration.zero : dur,
      sampleCount: 0,
      movementCount: movementCount,
      movementsPerMinute: 0.0,
      averageIpAngle: 0.0,
      minimumIpAngle: 0.0,
      maximumIpAngle: 0.0,
      ipAngleExcursion: 0.0,
      averageMcpAngle: 0.0,
      minimumMcpAngle: 0.0,
      maximumMcpAngle: 0.0,
      mcpAngleExcursion: 0.0,
      averageForce: 0.0,
      peakForce: 0.0,
      averageAngularVelocity: 0.0,
      peakAngularVelocity: 0.0,
      averageMotionMagnitude: 0.0,
      peakMotionMagnitude: 0.0,
    );
  }

  final String sessionId;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final int sampleCount;
  final int movementCount;
  final double movementsPerMinute;

  // Interphalangeal (IP) Joint Metrics
  final double averageIpAngle;
  final double minimumIpAngle;
  final double maximumIpAngle;
  final double ipAngleExcursion;

  // Metacarpophalangeal (MCP) Joint Metrics
  final double averageMcpAngle;
  final double minimumMcpAngle;
  final double maximumMcpAngle;
  final double mcpAngleExcursion;

  // Thumb-tip Force Metrics (N)
  final double averageForce;
  final double peakForce;

  // Angular Velocity Metrics (°/s)
  final double averageAngularVelocity;
  final double peakAngularVelocity;

  // Motion Magnitude Metrics
  final double averageMotionMagnitude;
  final double peakMotionMagnitude;

  /// Whether raw sensor samples were available to compute these analytics.
  bool get hasReadings => sampleCount > 0;

  Map<String, Object> toJson() => {
        'sessionId': sessionId,
        'startTime': startTime.toUtc().toIso8601String(),
        'endTime': endTime.toUtc().toIso8601String(),
        'durationMs': duration.inMilliseconds,
        'sampleCount': sampleCount,
        'movementCount': movementCount,
        'movementsPerMinute': movementsPerMinute,
        'averageIpAngle': averageIpAngle,
        'minimumIpAngle': minimumIpAngle,
        'maximumIpAngle': maximumIpAngle,
        'ipAngleExcursion': ipAngleExcursion,
        'averageMcpAngle': averageMcpAngle,
        'minimumMcpAngle': minimumMcpAngle,
        'maximumMcpAngle': maximumMcpAngle,
        'mcpAngleExcursion': mcpAngleExcursion,
        'averageForce': averageForce,
        'peakForce': peakForce,
        'averageAngularVelocity': averageAngularVelocity,
        'peakAngularVelocity': peakAngularVelocity,
        'averageMotionMagnitude': averageMotionMagnitude,
        'peakMotionMagnitude': peakMotionMagnitude,
      };

  factory SessionAnalytics.fromJson(Map<String, Object?> json) {
    double readNum(String key) {
      final v = json[key];
      if (v is num) return v.toDouble();
      throw FormatException('Expected numeric value for "$key".');
    }

    int readInt(String key) {
      final v = json[key];
      if (v is num) return v.toInt();
      throw FormatException('Expected integer value for "$key".');
    }

    final startStr = json['startTime']?.toString();
    final endStr = json['endTime']?.toString();
    if (startStr == null || endStr == null) {
      throw const FormatException('Missing startTime or endTime in SessionAnalytics JSON.');
    }

    return SessionAnalytics(
      sessionId: json['sessionId']?.toString() ?? '',
      startTime: DateTime.parse(startStr).toUtc(),
      endTime: DateTime.parse(endStr).toUtc(),
      duration: Duration(milliseconds: readInt('durationMs')),
      sampleCount: readInt('sampleCount'),
      movementCount: readInt('movementCount'),
      movementsPerMinute: readNum('movementsPerMinute'),
      averageIpAngle: readNum('averageIpAngle'),
      minimumIpAngle: readNum('minimumIpAngle'),
      maximumIpAngle: readNum('maximumIpAngle'),
      ipAngleExcursion: readNum('ipAngleExcursion'),
      averageMcpAngle: readNum('averageMcpAngle'),
      minimumMcpAngle: readNum('minimumMcpAngle'),
      maximumMcpAngle: readNum('maximumMcpAngle'),
      mcpAngleExcursion: readNum('mcpAngleExcursion'),
      averageForce: readNum('averageForce'),
      peakForce: readNum('peakForce'),
      averageAngularVelocity: readNum('averageAngularVelocity'),
      peakAngularVelocity: readNum('peakAngularVelocity'),
      averageMotionMagnitude: readNum('averageMotionMagnitude'),
      peakMotionMagnitude: readNum('peakMotionMagnitude'),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionAnalytics &&
          runtimeType == other.runtimeType &&
          sessionId == other.sessionId &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          duration == other.duration &&
          sampleCount == other.sampleCount &&
          movementCount == other.movementCount &&
          (movementsPerMinute - other.movementsPerMinute).abs() < 1e-6 &&
          (averageIpAngle - other.averageIpAngle).abs() < 1e-6 &&
          (minimumIpAngle - other.minimumIpAngle).abs() < 1e-6 &&
          (maximumIpAngle - other.maximumIpAngle).abs() < 1e-6 &&
          (ipAngleExcursion - other.ipAngleExcursion).abs() < 1e-6 &&
          (averageMcpAngle - other.averageMcpAngle).abs() < 1e-6 &&
          (minimumMcpAngle - other.minimumMcpAngle).abs() < 1e-6 &&
          (maximumMcpAngle - other.maximumMcpAngle).abs() < 1e-6 &&
          (mcpAngleExcursion - other.mcpAngleExcursion).abs() < 1e-6 &&
          (averageForce - other.averageForce).abs() < 1e-6 &&
          (peakForce - other.peakForce).abs() < 1e-6 &&
          (averageAngularVelocity - other.averageAngularVelocity).abs() < 1e-6 &&
          (peakAngularVelocity - other.peakAngularVelocity).abs() < 1e-6 &&
          (averageMotionMagnitude - other.averageMotionMagnitude).abs() < 1e-6 &&
          (peakMotionMagnitude - other.peakMotionMagnitude).abs() < 1e-6;

  @override
  int get hashCode => Object.hashAll([
        sessionId,
        startTime,
        endTime,
        duration,
        sampleCount,
        movementCount,
        movementsPerMinute,
        averageIpAngle,
        minimumIpAngle,
        maximumIpAngle,
        ipAngleExcursion,
        averageMcpAngle,
        minimumMcpAngle,
        maximumMcpAngle,
        mcpAngleExcursion,
        averageForce,
        peakForce,
        averageAngularVelocity,
        peakAngularVelocity,
        averageMotionMagnitude,
        peakMotionMagnitude,
      ]);

  @override
  String toString() => 'SessionAnalytics('
      'sessionId: $sessionId, '
      'samples: $sampleCount, '
      'duration: $duration, '
      'movements: $movementCount (${movementsPerMinute.toStringAsFixed(1)}/min), '
      'IP: avg=${averageIpAngle.toStringAsFixed(1)}° min=${minimumIpAngle.toStringAsFixed(1)}° '
      'max=${maximumIpAngle.toStringAsFixed(1)}° exc=${ipAngleExcursion.toStringAsFixed(1)}°, '
      'MCP: avg=${averageMcpAngle.toStringAsFixed(1)}° min=${minimumMcpAngle.toStringAsFixed(1)}° '
      'max=${maximumMcpAngle.toStringAsFixed(1)}° exc=${mcpAngleExcursion.toStringAsFixed(1)}°, '
      'Force: avg=${averageForce.toStringAsFixed(2)}N peak=${peakForce.toStringAsFixed(2)}N, '
      'AngVel: avg=${averageAngularVelocity.toStringAsFixed(1)}°/s peak=${peakAngularVelocity.toStringAsFixed(1)}°/s, '
      'Motion: avg=${averageMotionMagnitude.toStringAsFixed(2)} peak=${peakMotionMagnitude.toStringAsFixed(2)})';
}
