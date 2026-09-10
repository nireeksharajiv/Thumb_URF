import 'package:flutter/foundation.dart';

/// Research prototype exposure categories indicating overall biomechanical loading.
///
/// **Non-Diagnostic Notice**: These categories represent engineering research
/// exposure bands for demonstration and calibration. They do NOT represent
/// clinical risk, disease severity, or medical assessment.
enum ResearchExposureCategory {
  low('Low Exposure'),
  moderate('Moderate Exposure'),
  high('High Exposure');

  const ResearchExposureCategory(this.displayName);

  final String displayName;
}

/// Configurable normalization baselines, weights, and thresholds for the
/// research-oriented loading/exposure index.
///
/// **Notice**: All default parameters are demonstration research prototype values
/// and are NOT clinically validated thresholds.
@immutable
class ResearchExposureIndexConfig {
  ResearchExposureIndexConfig({
    // Component weights
    this.movementWeight = 0.25,
    this.jointMotionWeight = 0.25,
    this.forceWeight = 0.25,
    this.motionIntensityWeight = 0.25,
    // Normalization reference baselines
    this.refMovementsPerMinute = 30.0,
    this.refIpExcursion = 60.0,
    this.refMcpExcursion = 50.0,
    this.refAngularChangeRate = 60.0,
    this.refAverageForce = 4.0,
    this.refPeakForce = 8.0,
    this.refAverageAngularVelocity = 60.0,
    this.refPeakAngularVelocity = 150.0,
    // Category boundary thresholds
    this.moderateThreshold = 33.33,
    this.highThreshold = 66.66,
    this.version = 'v1.0-research-prototype',
  }) {
    if (movementWeight < 0 ||
        jointMotionWeight < 0 ||
        forceWeight < 0 ||
        motionIntensityWeight < 0) {
      throw ArgumentError('Component weights must be non-negative.');
    }
    final totalWeight =
        movementWeight + jointMotionWeight + forceWeight + motionIntensityWeight;
    if (totalWeight <= 0) {
      throw ArgumentError('Sum of component weights must be strictly positive.');
    }
    if (refMovementsPerMinute <= 0 ||
        refIpExcursion <= 0 ||
        refMcpExcursion <= 0 ||
        refAngularChangeRate <= 0 ||
        refAverageForce <= 0 ||
        refPeakForce <= 0 ||
        refAverageAngularVelocity <= 0 ||
        refPeakAngularVelocity <= 0) {
      throw ArgumentError('Reference normalization baselines must be strictly positive.');
    }
    if (moderateThreshold <= 0 ||
        moderateThreshold >= highThreshold ||
        highThreshold >= 100.0) {
      throw ArgumentError(
          'Category thresholds must satisfy: 0 < moderateThreshold < highThreshold < 100.');
    }
  }

  final double movementWeight;
  final double jointMotionWeight;
  final double forceWeight;
  final double motionIntensityWeight;

  final double refMovementsPerMinute;
  final double refIpExcursion;
  final double refMcpExcursion;
  final double refAngularChangeRate;
  final double refAverageForce;
  final double refPeakForce;
  final double refAverageAngularVelocity;
  final double refPeakAngularVelocity;

  final double moderateThreshold;
  final double highThreshold;
  final String version;

  /// Effective normalized weight for movement exposure (sums to 1.0 with others).
  double get effectiveMovementWeight =>
      movementWeight / totalRawWeight;

  /// Effective normalized weight for joint motion exposure.
  double get effectiveJointMotionWeight =>
      jointMotionWeight / totalRawWeight;

  /// Effective normalized weight for force exposure.
  double get effectiveForceWeight =>
      forceWeight / totalRawWeight;

  /// Effective normalized weight for motion intensity exposure.
  double get effectiveMotionIntensityWeight =>
      motionIntensityWeight / totalRawWeight;

  double get totalRawWeight =>
      movementWeight + jointMotionWeight + forceWeight + motionIntensityWeight;

  Map<String, Object> toJson() => {
        'movementWeight': movementWeight,
        'jointMotionWeight': jointMotionWeight,
        'forceWeight': forceWeight,
        'motionIntensityWeight': motionIntensityWeight,
        'refMovementsPerMinute': refMovementsPerMinute,
        'refIpExcursion': refIpExcursion,
        'refMcpExcursion': refMcpExcursion,
        'refAngularChangeRate': refAngularChangeRate,
        'refAverageForce': refAverageForce,
        'refPeakForce': refPeakForce,
        'refAverageAngularVelocity': refAverageAngularVelocity,
        'refPeakAngularVelocity': refPeakAngularVelocity,
        'moderateThreshold': moderateThreshold,
        'highThreshold': highThreshold,
        'version': version,
      };

  factory ResearchExposureIndexConfig.fromJson(Map<String, Object?> json) {
    return ResearchExposureIndexConfig(
      movementWeight: (json['movementWeight'] as num?)?.toDouble() ?? 0.25,
      jointMotionWeight: (json['jointMotionWeight'] as num?)?.toDouble() ?? 0.25,
      forceWeight: (json['forceWeight'] as num?)?.toDouble() ?? 0.25,
      motionIntensityWeight:
          (json['motionIntensityWeight'] as num?)?.toDouble() ?? 0.25,
      refMovementsPerMinute:
          (json['refMovementsPerMinute'] as num?)?.toDouble() ?? 30.0,
      refIpExcursion: (json['refIpExcursion'] as num?)?.toDouble() ?? 60.0,
      refMcpExcursion: (json['refMcpExcursion'] as num?)?.toDouble() ?? 50.0,
      refAngularChangeRate:
          (json['refAngularChangeRate'] as num?)?.toDouble() ?? 60.0,
      refAverageForce: (json['refAverageForce'] as num?)?.toDouble() ?? 4.0,
      refPeakForce: (json['refPeakForce'] as num?)?.toDouble() ?? 8.0,
      refAverageAngularVelocity:
          (json['refAverageAngularVelocity'] as num?)?.toDouble() ?? 60.0,
      refPeakAngularVelocity:
          (json['refPeakAngularVelocity'] as num?)?.toDouble() ?? 150.0,
      moderateThreshold: (json['moderateThreshold'] as num?)?.toDouble() ?? 33.33,
      highThreshold: (json['highThreshold'] as num?)?.toDouble() ?? 66.66,
      version: json['version'] as String? ?? 'v1.0-research-prototype',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResearchExposureIndexConfig &&
          runtimeType == other.runtimeType &&
          movementWeight == other.movementWeight &&
          jointMotionWeight == other.jointMotionWeight &&
          forceWeight == other.forceWeight &&
          motionIntensityWeight == other.motionIntensityWeight &&
          refMovementsPerMinute == other.refMovementsPerMinute &&
          refIpExcursion == other.refIpExcursion &&
          refMcpExcursion == other.refMcpExcursion &&
          refAngularChangeRate == other.refAngularChangeRate &&
          refAverageForce == other.refAverageForce &&
          refPeakForce == other.refPeakForce &&
          refAverageAngularVelocity == other.refAverageAngularVelocity &&
          refPeakAngularVelocity == other.refPeakAngularVelocity &&
          moderateThreshold == other.moderateThreshold &&
          highThreshold == other.highThreshold &&
          version == other.version;

  @override
  int get hashCode => Object.hash(
        movementWeight,
        jointMotionWeight,
        forceWeight,
        motionIntensityWeight,
        refMovementsPerMinute,
        refIpExcursion,
        refMcpExcursion,
        refAngularChangeRate,
        refAverageForce,
        refPeakForce,
        refAverageAngularVelocity,
        refPeakAngularVelocity,
        moderateThreshold,
        highThreshold,
        version,
      );
}

/// Immutable result model encapsulating a calculated Research-Oriented Loading / Exposure Index.
///
/// **Non-Diagnostic Notice**: This index is an engineering research metric measuring
/// cumulative biomechanical loading and exposure. It does NOT predict clinical risk,
/// RSI risk, arthritis risk, clinical stress, or medical pathology.
@immutable
class ResearchExposureIndex {
  const ResearchExposureIndex({
    required this.overallIndex,
    required this.category,
    required this.movementComponent,
    required this.jointMotionComponent,
    required this.forceComponent,
    required this.motionIntensityComponent,
    required this.explanation,
    required this.config,
    required this.calculatedAt,
  });

  /// Factory constructor for empty/zero-exposure state.
  factory ResearchExposureIndex.empty({
    ResearchExposureIndexConfig? config,
    DateTime? calculatedAt,
  }) {
    final effectiveConfig = config ?? ResearchExposureIndexConfig();
    final timestamp = calculatedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return ResearchExposureIndex(
      overallIndex: 0.0,
      category: ResearchExposureCategory.low,
      movementComponent: 0.0,
      jointMotionComponent: 0.0,
      forceComponent: 0.0,
      motionIntensityComponent: 0.0,
      explanation:
          'Research Exposure Index: 0.0/100 (Low Exposure) — No sensor exposure recorded.',
      config: effectiveConfig,
      calculatedAt: timestamp,
    );
  }

  /// Composite loading index strictly bounded in range [0, 100].
  final double overallIndex;

  /// Research prototype exposure category (Low, Moderate, High).
  final ResearchExposureCategory category;

  /// Normalized movement repetition exposure score in range [0, 100].
  final double movementComponent;

  /// Normalized joint kinematics & angular change score in range [0, 100].
  final double jointMotionComponent;

  /// Normalized contact force exposure score in range [0, 100].
  final double forceComponent;

  /// Normalized motion intensity & angular velocity score in range [0, 100].
  final double motionIntensityComponent;

  /// Human-readable explanation breakdown of contributing dimensions.
  final String explanation;

  /// Configuration containing reference baselines and weights used.
  final ResearchExposureIndexConfig config;

  /// Timestamp when index was computed.
  final DateTime calculatedAt;

  Map<String, Object> toJson() => {
        'overallIndex': overallIndex,
        'category': category.name,
        'movementComponent': movementComponent,
        'jointMotionComponent': jointMotionComponent,
        'forceComponent': forceComponent,
        'motionIntensityComponent': motionIntensityComponent,
        'explanation': explanation,
        'config': config.toJson(),
        'calculatedAt': calculatedAt.toIso8601String(),
      };

  factory ResearchExposureIndex.fromJson(Map<String, Object?> json) {
    final catName = json['category'] as String?;
    final category = ResearchExposureCategory.values.firstWhere(
      (c) => c.name == catName,
      orElse: () => ResearchExposureCategory.low,
    );

    final configRaw = json['config'];
    final config = configRaw is Map<String, Object?>
        ? ResearchExposureIndexConfig.fromJson(configRaw)
        : ResearchExposureIndexConfig();

    return ResearchExposureIndex(
      overallIndex: (json['overallIndex'] as num?)?.toDouble() ?? 0.0,
      category: category,
      movementComponent: (json['movementComponent'] as num?)?.toDouble() ?? 0.0,
      jointMotionComponent:
          (json['jointMotionComponent'] as num?)?.toDouble() ?? 0.0,
      forceComponent: (json['forceComponent'] as num?)?.toDouble() ?? 0.0,
      motionIntensityComponent:
          (json['motionIntensityComponent'] as num?)?.toDouble() ?? 0.0,
      explanation: json['explanation'] as String? ?? '',
      config: config,
      calculatedAt: json['calculatedAt'] != null
          ? DateTime.parse(json['calculatedAt'] as String).toUtc()
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResearchExposureIndex &&
          runtimeType == other.runtimeType &&
          (overallIndex - other.overallIndex).abs() < 1e-6 &&
          category == other.category &&
          (movementComponent - other.movementComponent).abs() < 1e-6 &&
          (jointMotionComponent - other.jointMotionComponent).abs() < 1e-6 &&
          (forceComponent - other.forceComponent).abs() < 1e-6 &&
          (motionIntensityComponent - other.motionIntensityComponent).abs() <
              1e-6 &&
          explanation == other.explanation &&
          config == other.config &&
          calculatedAt == other.calculatedAt;

  @override
  int get hashCode => Object.hash(
        overallIndex,
        category,
        movementComponent,
        jointMotionComponent,
        forceComponent,
        motionIntensityComponent,
        explanation,
        config,
        calculatedAt,
      );

  @override
  String toString() =>
      'ResearchExposureIndex(index: ${overallIndex.toStringAsFixed(1)}/100, '
      'category: ${category.displayName}, '
      'mov: ${movementComponent.toStringAsFixed(1)}, '
      'joint: ${jointMotionComponent.toStringAsFixed(1)}, '
      'force: ${forceComponent.toStringAsFixed(1)}, '
      'motion: ${motionIntensityComponent.toStringAsFixed(1)})';
}
