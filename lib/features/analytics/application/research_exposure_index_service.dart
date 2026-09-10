import 'dart:math' as math;

import '../domain/models/biomechanical_analysis.dart';
import '../domain/models/research_exposure_index.dart';

/// Pure domain/application service that calculates a transparent, configurable
/// Research-Oriented Loading / Exposure Index from [BiomechanicalAnalysis].
///
/// **Non-Diagnostic Notice**: This service evaluates engineering research exposure
/// telemetry for prototype comparison and calibration. It does NOT diagnose
/// clinical stress, RSI, arthritis, injury risk, or medical pathology.
class ResearchExposureIndexService {
  const ResearchExposureIndexService();

  /// Computes a [ResearchExposureIndex] from the supplied [analysis].
  ///
  /// Uses [config] for reference normalization baselines, component weights,
  /// and exposure category boundaries. Defaults to standard research prototype configuration.
  static ResearchExposureIndex calculate(
    BiomechanicalAnalysis analysis, {
    ResearchExposureIndexConfig? config,
    DateTime? timestamp,
  }) {
    final effectiveConfig = config ?? ResearchExposureIndexConfig();

    // 1. Dimension A: Movement Exposure Score (0-100)
    final sMovRate = math.min(
      100.0,
      (analysis.movementsPerMinute / effectiveConfig.refMovementsPerMinute) * 100.0,
    );
    final sMovTime = math.min(100.0, math.max(0.0, analysis.percentageTimeMoving));
    final movementScore = math.min(100.0, math.max(0.0, (0.5 * sMovRate) + (0.5 * sMovTime)));

    // 2. Dimension B: Joint Motion & Excursion Score (0-100)
    final sIpExcursion = math.min(
      100.0,
      (analysis.ipAngleExcursion / effectiveConfig.refIpExcursion) * 100.0,
    );
    final sMcpExcursion = math.min(
      100.0,
      (analysis.mcpAngleExcursion / effectiveConfig.refMcpExcursion) * 100.0,
    );
    final avgExcursion = (sIpExcursion + sMcpExcursion) / 2.0;

    final durationSec = analysis.duration.inMicroseconds / 1000000.0;
    final totalDelta = analysis.cumulativeAbsoluteIpAngularChange +
        analysis.cumulativeAbsoluteMcpAngularChange;
    final angularChangeRate = durationSec > 0 ? (totalDelta / durationSec) : 0.0;
    final sAngularChange = math.min(
      100.0,
      (angularChangeRate / effectiveConfig.refAngularChangeRate) * 100.0,
    );
    final jointMotionScore =
        math.min(100.0, math.max(0.0, (0.5 * avgExcursion) + (0.5 * sAngularChange)));

    // 3. Dimension C: Force Exposure Score (0-100)
    final sAvgForce = math.min(
      100.0,
      (analysis.averageForce / effectiveConfig.refAverageForce) * 100.0,
    );
    final sPeakForce = math.min(
      100.0,
      (analysis.peakForce / effectiveConfig.refPeakForce) * 100.0,
    );
    final sForceExceedance =
        math.min(100.0, math.max(0.0, analysis.forceThresholdExceedancePercentage));
    final forceScore = math.min(
      100.0,
      math.max(
        0.0,
        (0.4 * sAvgForce) + (0.3 * sPeakForce) + (0.3 * sForceExceedance),
      ),
    );

    // 4. Dimension D: Motion Intensity & Velocity Score (0-100)
    final sAvgAngVel = math.min(
      100.0,
      (analysis.averageAngularVelocity / effectiveConfig.refAverageAngularVelocity) * 100.0,
    );
    final sPeakAngVel = math.min(
      100.0,
      (analysis.peakAngularVelocity / effectiveConfig.refPeakAngularVelocity) * 100.0,
    );
    final sMotionExceedance =
        math.min(100.0, math.max(0.0, analysis.angularVelocityThresholdExceedancePercentage));
    final motionIntensityScore = math.min(
      100.0,
      math.max(
        0.0,
        (0.4 * sAvgAngVel) + (0.3 * sPeakAngVel) + (0.3 * sMotionExceedance),
      ),
    );

    // 5. Normalized Weighted Composite Index (0-100)
    final wMov = effectiveConfig.effectiveMovementWeight;
    final wJoint = effectiveConfig.effectiveJointMotionWeight;
    final wForce = effectiveConfig.effectiveForceWeight;
    final wMotion = effectiveConfig.effectiveMotionIntensityWeight;

    final compositeRaw = (wMov * movementScore) +
        (wJoint * jointMotionScore) +
        (wForce * forceScore) +
        (wMotion * motionIntensityScore);

    final overallIndex = math.min(100.0, math.max(0.0, compositeRaw));

    // 6. Research Prototype Exposure Category
    final ResearchExposureCategory category;
    if (overallIndex <= effectiveConfig.moderateThreshold) {
      category = ResearchExposureCategory.low;
    } else if (overallIndex <= effectiveConfig.highThreshold) {
      category = ResearchExposureCategory.moderate;
    } else {
      category = ResearchExposureCategory.high;
    }

    // 7. Human-readable explanation breakdown
    final explanation =
        'Research Exposure Index: ${overallIndex.toStringAsFixed(1)}/100 (${category.displayName}) | '
        'Movement: ${movementScore.toStringAsFixed(1)} (wt: ${(wMov * 100).toStringAsFixed(0)}%), '
        'Joint Motion: ${jointMotionScore.toStringAsFixed(1)} (wt: ${(wJoint * 100).toStringAsFixed(0)}%), '
        'Force: ${forceScore.toStringAsFixed(1)} (wt: ${(wForce * 100).toStringAsFixed(0)}%), '
        'Motion Intensity: ${motionIntensityScore.toStringAsFixed(1)} (wt: ${(wMotion * 100).toStringAsFixed(0)}%)';

    return ResearchExposureIndex(
      overallIndex: overallIndex,
      category: category,
      movementComponent: movementScore,
      jointMotionComponent: jointMotionScore,
      forceComponent: forceScore,
      motionIntensityComponent: motionIntensityScore,
      explanation: explanation,
      config: effectiveConfig,
      calculatedAt: timestamp ?? DateTime.now().toUtc(),
    );
  }
}
