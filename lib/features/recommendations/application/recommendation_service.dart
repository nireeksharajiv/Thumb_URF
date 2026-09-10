import '../../analytics/domain/models/biomechanical_analysis.dart';
import '../../analytics/domain/models/research_exposure_index.dart';
import '../domain/models/research_recommendation.dart';

/// Pure application service responsible for generating deterministic, research-oriented
/// ergonomic recommendations based on [BiomechanicalAnalysis] telemetry.
///
/// **Non-Diagnostic Notice**:
/// Recommendations are engineering observations and ergonomic suggestions based on
/// measured prototype telemetry. They do NOT provide clinical diagnoses, medical advice,
/// or injury risk assessments.
class RecommendationService {
  const RecommendationService();

  /// Generates a prioritized, deduplicated list of research recommendations
  /// for the provided [analysis].
  List<ResearchRecommendation> generateRecommendations(
    BiomechanicalAnalysis analysis, {
    ResearchExposureIndex? exposureIndex,
    RecommendationConfig? config,
    DateTime? timestamp,
  }) {
    // 1. Safe handling for empty or zero-duration sessions
    if (analysis.sampleCount == 0 || analysis.duration <= Duration.zero) {
      return const [];
    }

    final cfg = config ?? RecommendationConfig();
    final now = timestamp ?? DateTime.utc(2026, 9, 10);
    final recommendations = <ResearchRecommendation>[];

    // Track triggered dimensional categories (excluding general)
    final triggeredCategories = <RecommendationCategory>{};

    // -------------------------------------------------------------
    // Rule 1: Movement Frequency (Repetition rate)
    // -------------------------------------------------------------
    if (analysis.movementsPerMinute >= cfg.refMovementsPerMinute) {
      final isHigh = analysis.movementsPerMinute >= cfg.refMovementsPerMinute * 1.3;
      recommendations.add(
        ResearchRecommendation(
          id: 'rec_movement_frequency',
          title: isHigh ? 'High Movement Frequency Observed' : 'Elevated Movement Frequency Observed',
          description: isHigh
              ? 'Movement frequency substantially exceeds the research reference baseline. Consider reviewing repetitive-use patterns and scheduling structured rest intervals.'
              : 'Movement frequency is elevated relative to the research reference baseline. Consider reviewing repetitive-use patterns and incorporating periodic pauses.',
          category: RecommendationCategory.movement,
          priority: isHigh ? RecommendationPriority.elevated : RecommendationPriority.moderate,
          evidence:
              'Measured ${analysis.movementsPerMinute.toStringAsFixed(1)} /min vs reference baseline ${cfg.refMovementsPerMinute.toStringAsFixed(0)} /min',
          metricValue: analysis.movementsPerMinute,
          referenceValue: cfg.refMovementsPerMinute,
          unit: '/min',
          generatedAt: now,
        ),
      );
      triggeredCategories.add(RecommendationCategory.movement);
    }

    // -------------------------------------------------------------
    // Rule 2: Percentage of Time Moving (Active movement duty cycle)
    // -------------------------------------------------------------
    if (analysis.percentageTimeMoving >= cfg.refPercentageTimeMoving) {
      final isHigh = analysis.percentageTimeMoving >= cfg.refPercentageTimeMoving * 1.5;
      recommendations.add(
        ResearchRecommendation(
          id: 'rec_active_time',
          title: 'High Active Movement Proportion',
          description:
              'Active movement occupies a high proportion of session duration. Consider reviewing the balance between active movement and rest intervals during prolonged sessions.',
          category: RecommendationCategory.movement,
          priority: isHigh ? RecommendationPriority.elevated : RecommendationPriority.moderate,
          evidence:
              'Active movement accounted for ${analysis.percentageTimeMoving.toStringAsFixed(1)}% of total session time (reference: ${cfg.refPercentageTimeMoving.toStringAsFixed(0)}%)',
          metricValue: analysis.percentageTimeMoving,
          referenceValue: cfg.refPercentageTimeMoving,
          unit: '%',
          generatedAt: now,
        ),
      );
      triggeredCategories.add(RecommendationCategory.movement);
    }

    // -------------------------------------------------------------
    // Rule 3: Contact Force Exposure (Threshold exceedance)
    // -------------------------------------------------------------
    if (analysis.forceThresholdExceedancePercentage >= cfg.refForceExceedancePercentage) {
      final isHigh = analysis.forceThresholdExceedancePercentage >= cfg.refForceExceedancePercentage * 1.5;
      recommendations.add(
        ResearchRecommendation(
          id: 'rec_force_exposure',
          title: 'Sustained Thumb Contact Force Observed',
          description:
              'Thumb contact force remained above research threshold for an extended portion of the session. Recommend reviewing sustained thumb contact pressure during repetitive interactions.',
          category: RecommendationCategory.force,
          priority: isHigh ? RecommendationPriority.elevated : RecommendationPriority.moderate,
          evidence:
              'Contact force exceeded research threshold (≥ ${analysis.config.forceThreshold.toStringAsFixed(1)} N) for ${analysis.forceThresholdExceedancePercentage.toStringAsFixed(1)}% of session time',
          metricValue: analysis.forceThresholdExceedancePercentage,
          referenceValue: cfg.refForceExceedancePercentage,
          unit: '%',
          generatedAt: now,
        ),
      );
      triggeredCategories.add(RecommendationCategory.force);
    }

    // -------------------------------------------------------------
    // Rule 4: Peak Force (High interaction magnitude)
    // -------------------------------------------------------------
    if (analysis.peakForce >= cfg.refPeakForce) {
      recommendations.add(
        ResearchRecommendation(
          id: 'rec_peak_force',
          title: 'Elevated Peak Contact Force Observed',
          description:
              'Peak thumb contact force reached elevated levels relative to reference baseline. Consider reviewing high-force pinch or pressing maneuvers observed during the session.',
          category: RecommendationCategory.force,
          priority: RecommendationPriority.elevated,
          evidence:
              'Peak force reached ${analysis.peakForce.toStringAsFixed(1)} N (reference baseline: ${cfg.refPeakForce.toStringAsFixed(1)} N)',
          metricValue: analysis.peakForce,
          referenceValue: cfg.refPeakForce,
          unit: 'N',
          generatedAt: now,
        ),
      );
      triggeredCategories.add(RecommendationCategory.force);
    }

    // -------------------------------------------------------------
    // Rule 5: Angular Velocity (Rapid motion dynamics)
    // -------------------------------------------------------------
    final hasHighVelocityExceedance =
        analysis.angularVelocityThresholdExceedancePercentage >= cfg.refAngularVelocityExceedancePercentage;
    final hasHighPeakVelocity = analysis.peakAngularVelocity >= cfg.refPeakAngularVelocity;

    if (hasHighVelocityExceedance || hasHighPeakVelocity) {
      final bothExceeded = hasHighVelocityExceedance && hasHighPeakVelocity;
      recommendations.add(
        ResearchRecommendation(
          id: 'rec_motion_velocity',
          title: 'Rapid Thumb Motion Dynamics Observed',
          description:
              'Rapid thumb motion was detected with elevated angular velocities. Recommend reviewing rapid thumb directional transitions and high-speed motion segments.',
          category: RecommendationCategory.motionIntensity,
          priority: bothExceeded ? RecommendationPriority.elevated : RecommendationPriority.moderate,
          evidence:
              'Angular velocity exceeded threshold for ${analysis.angularVelocityThresholdExceedancePercentage.toStringAsFixed(1)}% of session (peak: ${analysis.peakAngularVelocity.toStringAsFixed(0)} °/s vs reference: ${cfg.refPeakAngularVelocity.toStringAsFixed(0)} °/s)',
          metricValue: analysis.peakAngularVelocity,
          referenceValue: cfg.refPeakAngularVelocity,
          unit: '°/s',
          generatedAt: now,
        ),
      );
      triggeredCategories.add(RecommendationCategory.motionIntensity);
    }

    // -------------------------------------------------------------
    // Rule 6: Joint Excursion (Range of motion)
    // -------------------------------------------------------------
    if (analysis.ipAngleExcursion >= cfg.refIpExcursion || analysis.mcpAngleExcursion >= cfg.refMcpExcursion) {
      recommendations.add(
        ResearchRecommendation(
          id: 'rec_joint_excursion',
          title: 'Large Joint Excursion Observed',
          description:
              'Observed joint excursion ranges are elevated relative to reference baselines. Consider reviewing the active range of thumb motion during task performance.',
          category: RecommendationCategory.jointMotion,
          priority: RecommendationPriority.moderate,
          evidence:
              'Excursion reached IP: ${analysis.ipAngleExcursion.toStringAsFixed(1)}° (ref: ${cfg.refIpExcursion.toStringAsFixed(0)}°), MCP: ${analysis.mcpAngleExcursion.toStringAsFixed(1)}° (ref: ${cfg.refMcpExcursion.toStringAsFixed(0)}°)',
          metricValue: analysis.ipAngleExcursion > analysis.mcpAngleExcursion
              ? analysis.ipAngleExcursion
              : analysis.mcpAngleExcursion,
          referenceValue: analysis.ipAngleExcursion > analysis.mcpAngleExcursion
              ? cfg.refIpExcursion
              : cfg.refMcpExcursion,
          unit: '°',
          generatedAt: now,
        ),
      );
      triggeredCategories.add(RecommendationCategory.jointMotion);
    }

    // -------------------------------------------------------------
    // Rule 7: Multiple Elevated Dimensions (Combined loading pattern)
    // -------------------------------------------------------------
    if (triggeredCategories.length >= 2) {
      final categoryNames = triggeredCategories.map((c) => c.displayName).join(', ');
      recommendations.add(
        ResearchRecommendation(
          id: 'rec_combined_exposure',
          title: 'Combined Multi-Factor Biomechanical Loading',
          description:
              'Multiple biomechanical exposure dimensions are simultaneously elevated in this session. Consider reviewing overall session pacing, task structure, and ergonomic workflow distribution.',
          category: RecommendationCategory.general,
          priority: RecommendationPriority.elevated,
          evidence: 'Multiple exposure dimensions ($categoryNames) exhibited elevated loading patterns',
          generatedAt: now,
        ),
      );
    }

    // -------------------------------------------------------------
    // Rule 8: Baseline / Low Exposure Informational Result
    // -------------------------------------------------------------
    if (recommendations.isEmpty) {
      recommendations.add(
        ResearchRecommendation(
          id: 'rec_baseline_informational',
          title: 'Baseline Biomechanical Loading Observed',
          description:
              'All observed movement, joint motion, contact force, and velocity parameters remained within configured research prototype reference boundaries throughout the session.',
          category: RecommendationCategory.general,
          priority: RecommendationPriority.informational,
          evidence:
              'All telemetry metrics remained within baseline reference thresholds across ${analysis.sampleCount} recorded samples',
          generatedAt: now,
        ),
      );
    }

    // -------------------------------------------------------------
    // Sorting & Deduplication:
    // Priority order: elevated (rank 2) -> moderate (rank 1) -> informational (rank 0).
    // Tie-breaker: rule ID for deterministic stability.
    // -------------------------------------------------------------
    recommendations.sort((a, b) {
      final rankComp = b.priority.rank.compareTo(a.priority.rank);
      if (rankComp != 0) return rankComp;
      return a.id.compareTo(b.id);
    });

    return List.unmodifiable(recommendations);
  }
}
