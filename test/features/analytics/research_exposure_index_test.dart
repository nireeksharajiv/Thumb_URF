import 'package:flutter_test/flutter_test.dart';
import 'package:thumb_biomech_monitor_glove/features/analytics/application/research_exposure_index_service.dart';
import 'package:thumb_biomech_monitor_glove/features/analytics/domain/models/biomechanical_analysis.dart';
import 'package:thumb_biomech_monitor_glove/features/analytics/domain/models/research_exposure_index.dart';

void main() {
  final t0 = DateTime.utc(2026, 9, 10, 12, 0, 0);

  BiomechanicalAnalysis buildAnalysis({
    Duration duration = const Duration(minutes: 1),
    int sampleCount = 60,
    int movementCount = 10,
    double movementsPerMinute = 10.0,
    double percentageTimeMoving = 20.0,
    double ipAngleExcursion = 30.0,
    double mcpAngleExcursion = 25.0,
    double cumIpDelta = 120.0,
    double cumMcpDelta = 60.0,
    double averageForce = 2.0,
    double peakForce = 4.0,
    double forceExceedancePct = 25.0,
    double averageAngVel = 30.0,
    double peakAngVel = 75.0,
    double angVelExceedancePct = 20.0,
  }) {
    return BiomechanicalAnalysis(
      sessionId: 'test-sess',
      startTime: t0,
      endTime: t0.add(duration),
      duration: duration,
      sampleCount: sampleCount,
      config: const BiomechanicalAnalysisConfig(),
      movementCount: movementCount,
      movementsPerMinute: movementsPerMinute,
      totalTimeMoving: Duration(
        milliseconds: (duration.inMilliseconds * (percentageTimeMoving / 100.0)).round(),
      ),
      averageMovementDuration: const Duration(seconds: 1),
      percentageTimeMoving: percentageTimeMoving,
      averageRestInterval: const Duration(seconds: 4),
      movementIntervals: const [],
      ipAngleExcursion: ipAngleExcursion,
      mcpAngleExcursion: mcpAngleExcursion,
      averageIpAngularChange: 2.0,
      averageMcpAngularChange: 1.0,
      cumulativeAbsoluteIpAngularChange: cumIpDelta,
      cumulativeAbsoluteMcpAngularChange: cumMcpDelta,
      averageForce: averageForce,
      peakForce: peakForce,
      cumulativeForceExposure: averageForce * (duration.inMilliseconds / 1000.0),
      forceThresholdExceedanceDuration: const Duration(seconds: 15),
      forceThresholdExceedancePercentage: forceExceedancePct,
      forceSampleExceedancePercentage: forceExceedancePct,
      averageAngularVelocity: averageAngVel,
      peakAngularVelocity: peakAngVel,
      cumulativeAngularVelocityExposure: averageAngVel * (duration.inMilliseconds / 1000.0),
      angularVelocityThresholdExceedanceDuration: const Duration(seconds: 12),
      angularVelocityThresholdExceedancePercentage: angVelExceedancePct,
      angularVelocitySampleExceedancePercentage: angVelExceedancePct,
    );
  }

  group('ResearchExposureIndex & Service Tests', () {
    test('1. Empty session produces 0.0 index and Low exposure category', () {
      final emptyAnalysis = BiomechanicalAnalysis.empty(sessionId: 'empty-sess');
      final result = ResearchExposureIndexService.calculate(emptyAnalysis);

      expect(result.overallIndex, 0.0);
      expect(result.category, ResearchExposureCategory.low);
      expect(result.movementComponent, 0.0);
      expect(result.jointMotionComponent, 0.0);
      expect(result.forceComponent, 0.0);
      expect(result.motionIntensityComponent, 0.0);
      expect(result.explanation, contains('Low Exposure'));
    });

    test('2. Zero exposure readings produce zeroed component scores', () {
      final zeroAnalysis = buildAnalysis(
        movementCount: 0,
        movementsPerMinute: 0.0,
        percentageTimeMoving: 0.0,
        ipAngleExcursion: 0.0,
        mcpAngleExcursion: 0.0,
        cumIpDelta: 0.0,
        cumMcpDelta: 0.0,
        averageForce: 0.0,
        peakForce: 0.0,
        forceExceedancePct: 0.0,
        averageAngVel: 0.0,
        peakAngVel: 0.0,
        angVelExceedancePct: 0.0,
      );

      final result = ResearchExposureIndexService.calculate(zeroAnalysis);

      expect(result.overallIndex, 0.0);
      expect(result.category, ResearchExposureCategory.low);
      expect(result.movementComponent, 0.0);
      expect(result.jointMotionComponent, 0.0);
      expect(result.forceComponent, 0.0);
      expect(result.motionIntensityComponent, 0.0);
    });

    test('3. Known normalized component calculations produce exact expected scores', () {
      // Configure references:
      // refMovementsPerMinute = 20.0, refIpExcursion = 50.0, refMcpExcursion = 50.0, refAngularChangeRate = 10.0
      // refAverageForce = 4.0, refPeakForce = 8.0
      // refAverageAngularVelocity = 50.0, refPeakAngularVelocity = 100.0
      final config = ResearchExposureIndexConfig(
        refMovementsPerMinute: 20.0,
        refIpExcursion: 50.0,
        refMcpExcursion: 50.0,
        refAngularChangeRate: 10.0,
        refAverageForce: 4.0,
        refPeakForce: 8.0,
        refAverageAngularVelocity: 50.0,
        refPeakAngularVelocity: 100.0,
      );

      // Dimension A: mpm = 10 (50%), moving% = 30 (30%) -> movScore = (0.5 * 50) + (0.5 * 30) = 40.0
      // Dimension B: ipEx = 25 (50%), mcpEx = 25 (50%), avgEx = 50%
      //   Duration = 60s, cumDelta = 180 + 120 = 300 deg. Rate = 300 / 60 = 5.0 deg/s. (5 / 10) * 100 = 50%
      //   jointScore = (0.5 * 50) + (0.5 * 50) = 50.0
      // Dimension C: avgForce = 2.0 (50%), peakForce = 4.0 (50%), exceedPct = 50%
      //   forceScore = (0.4 * 50) + (0.3 * 50) + (0.3 * 50) = 50.0
      // Dimension D: avgAngVel = 25.0 (50%), peakAngVel = 50.0 (50%), exceedPct = 50%
      //   motionScore = (0.4 * 50) + (0.3 * 50) + (0.3 * 50) = 50.0
      // Overall (equal weights): 0.25*40 + 0.25*50 + 0.25*50 + 0.25*50 = 10 + 12.5 + 12.5 + 12.5 = 47.5
      final analysis = buildAnalysis(
        duration: const Duration(seconds: 60),
        movementsPerMinute: 10.0,
        percentageTimeMoving: 30.0,
        ipAngleExcursion: 25.0,
        mcpAngleExcursion: 25.0,
        cumIpDelta: 180.0,
        cumMcpDelta: 120.0,
        averageForce: 2.0,
        peakForce: 4.0,
        forceExceedancePct: 50.0,
        averageAngVel: 25.0,
        peakAngVel: 50.0,
        angVelExceedancePct: 50.0,
      );

      final result = ResearchExposureIndexService.calculate(analysis, config: config);

      expect(result.movementComponent, closeTo(40.0, 1e-5));
      expect(result.jointMotionComponent, closeTo(50.0, 1e-5));
      expect(result.forceComponent, closeTo(50.0, 1e-5));
      expect(result.motionIntensityComponent, closeTo(50.0, 1e-5));
      expect(result.overallIndex, closeTo(47.5, 1e-5));
      expect(result.category, ResearchExposureCategory.moderate);
    });

    test('4. Component weighting reflects configured weight values', () {
      // Force-only weighting: movementWeight = 0, joint = 0, motion = 0, force = 1.0
      final forceOnlyConfig = ResearchExposureIndexConfig(
        movementWeight: 0.0,
        jointMotionWeight: 0.0,
        forceWeight: 1.0,
        motionIntensityWeight: 0.0,
        refAverageForce: 4.0,
        refPeakForce: 8.0,
      );

      final analysis = buildAnalysis(
        averageForce: 4.0, // 100%
        peakForce: 8.0, // 100%
        forceExceedancePct: 100.0, // 100%
        movementsPerMinute: 0.0, // 0%
        percentageTimeMoving: 0.0, // 0%
        ipAngleExcursion: 0.0, // 0%
      );

      final result = ResearchExposureIndexService.calculate(analysis, config: forceOnlyConfig);

      expect(result.forceComponent, 100.0);
      expect(result.movementComponent, 0.0);
      expect(result.overallIndex, 100.0);
      expect(result.category, ResearchExposureCategory.high);
    });

    test('5. Automatic weight normalization ensures weights sum to 1.0 even if raw inputs do not', () {
      // Weights sum to 400 (100 each) -> effective weights should each be 0.25 (25%)
      final config = ResearchExposureIndexConfig(
        movementWeight: 100.0,
        jointMotionWeight: 100.0,
        forceWeight: 100.0,
        motionIntensityWeight: 100.0,
      );

      expect(config.effectiveMovementWeight, 0.25);
      expect(config.effectiveJointMotionWeight, 0.25);
      expect(config.effectiveForceWeight, 0.25);
      expect(config.effectiveMotionIntensityWeight, 0.25);
      expect(
        config.effectiveMovementWeight +
            config.effectiveJointMotionWeight +
            config.effectiveForceWeight +
            config.effectiveMotionIntensityWeight,
        closeTo(1.0, 1e-6),
      );
    });

    test('6. Index bounds [0, 100] are strictly enforced under extreme inputs', () {
      final extremeAnalysis = buildAnalysis(
        movementsPerMinute: 500.0,
        percentageTimeMoving: 200.0,
        ipAngleExcursion: 180.0,
        mcpAngleExcursion: 180.0,
        cumIpDelta: 100000.0,
        cumMcpDelta: 100000.0,
        averageForce: 100.0,
        peakForce: 250.0,
        forceExceedancePct: 150.0,
        averageAngVel: 5000.0,
        peakAngVel: 10000.0,
        angVelExceedancePct: 200.0,
      );

      final result = ResearchExposureIndexService.calculate(extremeAnalysis);

      expect(result.movementComponent, 100.0);
      expect(result.jointMotionComponent, 100.0);
      expect(result.forceComponent, 100.0);
      expect(result.motionIntensityComponent, 100.0);
      expect(result.overallIndex, 100.0);
      expect(result.category, ResearchExposureCategory.high);
    });

    test('7. Category boundaries correctly distinguish Low, Moderate, and High', () {
      final config = ResearchExposureIndexConfig(
        moderateThreshold: 33.33,
        highThreshold: 66.66,
      );

      // Helper to synthesize an index
      ResearchExposureIndex indexWithScore(double score) {
        return ResearchExposureIndexService.calculate(
          buildAnalysis(
            movementsPerMinute: (score / 100.0) * 30.0,
            percentageTimeMoving: score,
            ipAngleExcursion: (score / 100.0) * 60.0,
            mcpAngleExcursion: (score / 100.0) * 50.0,
            averageForce: (score / 100.0) * 4.0,
            peakForce: (score / 100.0) * 8.0,
            forceExceedancePct: score,
            averageAngVel: (score / 100.0) * 60.0,
            peakAngVel: (score / 100.0) * 150.0,
            angVelExceedancePct: score,
            cumIpDelta: 0,
            cumMcpDelta: 0,
          ),
          config: config,
        );
      }

      final low = indexWithScore(25.0);
      expect(low.category, ResearchExposureCategory.low);
      expect(low.category.displayName, 'Low Exposure');

      final moderate = indexWithScore(50.0);
      expect(moderate.category, ResearchExposureCategory.moderate);
      expect(moderate.category.displayName, 'Moderate Exposure');

      final high = indexWithScore(85.0);
      expect(high.category, ResearchExposureCategory.high);
      expect(high.category.displayName, 'High Exposure');
    });

    test('8. Missing/empty readings in session metadata handled safely', () {
      final sessionEmptyReadings = BiomechanicalAnalysis.empty(
        sessionId: 'empty-readings-sess',
        duration: const Duration(minutes: 5),
      );

      final result = ResearchExposureIndexService.calculate(sessionEmptyReadings);

      expect(result.overallIndex, 0.0);
      expect(result.category, ResearchExposureCategory.low);
      expect(result.movementComponent, 0.0);
    });

    test('9. Zero-duration sessions avoid division by zero', () {
      final zeroDur = buildAnalysis(duration: Duration.zero);
      final result = ResearchExposureIndexService.calculate(zeroDur);

      expect(result.overallIndex, isNot(isNaN));
      expect(result.overallIndex, inInclusiveRange(0.0, 100.0));
    });

    test('10. Extreme sensor inputs clamp cleanly to 100.0 without overflow', () {
      final huge = buildAnalysis(
        movementsPerMinute: 1e9,
        percentageTimeMoving: 1e9,
        ipAngleExcursion: 1e9,
        mcpAngleExcursion: 1e9,
        cumIpDelta: 1e9,
        cumMcpDelta: 1e9,
        averageForce: 1e9,
        peakForce: 1e9,
        forceExceedancePct: 1e9,
        averageAngVel: 1e9,
        peakAngVel: 1e9,
        angVelExceedancePct: 1e9,
      );

      final result = ResearchExposureIndexService.calculate(huge);

      expect(result.overallIndex, 100.0);
      expect(result.movementComponent, 100.0);
      expect(result.jointMotionComponent, 100.0);
      expect(result.forceComponent, 100.0);
      expect(result.motionIntensityComponent, 100.0);
    });

    test('11. Configuration validation rejects negative weights or invalid thresholds', () {
      expect(
        () => ResearchExposureIndexConfig(movementWeight: -1.0),
        throwsArgumentError,
      );
      expect(
        () => ResearchExposureIndexConfig(
          movementWeight: 0,
          jointMotionWeight: 0,
          forceWeight: 0,
          motionIntensityWeight: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => ResearchExposureIndexConfig(refMovementsPerMinute: 0),
        throwsArgumentError,
      );
      expect(
        () => ResearchExposureIndexConfig(moderateThreshold: 80.0, highThreshold: 60.0),
        throwsArgumentError,
      );
    });

    test('12. Deterministic repeated calculation yields identical outputs', () {
      final analysis = buildAnalysis();
      final r1 = ResearchExposureIndexService.calculate(analysis);
      final r2 = ResearchExposureIndexService.calculate(analysis);

      expect(r1.overallIndex, equals(r2.overallIndex));
      expect(r1.movementComponent, equals(r2.movementComponent));
      expect(r1.jointMotionComponent, equals(r2.jointMotionComponent));
      expect(r1.forceComponent, equals(r2.forceComponent));
      expect(r1.motionIntensityComponent, equals(r2.motionIntensityComponent));
      expect(r1.category, equals(r2.category));
    });

    test('13. Serialization and deserialization preserves all fields faithfully', () {
      final analysis = buildAnalysis();
      final index = ResearchExposureIndexService.calculate(
        analysis,
        timestamp: t0,
      );

      final json = index.toJson();
      final restored = ResearchExposureIndex.fromJson(json);

      expect(restored.overallIndex, index.overallIndex);
      expect(restored.category, index.category);
      expect(restored.movementComponent, index.movementComponent);
      expect(restored.jointMotionComponent, index.jointMotionComponent);
      expect(restored.forceComponent, index.forceComponent);
      expect(restored.motionIntensityComponent, index.motionIntensityComponent);
      expect(restored.explanation, index.explanation);
      expect(restored.calculatedAt, index.calculatedAt);
      expect(restored, equals(index));
      expect(index.toString(), contains('ResearchExposureIndex'));
    });
  });
}
