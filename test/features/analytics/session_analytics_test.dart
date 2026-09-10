import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thumb_biomech_monitor_glove/core/models/monitoring_session.dart';
import 'package:thumb_biomech_monitor_glove/core/models/sensor_reading.dart';
import 'package:thumb_biomech_monitor_glove/core/services/local_monitoring_session_repository.dart';
import 'package:thumb_biomech_monitor_glove/core/services/monitoring_session_repository.dart';
import 'package:thumb_biomech_monitor_glove/features/analytics/application/analytics_service.dart';
import 'package:thumb_biomech_monitor_glove/features/analytics/domain/models/session_analytics.dart';

void main() {
  final t0 = DateTime.utc(2026, 9, 10, 10, 0, 0);

  SensorReading createReading({
    required int offsetSeconds,
    required double ip,
    required double mcp,
    required double force,
    required double angularVelocity,
    required double motionMagnitude,
  }) =>
      SensorReading(
        timestamp: t0.add(Duration(seconds: offsetSeconds)),
        ipAngle: ip,
        mcpAngle: mcp,
        force: force,
        angularVelocity: angularVelocity,
        motionMagnitude: motionMagnitude,
      );

  MonitoringSession createSession({
    required String id,
    required DateTime start,
    required DateTime end,
    int movementCount = 0,
    double avgIp = 0.0,
    double maxIp = 0.0,
    double avgMcp = 0.0,
    double maxMcp = 0.0,
    double avgForce = 0.0,
    double peakForce = 0.0,
    double avgAngVel = 0.0,
    double avgMotionMag = 0.0,
  }) =>
      MonitoringSession(
        id: id,
        startTime: start,
        endTime: end,
        movementCount: movementCount,
        averageIpAngle: avgIp,
        maximumIpAngle: maxIp,
        averageMcpAngle: avgMcp,
        maximumMcpAngle: maxMcp,
        averageForce: avgForce,
        peakForce: peakForce,
        averageAngularVelocity: avgAngVel,
        averageMotionMagnitude: avgMotionMag,
      );

  // ───────────────────────────────────────────────────────────────────────────
  // Group 1: Domain Model
  // ───────────────────────────────────────────────────────────────────────────

  group('SessionAnalytics Domain Model', () {
    test('1. SessionAnalytics.empty creates zeroed metrics safely', () {
      final empty = SessionAnalytics.empty(
        sessionId: 'empty-001',
        startTime: t0,
        endTime: t0.add(const Duration(minutes: 5)),
        movementCount: 2,
      );

      expect(empty.sessionId, 'empty-001');
      expect(empty.sampleCount, 0);
      expect(empty.hasReadings, isFalse);
      expect(empty.movementCount, 2);
      expect(empty.movementsPerMinute, 0.0);
      expect(empty.averageIpAngle, 0.0);
      expect(empty.minimumIpAngle, 0.0);
      expect(empty.maximumIpAngle, 0.0);
      expect(empty.ipAngleExcursion, 0.0);
      expect(empty.averageMcpAngle, 0.0);
      expect(empty.minimumMcpAngle, 0.0);
      expect(empty.maximumMcpAngle, 0.0);
      expect(empty.mcpAngleExcursion, 0.0);
      expect(empty.averageForce, 0.0);
      expect(empty.peakForce, 0.0);
      expect(empty.averageAngularVelocity, 0.0);
      expect(empty.peakAngularVelocity, 0.0);
      expect(empty.averageMotionMagnitude, 0.0);
      expect(empty.peakMotionMagnitude, 0.0);
    });

    test('2. SessionAnalytics serializes to and from JSON faithfully', () {
      final analytics = SessionAnalytics(
        sessionId: 'test-sess-json',
        startTime: t0,
        endTime: t0.add(const Duration(minutes: 2)),
        duration: const Duration(minutes: 2),
        sampleCount: 120,
        movementCount: 10,
        movementsPerMinute: 5.0,
        averageIpAngle: 35.5,
        minimumIpAngle: 15.0,
        maximumIpAngle: 60.0,
        ipAngleExcursion: 45.0,
        averageMcpAngle: 25.2,
        minimumMcpAngle: 10.0,
        maximumMcpAngle: 40.0,
        mcpAngleExcursion: 30.0,
        averageForce: 2.34,
        peakForce: 5.67,
        averageAngularVelocity: 18.5,
        peakAngularVelocity: 35.0,
        averageMotionMagnitude: 0.45,
        peakMotionMagnitude: 0.89,
      );

      final json = analytics.toJson();
      final restored = SessionAnalytics.fromJson(json);

      expect(restored, equals(analytics));
      expect(restored.sessionId, 'test-sess-json');
      expect(restored.sampleCount, 120);
      expect(restored.hasReadings, isTrue);
      expect(restored.ipAngleExcursion, 45.0);
      expect(restored.mcpAngleExcursion, 30.0);
      expect(restored.peakForce, 5.67);
    });

    test('3. Value equality and toString work correctly', () {
      final a1 = SessionAnalytics.empty(sessionId: 'same-id', startTime: t0);
      final a2 = SessionAnalytics.empty(sessionId: 'same-id', startTime: t0);
      final b = SessionAnalytics.empty(sessionId: 'other-id', startTime: t0);

      expect(a1, equals(a2));
      expect(a1.hashCode, equals(a2.hashCode));
      expect(a1, isNot(equals(b)));
      expect(a1.toString(), contains('sessionId: same-id'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Group 2: Deterministic Metrics Calculations
  // ───────────────────────────────────────────────────────────────────────────

  group('Deterministic Biomechanical Metrics Calculations', () {
    test('4. Correctly computes exact averages, extrema, and excursions for multi-reading batch', () {
      final readings = [
        createReading(
          offsetSeconds: 0,
          ip: 20.0,
          mcp: 10.0,
          force: 1.0,
          angularVelocity: -10.0,
          motionMagnitude: 0.2,
        ),
        createReading(
          offsetSeconds: 30,
          ip: 40.0,
          mcp: 30.0,
          force: 3.0,
          angularVelocity: 20.0,
          motionMagnitude: 0.6,
        ),
        createReading(
          offsetSeconds: 60,
          ip: 60.0,
          mcp: 20.0,
          force: 5.0,
          angularVelocity: -30.0,
          motionMagnitude: 0.4,
        ),
      ];

      final analytics = AnalyticsService.calculate(
        sessionId: 'deterministic-01',
        startTime: t0,
        endTime: t0.add(const Duration(seconds: 60)),
        movementCount: 6,
        readings: readings,
      );

      // Sample count
      expect(analytics.sampleCount, 3);
      expect(analytics.hasReadings, isTrue);

      // Duration & Movement Frequency
      expect(analytics.duration, const Duration(seconds: 60));
      expect(analytics.movementCount, 6);
      expect(analytics.movementsPerMinute, closeTo(6.0, 0.001)); // 6 movements / 1 min = 6/min

      // IP Joint Metrics
      expect(analytics.averageIpAngle, closeTo(40.0, 0.0001)); // (20 + 40 + 60) / 3 = 40.0
      expect(analytics.minimumIpAngle, 20.0);
      expect(analytics.maximumIpAngle, 60.0);
      expect(analytics.ipAngleExcursion, 40.0); // 60.0 - 20.0 = 40.0

      // MCP Joint Metrics
      expect(analytics.averageMcpAngle, closeTo(20.0, 0.0001)); // (10 + 30 + 20) / 3 = 20.0
      expect(analytics.minimumMcpAngle, 10.0);
      expect(analytics.maximumMcpAngle, 30.0);
      expect(analytics.mcpAngleExcursion, 20.0); // 30.0 - 10.0 = 20.0

      // Force Metrics
      expect(analytics.averageForce, closeTo(3.0, 0.0001)); // (1 + 3 + 5) / 3 = 3.0
      expect(analytics.peakForce, 5.0);

      // Angular Velocity Metrics (absolute magnitude for direction-invariant rate)
      // |-10| = 10, |20| = 20, |-30| = 30 -> avg = 20.0, peak = 30.0
      expect(analytics.averageAngularVelocity, closeTo(20.0, 0.0001));
      expect(analytics.peakAngularVelocity, 30.0);

      // Motion Magnitude Metrics
      expect(analytics.averageMotionMagnitude, closeTo(0.4, 0.0001)); // (0.2 + 0.6 + 0.4) / 3 = 0.4
      expect(analytics.peakMotionMagnitude, 0.6);
    });

    test('5. Integrates with MonitoringSession summary duration and movement count', () {
      final session = createSession(
        id: 'sess-with-meta',
        start: t0,
        end: t0.add(const Duration(minutes: 2)), // 120s = 2 min
        movementCount: 14,
      );

      final readings = [
        createReading(
          offsetSeconds: 10,
          ip: 30.0,
          mcp: 15.0,
          force: 2.0,
          angularVelocity: 15.0,
          motionMagnitude: 0.3,
        ),
        createReading(
          offsetSeconds: 90,
          ip: 50.0,
          mcp: 25.0,
          force: 4.0,
          angularVelocity: 25.0,
          motionMagnitude: 0.5,
        ),
      ];

      final analytics = AnalyticsService.calculate(
        sessionId: session.id,
        session: session,
        readings: readings,
      );

      expect(analytics.duration, const Duration(minutes: 2));
      expect(analytics.movementCount, 14);
      expect(analytics.movementsPerMinute, closeTo(7.0, 0.001)); // 14 / 2 min = 7.0/min
      expect(analytics.sampleCount, 2);
      expect(analytics.ipAngleExcursion, 20.0); // 50 - 30
      expect(analytics.mcpAngleExcursion, 10.0); // 25 - 15
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Group 3: Edge Cases & Resilience
  // ───────────────────────────────────────────────────────────────────────────

  group('Edge Cases and Boundary Conditions', () {
    test('6. Empty readings dataset returns safe zeroed metrics without crashing', () {
      final analytics = AnalyticsService.calculate(
        sessionId: 'empty-readings',
        startTime: t0,
        endTime: t0.add(const Duration(seconds: 100)),
        movementCount: 0,
        readings: const [],
      );

      expect(analytics.sampleCount, 0);
      expect(analytics.hasReadings, isFalse);
      expect(analytics.duration, const Duration(seconds: 100));
      expect(analytics.movementCount, 0);
      expect(analytics.movementsPerMinute, 0.0);
      expect(analytics.averageIpAngle, 0.0);
      expect(analytics.minimumIpAngle, 0.0);
      expect(analytics.maximumIpAngle, 0.0);
      expect(analytics.ipAngleExcursion, 0.0);
      expect(analytics.averageMcpAngle, 0.0);
      expect(analytics.minimumMcpAngle, 0.0);
      expect(analytics.maximumMcpAngle, 0.0);
      expect(analytics.mcpAngleExcursion, 0.0);
      expect(analytics.averageForce, 0.0);
      expect(analytics.peakForce, 0.0);
      expect(analytics.averageAngularVelocity, 0.0);
      expect(analytics.peakAngularVelocity, 0.0);
      expect(analytics.averageMotionMagnitude, 0.0);
      expect(analytics.peakMotionMagnitude, 0.0);
    });

    test('7. Empty readings with existing session summary falls back safely to session metadata', () {
      final session = createSession(
        id: 'meta-only',
        start: t0,
        end: t0.add(const Duration(minutes: 1)),
        movementCount: 4,
        avgIp: 32.0,
        maxIp: 45.0,
        avgMcp: 18.0,
        maxMcp: 28.0,
        avgForce: 2.1,
        peakForce: 3.8,
        avgAngVel: 12.0,
        avgMotionMag: 0.35,
      );

      final analytics = AnalyticsService.calculate(
        sessionId: session.id,
        session: session,
        readings: const [],
      );

      expect(analytics.sampleCount, 0);
      expect(analytics.hasReadings, isFalse);
      expect(analytics.duration, const Duration(minutes: 1));
      expect(analytics.movementCount, 4);
      expect(analytics.movementsPerMinute, closeTo(4.0, 0.001));
      expect(analytics.averageIpAngle, 32.0);
      expect(analytics.maximumIpAngle, 45.0);
      expect(analytics.averageMcpAngle, 18.0);
      expect(analytics.maximumMcpAngle, 28.0);
      expect(analytics.averageForce, 2.1);
      expect(analytics.peakForce, 3.8);
    });

    test('8. Single reading dataset has min = max = average, excursion = 0', () {
      final readings = [
        createReading(
          offsetSeconds: 15,
          ip: 42.0,
          mcp: 24.0,
          force: 3.5,
          angularVelocity: -15.0,
          motionMagnitude: 0.75,
        ),
      ];

      final analytics = AnalyticsService.calculate(
        sessionId: 'single-sample',
        startTime: t0,
        endTime: t0.add(const Duration(seconds: 30)),
        movementCount: 1,
        readings: readings,
      );

      expect(analytics.sampleCount, 1);
      expect(analytics.hasReadings, isTrue);

      // IP Angle: min == max == average == 42.0, excursion == 0.0
      expect(analytics.averageIpAngle, 42.0);
      expect(analytics.minimumIpAngle, 42.0);
      expect(analytics.maximumIpAngle, 42.0);
      expect(analytics.ipAngleExcursion, 0.0);

      // MCP Angle: min == max == average == 24.0, excursion == 0.0
      expect(analytics.averageMcpAngle, 24.0);
      expect(analytics.minimumMcpAngle, 24.0);
      expect(analytics.maximumMcpAngle, 24.0);
      expect(analytics.mcpAngleExcursion, 0.0);

      // Force
      expect(analytics.averageForce, 3.5);
      expect(analytics.peakForce, 3.5);

      // Angular Velocity
      expect(analytics.averageAngularVelocity, 15.0);
      expect(analytics.peakAngularVelocity, 15.0);

      // Motion Magnitude
      expect(analytics.averageMotionMagnitude, 0.75);
      expect(analytics.peakMotionMagnitude, 0.75);
    });

    test('9. Zero-duration session handles movements/minute safely without division by zero', () {
      final readings = [
        createReading(
          offsetSeconds: 0,
          ip: 25.0,
          mcp: 15.0,
          force: 2.0,
          angularVelocity: 5.0,
          motionMagnitude: 0.1,
        ),
      ];

      final analytics = AnalyticsService.calculate(
        sessionId: 'zero-duration',
        startTime: t0,
        endTime: t0, // identical start and end -> duration 0
        movementCount: 3,
        readings: readings,
      );

      expect(analytics.duration, Duration.zero);
      expect(analytics.movementCount, 3);
      expect(analytics.movementsPerMinute, 0.0); // safe division guard
      expect(analytics.sampleCount, 1);
    });

    test('10. Zero movements in active duration yields 0.0 movements per minute', () {
      final readings = [
        createReading(
          offsetSeconds: 0,
          ip: 20.0,
          mcp: 10.0,
          force: 1.0,
          angularVelocity: 0.0,
          motionMagnitude: 0.05,
        ),
        createReading(
          offsetSeconds: 60,
          ip: 20.0,
          mcp: 10.0,
          force: 1.0,
          angularVelocity: 0.0,
          motionMagnitude: 0.05,
        ),
      ];

      final analytics = AnalyticsService.calculate(
        sessionId: 'zero-movements',
        startTime: t0,
        endTime: t0.add(const Duration(seconds: 60)),
        movementCount: 0,
        readings: readings,
      );

      expect(analytics.duration, const Duration(seconds: 60));
      expect(analytics.movementCount, 0);
      expect(analytics.movementsPerMinute, 0.0);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Group 4: Repository Abstraction Integration
  // ───────────────────────────────────────────────────────────────────────────

  group('AnalyticsService Repository Integration', () {
    late Directory tempDir;
    late MonitoringSessionRepository repository;
    late AnalyticsService analyticsService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('analytics_repo_test_');
      repository = LocalMonitoringSessionRepository(
        storageFile: File('${tempDir.path}/sessions.json'),
      );
      analyticsService = AnalyticsService(repository);
    });

    tearDown(() async {
      (repository as LocalMonitoringSessionRepository).dispose();
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('11. computeSessionAnalytics retrieves session and readings through repository abstraction', () async {
      final session = createSession(
        id: 'repo-sess-01',
        start: t0,
        end: t0.add(const Duration(seconds: 120)),
        movementCount: 8,
      );

      final readings = [
        createReading(
          offsetSeconds: 10,
          ip: 25.0,
          mcp: 15.0,
          force: 2.0,
          angularVelocity: 10.0,
          motionMagnitude: 0.2,
        ),
        createReading(
          offsetSeconds: 60,
          ip: 45.0,
          mcp: 35.0,
          force: 4.0,
          angularVelocity: 20.0,
          motionMagnitude: 0.4,
        ),
        createReading(
          offsetSeconds: 110,
          ip: 35.0,
          mcp: 25.0,
          force: 6.0,
          angularVelocity: -30.0,
          motionMagnitude: 0.6,
        ),
      ];

      await repository.saveSession(session, readings: readings);

      final result = await analyticsService.computeSessionAnalytics('repo-sess-01');

      expect(result.sessionId, 'repo-sess-01');
      expect(result.sampleCount, 3);
      expect(result.hasReadings, isTrue);
      expect(result.movementCount, 8);
      expect(result.duration, const Duration(seconds: 120));
      expect(result.movementsPerMinute, closeTo(4.0, 0.001)); // 8 / 2 min = 4.0/min

      // IP metrics: 25, 45, 35 -> avg = 35.0, min = 25, max = 45, excursion = 20
      expect(result.averageIpAngle, closeTo(35.0, 0.001));
      expect(result.minimumIpAngle, 25.0);
      expect(result.maximumIpAngle, 45.0);
      expect(result.ipAngleExcursion, 20.0);

      // MCP metrics: 15, 35, 25 -> avg = 25.0, min = 15, max = 35, excursion = 20
      expect(result.averageMcpAngle, closeTo(25.0, 0.001));
      expect(result.minimumMcpAngle, 15.0);
      expect(result.maximumMcpAngle, 35.0);
      expect(result.mcpAngleExcursion, 20.0);

      // Force: 2, 4, 6 -> avg = 4.0, peak = 6.0
      expect(result.averageForce, closeTo(4.0, 0.001));
      expect(result.peakForce, 6.0);

      // Angular velocity: |10|, |20|, |-30| -> avg = 20.0, peak = 30.0
      expect(result.averageAngularVelocity, closeTo(20.0, 0.001));
      expect(result.peakAngularVelocity, 30.0);

      // Motion magnitude: 0.2, 0.4, 0.6 -> avg = 0.4, peak = 0.6
      expect(result.averageMotionMagnitude, closeTo(0.4, 0.001));
      expect(result.peakMotionMagnitude, 0.6);
    });

    test('12. computeAllSessionsAnalytics computes analytics for all sessions in repository', () async {
      final s1 = createSession(
        id: 'multi-01',
        start: t0,
        end: t0.add(const Duration(seconds: 60)),
        movementCount: 5,
      );
      final r1 = [createReading(offsetSeconds: 10, ip: 20, mcp: 10, force: 1, angularVelocity: 5, motionMagnitude: 0.1)];

      final s2 = createSession(
        id: 'multi-02',
        start: t0.add(const Duration(minutes: 10)),
        end: t0.add(const Duration(minutes: 11)),
        movementCount: 10,
      );
      final r2 = [createReading(offsetSeconds: 10, ip: 40, mcp: 20, force: 2, angularVelocity: 10, motionMagnitude: 0.2)];

      await repository.saveSession(s1, readings: r1);
      await repository.saveSession(s2, readings: r2);

      final allAnalytics = await analyticsService.computeAllSessionsAnalytics();

      expect(allAnalytics, hasLength(2));
      // Repository returns newest first
      expect(allAnalytics.first.sessionId, 'multi-02');
      expect(allAnalytics.first.movementCount, 10);
      expect(allAnalytics.last.sessionId, 'multi-01');
      expect(allAnalytics.last.movementCount, 5);
    });

    test('13. computeSessionAnalytics for non-existent session ID returns empty analytics safely', () async {
      final result = await analyticsService.computeSessionAnalytics('unknown-id');

      expect(result.sessionId, 'unknown-id');
      expect(result.sampleCount, 0);
      expect(result.hasReadings, isFalse);
      expect(result.averageIpAngle, 0.0);
      expect(result.averageForce, 0.0);
    });
  });
}
