import 'package:flutter_test/flutter_test.dart';
import 'package:thumb_biomech_monitor_glove/features/analytics/domain/models/biomechanical_analysis.dart';
import 'package:thumb_biomech_monitor_glove/features/recommendations/application/recommendation_service.dart';
import 'package:thumb_biomech_monitor_glove/features/recommendations/domain/models/research_recommendation.dart';

void main() {
  const service = RecommendationService();
  final t0 = DateTime.utc(2026, 9, 10, 10, 0, 0);

  BiomechanicalAnalysis buildAnalysis({
    Duration duration = const Duration(minutes: 1),
    int sampleCount = 60,
    int movementCount = 5,
    double movementsPerMinute = 10.0,
    double percentageTimeMoving = 15.0,
    double ipAngleExcursion = 30.0,
    double mcpAngleExcursion = 25.0,
    double averageForce = 1.5,
    double peakForce = 3.0,
    double forceExceedancePct = 5.0,
    double averageAngVel = 20.0,
    double peakAngVel = 50.0,
    double angVelExceedancePct = 5.0,
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
      cumulativeAbsoluteIpAngularChange: 120.0,
      cumulativeAbsoluteMcpAngularChange: 60.0,
      averageForce: averageForce,
      peakForce: peakForce,
      cumulativeForceExposure: averageForce * (duration.inMilliseconds / 1000.0),
      forceThresholdExceedanceDuration: Duration(
        milliseconds: (duration.inMilliseconds * (forceExceedancePct / 100.0)).round(),
      ),
      forceThresholdExceedancePercentage: forceExceedancePct,
      forceSampleExceedancePercentage: forceExceedancePct,
      averageAngularVelocity: averageAngVel,
      peakAngularVelocity: peakAngVel,
      cumulativeAngularVelocityExposure: averageAngVel * (duration.inMilliseconds / 1000.0),
      angularVelocityThresholdExceedanceDuration: Duration(
        milliseconds: (duration.inMilliseconds * (angVelExceedancePct / 100.0)).round(),
      ),
      angularVelocityThresholdExceedancePercentage: angVelExceedancePct,
      angularVelocitySampleExceedancePercentage: angVelExceedancePct,
    );
  }

  group('RecommendationService Unit Tests', () {
    test('1. Empty analysis returns empty recommendation list', () {
      final empty = BiomechanicalAnalysis.empty(sessionId: 'empty-sess');
      final recs = service.generateRecommendations(empty);

      expect(recs, isEmpty);
    });

    test('2. Zero-duration analysis returns empty recommendation list', () {
      final zeroDur = buildAnalysis(duration: Duration.zero);
      final recs = service.generateRecommendations(zeroDur);

      expect(recs, isEmpty);
    });

    test('3. Low exposure yields informational recommendation', () {
      final normal = buildAnalysis(
        movementsPerMinute: 10.0,
        percentageTimeMoving: 15.0,
        ipAngleExcursion: 25.0,
        mcpAngleExcursion: 20.0,
        peakForce: 3.0,
        forceExceedancePct: 0.0,
        peakAngVel: 40.0,
        angVelExceedancePct: 0.0,
      );
      final recs = service.generateRecommendations(normal);

      expect(recs.length, 1);
      expect(recs.first.id, 'rec_baseline_informational');
      expect(recs.first.priority, RecommendationPriority.informational);
      expect(recs.first.category, RecommendationCategory.general);
      expect(recs.first.title, contains('Baseline'));
    });

    test('4. Elevated movement frequency produces targeted recommendation', () {
      final elevatedMpm = buildAnalysis(movementsPerMinute: 35.0); // > 30 ref
      final recs = service.generateRecommendations(elevatedMpm);

      final rec = recs.firstWhere((r) => r.id == 'rec_movement_frequency');
      expect(rec.category, RecommendationCategory.movement);
      expect(rec.priority, RecommendationPriority.moderate);
      expect(rec.metricValue, 35.0);
      expect(rec.referenceValue, 30.0);
      expect(rec.unit, '/min');

      // High trigger (>= 1.3 * 30 = 39)
      final highMpm = buildAnalysis(movementsPerMinute: 45.0);
      final highRecs = service.generateRecommendations(highMpm);
      final highRec = highRecs.firstWhere((r) => r.id == 'rec_movement_frequency');
      expect(highRec.priority, RecommendationPriority.elevated);
      expect(highRec.title, contains('High Movement Frequency'));
    });

    test('5. Elevated movement percentage produces active time recommendation', () {
      final highActive = buildAnalysis(percentageTimeMoving: 45.0); // > 40 ref
      final recs = service.generateRecommendations(highActive);

      final rec = recs.firstWhere((r) => r.id == 'rec_active_time');
      expect(rec.category, RecommendationCategory.movement);
      expect(rec.metricValue, 45.0);
      expect(rec.referenceValue, 40.0);
      expect(rec.unit, '%');
    });

    test('6. Elevated force exposure percentage produces sustained force recommendation', () {
      final highForcePct = buildAnalysis(forceExceedancePct: 25.0); // > 20 ref
      final recs = service.generateRecommendations(highForcePct);

      final rec = recs.firstWhere((r) => r.id == 'rec_force_exposure');
      expect(rec.category, RecommendationCategory.force);
      expect(rec.evidence, contains('threshold'));
    });

    test('7. Elevated peak force produces elevated priority force recommendation', () {
      final highPeak = buildAnalysis(peakForce: 9.5); // > 8.0 ref
      final recs = service.generateRecommendations(highPeak);

      final rec = recs.firstWhere((r) => r.id == 'rec_peak_force');
      expect(rec.category, RecommendationCategory.force);
      expect(rec.priority, RecommendationPriority.elevated);
      expect(rec.metricValue, 9.5);
      expect(rec.unit, 'N');
    });

    test('8. Elevated angular velocity produces rapid motion dynamics recommendation', () {
      final highAngVel = buildAnalysis(
        peakAngVel: 150.0, // > 120 ref
        angVelExceedancePct: 25.0, // > 20 ref
      );
      final recs = service.generateRecommendations(highAngVel);

      final rec = recs.firstWhere((r) => r.id == 'rec_motion_velocity');
      expect(rec.category, RecommendationCategory.motionIntensity);
      expect(rec.priority, RecommendationPriority.elevated);
    });

    test('9. Elevated joint excursion produces range of motion recommendation', () {
      final highExcursion = buildAnalysis(ipAngleExcursion: 75.0); // > 60 ref
      final recs = service.generateRecommendations(highExcursion);

      final rec = recs.firstWhere((r) => r.id == 'rec_joint_excursion');
      expect(rec.category, RecommendationCategory.jointMotion);
      expect(rec.priority, RecommendationPriority.moderate);
    });

    test('10. Multiple elevated dimensions trigger combined general recommendation', () {
      final multi = buildAnalysis(
        movementsPerMinute: 42.0, // movement
        peakForce: 9.0, // force
        ipAngleExcursion: 70.0, // jointMotion
      );
      final recs = service.generateRecommendations(multi);

      expect(recs.any((r) => r.id == 'rec_movement_frequency'), isTrue);
      expect(recs.any((r) => r.id == 'rec_peak_force'), isTrue);
      expect(recs.any((r) => r.id == 'rec_joint_excursion'), isTrue);

      final combined = recs.firstWhere((r) => r.id == 'rec_combined_exposure');
      expect(combined.category, RecommendationCategory.general);
      expect(combined.priority, RecommendationPriority.elevated);
      expect(combined.title, contains('Combined Multi-Factor'));
    });

    test('11. Deterministic output produces identical results across repeated calls', () {
      final analysis = buildAnalysis(
        movementsPerMinute: 38.0,
        peakForce: 8.5,
      );

      final run1 = service.generateRecommendations(analysis);
      final run2 = service.generateRecommendations(analysis);

      expect(run1.length, run2.length);
      for (int i = 0; i < run1.length; i++) {
        expect(run1[i].id, run2[i].id);
        expect(run1[i].priority, run2[i].priority);
        expect(run1[i].title, run2[i].title);
      }
    });

    test('12. No duplicate recommendations generated', () {
      final multi = buildAnalysis(
        movementsPerMinute: 50.0,
        percentageTimeMoving: 80.0,
        peakForce: 10.0,
        forceExceedancePct: 50.0,
        peakAngVel: 200.0,
        angVelExceedancePct: 50.0,
        ipAngleExcursion: 80.0,
      );
      final recs = service.generateRecommendations(multi);

      final ids = recs.map((r) => r.id).toList();
      final uniqueIds = ids.toSet().toList();
      expect(ids.length, uniqueIds.length);
    });

    test('13. Priority ordering strictly ranks elevated before moderate before informational', () {
      final multi = buildAnalysis(
        movementsPerMinute: 32.0, // moderate
        peakForce: 9.0, // elevated
        ipAngleExcursion: 70.0, // moderate
      );
      final recs = service.generateRecommendations(multi);

      for (int i = 0; i < recs.length - 1; i++) {
        expect(recs[i].priority.rank >= recs[i + 1].priority.rank, isTrue);
      }
    });

    test('14. Configurable reference values alter trigger thresholds cleanly', () {
      // With default config (refMovementsPerMinute = 30), 25.0 will NOT trigger
      final analysis = buildAnalysis(movementsPerMinute: 25.0);
      final defaultRecs = service.generateRecommendations(analysis);
      expect(defaultRecs.any((r) => r.id == 'rec_movement_frequency'), isFalse);

      // With custom config (refMovementsPerMinute = 20), 25.0 WILL trigger
      final customConfig = RecommendationConfig(refMovementsPerMinute: 20.0);
      final customRecs = service.generateRecommendations(analysis, config: customConfig);
      expect(customRecs.any((r) => r.id == 'rec_movement_frequency'), isTrue);
    });

    test('15. Serialization and deserialization preserves all fields', () {
      final rec = ResearchRecommendation(
        id: 'rec_test',
        title: 'Test Title',
        description: 'Test Description',
        category: RecommendationCategory.force,
        priority: RecommendationPriority.elevated,
        evidence: 'Test evidence',
        metricValue: 7.5,
        referenceValue: 4.0,
        unit: 'N',
        generatedAt: t0,
      );

      final json = rec.toJson();
      final copy = ResearchRecommendation.fromJson(json);

      expect(copy, equals(rec));
    });
  });
}
