import 'package:flutter/foundation.dart';

import '../../../../core/services/movement_detection_config.dart';

/// Configurable parameters for research-grade biomechanical exposure analysis.
///
/// Contains explicit parameters with neutral research defaults.
/// Does NOT contain clinical, medical, or diagnostic thresholds.
@immutable
class BiomechanicalAnalysisConfig {
  const BiomechanicalAnalysisConfig({
    this.forceThreshold = 2.0,
    this.angularVelocityThreshold = 30.0,
    this.ipAngleChangeDeg = MovementDetectionConfig.ipAngleChangeDeg,
    this.mcpAngleChangeDeg = MovementDetectionConfig.mcpAngleChangeDeg,
    this.motionMagnitudeG = MovementDetectionConfig.motionMagnitudeG,
    this.minimumMovementDuration = MovementDetectionConfig.minimumMovementDuration,
    this.movementEndDebounce = MovementDetectionConfig.movementEndDebounce,
  });

  /// Configurable force exposure threshold in Newtons (N).
  final double forceThreshold;

  /// Configurable angular velocity threshold in degrees per second (°/s).
  final double angularVelocityThreshold;

  /// Flex sensor angular delta threshold for IP joint flex signal.
  final double ipAngleChangeDeg;

  /// Flex sensor angular delta threshold for MCP joint flex signal.
  final double mcpAngleChangeDeg;

  /// Accelerometer motion magnitude threshold in g.
  final double motionMagnitudeG;

  /// Minimum measured movement event duration to be classified as a movement.
  final Duration minimumMovementDuration;

  /// Inactivity period before finalizing an active movement event.
  final Duration movementEndDebounce;

  Map<String, Object> toJson() => {
        'forceThreshold': forceThreshold,
        'angularVelocityThreshold': angularVelocityThreshold,
        'ipAngleChangeDeg': ipAngleChangeDeg,
        'mcpAngleChangeDeg': mcpAngleChangeDeg,
        'motionMagnitudeG': motionMagnitudeG,
        'minimumMovementDurationMs': minimumMovementDuration.inMilliseconds,
        'movementEndDebounceMs': movementEndDebounce.inMilliseconds,
      };

  factory BiomechanicalAnalysisConfig.fromJson(Map<String, Object?> json) {
    return BiomechanicalAnalysisConfig(
      forceThreshold: (json['forceThreshold'] as num?)?.toDouble() ?? 2.0,
      angularVelocityThreshold: (json['angularVelocityThreshold'] as num?)?.toDouble() ?? 30.0,
      ipAngleChangeDeg: (json['ipAngleChangeDeg'] as num?)?.toDouble() ?? MovementDetectionConfig.ipAngleChangeDeg,
      mcpAngleChangeDeg: (json['mcpAngleChangeDeg'] as num?)?.toDouble() ?? MovementDetectionConfig.mcpAngleChangeDeg,
      motionMagnitudeG: (json['motionMagnitudeG'] as num?)?.toDouble() ?? MovementDetectionConfig.motionMagnitudeG,
      minimumMovementDuration: json['minimumMovementDurationMs'] != null
          ? Duration(milliseconds: (json['minimumMovementDurationMs'] as num).toInt())
          : MovementDetectionConfig.minimumMovementDuration,
      movementEndDebounce: json['movementEndDebounceMs'] != null
          ? Duration(milliseconds: (json['movementEndDebounceMs'] as num).toInt())
          : MovementDetectionConfig.movementEndDebounce,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BiomechanicalAnalysisConfig &&
          runtimeType == other.runtimeType &&
          forceThreshold == other.forceThreshold &&
          angularVelocityThreshold == other.angularVelocityThreshold &&
          ipAngleChangeDeg == other.ipAngleChangeDeg &&
          mcpAngleChangeDeg == other.mcpAngleChangeDeg &&
          motionMagnitudeG == other.motionMagnitudeG &&
          minimumMovementDuration == other.minimumMovementDuration &&
          movementEndDebounce == other.movementEndDebounce;

  @override
  int get hashCode => Object.hash(
        forceThreshold,
        angularVelocityThreshold,
        ipAngleChangeDeg,
        mcpAngleChangeDeg,
        motionMagnitudeG,
        minimumMovementDuration,
        movementEndDebounce,
      );
}

/// Immutable record of a single detected movement interval.
@immutable
class MovementEventInterval {
  const MovementEventInterval({
    required this.startTime,
    required this.endTime,
  });

  final DateTime startTime;
  final DateTime endTime;

  Duration get duration {
    final diff = endTime.difference(startTime);
    return diff < Duration.zero ? Duration.zero : diff;
  }

  Map<String, Object> toJson() => {
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'durationMs': duration.inMilliseconds,
      };

  factory MovementEventInterval.fromJson(Map<String, Object?> json) {
    return MovementEventInterval(
      startTime: DateTime.parse(json['startTime'] as String).toUtc(),
      endTime: DateTime.parse(json['endTime'] as String).toUtc(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MovementEventInterval &&
          runtimeType == other.runtimeType &&
          startTime == other.startTime &&
          endTime == other.endTime;

  @override
  int get hashCode => Object.hash(startTime, endTime);
}

/// Immutable domain model representing in-depth biomechanical exposure metrics
/// for an engineering research monitoring session.
///
/// **Non-Diagnostic Notice**: All metrics represent engineering research telemetry
/// and biomechanical loading exposure. Does NOT represent clinical stress,
/// RSI risk, disease diagnosis, or medical evaluation.
@immutable
class BiomechanicalAnalysis {
  const BiomechanicalAnalysis({
    required this.sessionId,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.sampleCount,
    required this.config,
    // 1. Movement Metrics
    required this.movementCount,
    required this.movementsPerMinute,
    required this.totalTimeMoving,
    required this.averageMovementDuration,
    required this.percentageTimeMoving,
    required this.averageRestInterval,
    this.movementIntervals = const [],
    // 2. Joint Motion Metrics
    required this.ipAngleExcursion,
    required this.mcpAngleExcursion,
    required this.averageIpAngularChange,
    required this.averageMcpAngularChange,
    required this.cumulativeAbsoluteIpAngularChange,
    required this.cumulativeAbsoluteMcpAngularChange,
    // 3. Force Exposure Metrics
    required this.averageForce,
    required this.peakForce,
    required this.cumulativeForceExposure,
    required this.forceThresholdExceedanceDuration,
    required this.forceThresholdExceedancePercentage,
    required this.forceSampleExceedancePercentage,
    // 4. Motion Intensity Metrics
    required this.averageAngularVelocity,
    required this.peakAngularVelocity,
    required this.cumulativeAngularVelocityExposure,
    required this.angularVelocityThresholdExceedanceDuration,
    required this.angularVelocityThresholdExceedancePercentage,
    required this.angularVelocitySampleExceedancePercentage,
  });

  /// Factory constructor for empty/zero-data sessions.
  factory BiomechanicalAnalysis.empty({
    required String sessionId,
    DateTime? startTime,
    DateTime? endTime,
    Duration? duration,
    int movementCount = 0,
    BiomechanicalAnalysisConfig config = const BiomechanicalAnalysisConfig(),
  }) {
    final start = startTime ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final end = endTime ?? start;
    final dur = duration ?? end.difference(start);

    return BiomechanicalAnalysis(
      sessionId: sessionId,
      startTime: start,
      endTime: end,
      duration: dur < Duration.zero ? Duration.zero : dur,
      sampleCount: 0,
      config: config,
      movementCount: movementCount,
      movementsPerMinute: 0.0,
      totalTimeMoving: Duration.zero,
      averageMovementDuration: Duration.zero,
      percentageTimeMoving: 0.0,
      averageRestInterval: Duration.zero,
      movementIntervals: const [],
      ipAngleExcursion: 0.0,
      mcpAngleExcursion: 0.0,
      averageIpAngularChange: 0.0,
      averageMcpAngularChange: 0.0,
      cumulativeAbsoluteIpAngularChange: 0.0,
      cumulativeAbsoluteMcpAngularChange: 0.0,
      averageForce: 0.0,
      peakForce: 0.0,
      cumulativeForceExposure: 0.0,
      forceThresholdExceedanceDuration: Duration.zero,
      forceThresholdExceedancePercentage: 0.0,
      forceSampleExceedancePercentage: 0.0,
      averageAngularVelocity: 0.0,
      peakAngularVelocity: 0.0,
      cumulativeAngularVelocityExposure: 0.0,
      angularVelocityThresholdExceedanceDuration: Duration.zero,
      angularVelocityThresholdExceedancePercentage: 0.0,
      angularVelocitySampleExceedancePercentage: 0.0,
    );
  }

  final String sessionId;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final int sampleCount;
  final BiomechanicalAnalysisConfig config;

  // 1. Movement Metrics
  final int movementCount;
  final double movementsPerMinute;
  final Duration totalTimeMoving;
  final Duration averageMovementDuration;
  final double percentageTimeMoving;
  final Duration averageRestInterval;
  final List<MovementEventInterval> movementIntervals;

  // 2. Joint Motion Metrics
  final double ipAngleExcursion;
  final double mcpAngleExcursion;
  final double averageIpAngularChange;
  final double averageMcpAngularChange;
  final double cumulativeAbsoluteIpAngularChange;
  final double cumulativeAbsoluteMcpAngularChange;

  // 3. Force Exposure Metrics
  final double averageForce;
  final double peakForce;
  /// Cumulative force exposure in Newton-seconds (N·s) via trapezoidal numerical integration.
  final double cumulativeForceExposure;
  final Duration forceThresholdExceedanceDuration;
  final double forceThresholdExceedancePercentage;
  final double forceSampleExceedancePercentage;

  // 4. Motion Intensity Metrics
  final double averageAngularVelocity;
  final double peakAngularVelocity;
  /// Cumulative angular velocity exposure in degrees (°) via trapezoidal numerical integration.
  final double cumulativeAngularVelocityExposure;
  final Duration angularVelocityThresholdExceedanceDuration;
  final double angularVelocityThresholdExceedancePercentage;
  final double angularVelocitySampleExceedancePercentage;

  bool get hasReadings => sampleCount > 0;

  Map<String, Object> toJson() => {
        'sessionId': sessionId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'durationMs': duration.inMilliseconds,
        'sampleCount': sampleCount,
        'config': config.toJson(),
        'movementCount': movementCount,
        'movementsPerMinute': movementsPerMinute,
        'totalTimeMovingMs': totalTimeMoving.inMilliseconds,
        'averageMovementDurationMs': averageMovementDuration.inMilliseconds,
        'percentageTimeMoving': percentageTimeMoving,
        'averageRestIntervalMs': averageRestInterval.inMilliseconds,
        'movementIntervals': movementIntervals.map((i) => i.toJson()).toList(),
        'ipAngleExcursion': ipAngleExcursion,
        'mcpAngleExcursion': mcpAngleExcursion,
        'averageIpAngularChange': averageIpAngularChange,
        'averageMcpAngularChange': averageMcpAngularChange,
        'cumulativeAbsoluteIpAngularChange': cumulativeAbsoluteIpAngularChange,
        'cumulativeAbsoluteMcpAngularChange': cumulativeAbsoluteMcpAngularChange,
        'averageForce': averageForce,
        'peakForce': peakForce,
        'cumulativeForceExposure': cumulativeForceExposure,
        'forceThresholdExceedanceDurationMs': forceThresholdExceedanceDuration.inMilliseconds,
        'forceThresholdExceedancePercentage': forceThresholdExceedancePercentage,
        'forceSampleExceedancePercentage': forceSampleExceedancePercentage,
        'averageAngularVelocity': averageAngularVelocity,
        'peakAngularVelocity': peakAngularVelocity,
        'cumulativeAngularVelocityExposure': cumulativeAngularVelocityExposure,
        'angularVelocityThresholdExceedanceDurationMs':
            angularVelocityThresholdExceedanceDuration.inMilliseconds,
        'angularVelocityThresholdExceedancePercentage':
            angularVelocityThresholdExceedancePercentage,
        'angularVelocitySampleExceedancePercentage':
            angularVelocitySampleExceedancePercentage,
      };

  factory BiomechanicalAnalysis.fromJson(Map<String, Object?> json) {
    final intervalsRaw = json['movementIntervals'];
    final intervals = <MovementEventInterval>[];
    if (intervalsRaw is List) {
      for (final item in intervalsRaw) {
        if (item is Map<String, Object?>) {
          intervals.add(MovementEventInterval.fromJson(item));
        }
      }
    }

    final configRaw = json['config'];
    final config = configRaw is Map<String, Object?>
        ? BiomechanicalAnalysisConfig.fromJson(configRaw)
        : const BiomechanicalAnalysisConfig();

    return BiomechanicalAnalysis(
      sessionId: json['sessionId'] as String? ?? '',
      startTime: DateTime.parse(json['startTime'] as String).toUtc(),
      endTime: DateTime.parse(json['endTime'] as String).toUtc(),
      duration: Duration(milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0),
      sampleCount: (json['sampleCount'] as num?)?.toInt() ?? 0,
      config: config,
      movementCount: (json['movementCount'] as num?)?.toInt() ?? 0,
      movementsPerMinute: (json['movementsPerMinute'] as num?)?.toDouble() ?? 0.0,
      totalTimeMoving: Duration(milliseconds: (json['totalTimeMovingMs'] as num?)?.toInt() ?? 0),
      averageMovementDuration:
          Duration(milliseconds: (json['averageMovementDurationMs'] as num?)?.toInt() ?? 0),
      percentageTimeMoving: (json['percentageTimeMoving'] as num?)?.toDouble() ?? 0.0,
      averageRestInterval:
          Duration(milliseconds: (json['averageRestIntervalMs'] as num?)?.toInt() ?? 0),
      movementIntervals: List.unmodifiable(intervals),
      ipAngleExcursion: (json['ipAngleExcursion'] as num?)?.toDouble() ?? 0.0,
      mcpAngleExcursion: (json['mcpAngleExcursion'] as num?)?.toDouble() ?? 0.0,
      averageIpAngularChange: (json['averageIpAngularChange'] as num?)?.toDouble() ?? 0.0,
      averageMcpAngularChange: (json['averageMcpAngularChange'] as num?)?.toDouble() ?? 0.0,
      cumulativeAbsoluteIpAngularChange:
          (json['cumulativeAbsoluteIpAngularChange'] as num?)?.toDouble() ?? 0.0,
      cumulativeAbsoluteMcpAngularChange:
          (json['cumulativeAbsoluteMcpAngularChange'] as num?)?.toDouble() ?? 0.0,
      averageForce: (json['averageForce'] as num?)?.toDouble() ?? 0.0,
      peakForce: (json['peakForce'] as num?)?.toDouble() ?? 0.0,
      cumulativeForceExposure: (json['cumulativeForceExposure'] as num?)?.toDouble() ?? 0.0,
      forceThresholdExceedanceDuration:
          Duration(milliseconds: (json['forceThresholdExceedanceDurationMs'] as num?)?.toInt() ?? 0),
      forceThresholdExceedancePercentage:
          (json['forceThresholdExceedancePercentage'] as num?)?.toDouble() ?? 0.0,
      forceSampleExceedancePercentage:
          (json['forceSampleExceedancePercentage'] as num?)?.toDouble() ?? 0.0,
      averageAngularVelocity: (json['averageAngularVelocity'] as num?)?.toDouble() ?? 0.0,
      peakAngularVelocity: (json['peakAngularVelocity'] as num?)?.toDouble() ?? 0.0,
      cumulativeAngularVelocityExposure:
          (json['cumulativeAngularVelocityExposure'] as num?)?.toDouble() ?? 0.0,
      angularVelocityThresholdExceedanceDuration: Duration(
          milliseconds:
              (json['angularVelocityThresholdExceedanceDurationMs'] as num?)?.toInt() ?? 0),
      angularVelocityThresholdExceedancePercentage:
          (json['angularVelocityThresholdExceedancePercentage'] as num?)?.toDouble() ?? 0.0,
      angularVelocitySampleExceedancePercentage:
          (json['angularVelocitySampleExceedancePercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BiomechanicalAnalysis &&
          runtimeType == other.runtimeType &&
          sessionId == other.sessionId &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          duration == other.duration &&
          sampleCount == other.sampleCount &&
          config == other.config &&
          movementCount == other.movementCount &&
          (movementsPerMinute - other.movementsPerMinute).abs() < 1e-6 &&
          totalTimeMoving == other.totalTimeMoving &&
          averageMovementDuration == other.averageMovementDuration &&
          (percentageTimeMoving - other.percentageTimeMoving).abs() < 1e-6 &&
          averageRestInterval == other.averageRestInterval &&
          listEquals(movementIntervals, other.movementIntervals) &&
          (ipAngleExcursion - other.ipAngleExcursion).abs() < 1e-6 &&
          (mcpAngleExcursion - other.mcpAngleExcursion).abs() < 1e-6 &&
          (averageIpAngularChange - other.averageIpAngularChange).abs() < 1e-6 &&
          (averageMcpAngularChange - other.averageMcpAngularChange).abs() < 1e-6 &&
          (cumulativeAbsoluteIpAngularChange - other.cumulativeAbsoluteIpAngularChange).abs() <
              1e-6 &&
          (cumulativeAbsoluteMcpAngularChange - other.cumulativeAbsoluteMcpAngularChange).abs() <
              1e-6 &&
          (averageForce - other.averageForce).abs() < 1e-6 &&
          (peakForce - other.peakForce).abs() < 1e-6 &&
          (cumulativeForceExposure - other.cumulativeForceExposure).abs() < 1e-6 &&
          forceThresholdExceedanceDuration == other.forceThresholdExceedanceDuration &&
          (forceThresholdExceedancePercentage - other.forceThresholdExceedancePercentage).abs() <
              1e-6 &&
          (forceSampleExceedancePercentage - other.forceSampleExceedancePercentage).abs() < 1e-6 &&
          (averageAngularVelocity - other.averageAngularVelocity).abs() < 1e-6 &&
          (peakAngularVelocity - other.peakAngularVelocity).abs() < 1e-6 &&
          (cumulativeAngularVelocityExposure - other.cumulativeAngularVelocityExposure).abs() <
              1e-6 &&
          angularVelocityThresholdExceedanceDuration ==
              other.angularVelocityThresholdExceedanceDuration &&
          (angularVelocityThresholdExceedancePercentage -
                      other.angularVelocityThresholdExceedancePercentage)
                  .abs() <
              1e-6 &&
          (angularVelocitySampleExceedancePercentage -
                      other.angularVelocitySampleExceedancePercentage)
                  .abs() <
              1e-6;

  @override
  int get hashCode => Object.hash(
        sessionId,
        startTime,
        endTime,
        duration,
        sampleCount,
        config,
        movementCount,
        movementsPerMinute,
        totalTimeMoving,
        averageMovementDuration,
        percentageTimeMoving,
        averageRestInterval,
        ipAngleExcursion,
        mcpAngleExcursion,
        cumulativeForceExposure,
        cumulativeAngularVelocityExposure,
      );

  @override
  String toString() =>
      'BiomechanicalAnalysis(sessionId: $sessionId, movements: $movementCount, '
      'timeMoving: ${totalTimeMoving.inMilliseconds}ms, '
      'forceExposure: ${cumulativeForceExposure.toStringAsFixed(2)} N·s, '
      'angVelExposure: ${cumulativeAngularVelocityExposure.toStringAsFixed(2)}°)';
}
