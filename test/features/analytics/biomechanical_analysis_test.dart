import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thumb_biomech_monitor_glove/core/models/monitoring_session.dart';
import 'package:thumb_biomech_monitor_glove/core/models/sensor_reading.dart';
import 'package:thumb_biomech_monitor_glove/core/services/monitoring_session_repository.dart';
import 'package:thumb_biomech_monitor_glove/features/analytics/application/biomechanical_analysis_service.dart';
import 'package:thumb_biomech_monitor_glove/features/analytics/domain/models/biomechanical_analysis.dart';

/// In-memory fake repository implementation for deterministic testing.
class FakeMonitoringSessionRepository extends ChangeNotifier implements MonitoringSessionRepository {
  final List<MonitoringSession> _sessions = [];
  final Map<String, List<SensorReading>> _readings = {};

  void addTestSession(MonitoringSession session, {List<SensorReading>? readings}) {
    _sessions.add(session);
    if (readings != null) {
      _readings[session.id] = List.unmodifiable(readings);
    }
    notifyListeners();
  }

  @override
  Future<void> saveSession(MonitoringSession session, {List<SensorReading>? readings}) async {
    _sessions.removeWhere((s) => s.id == session.id);
    _sessions.add(session);
    if (readings != null) {
      _readings[session.id] = List.unmodifiable(readings);
    }
    notifyListeners();
  }

  @override
  Future<List<MonitoringSession>> getSessions() async {
    final copy = List<MonitoringSession>.from(_sessions);
    copy.sort((a, b) => b.startTime.compareTo(a.startTime));
    return copy;
  }

  @override
  Future<MonitoringSession?> getSessionById(String id) async {
    final matches = _sessions.where((s) => s.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<void> saveSensorReadings(String sessionId, List<SensorReading> readings) async {
    _readings[sessionId] = List.unmodifiable(readings);
  }

  @override
  Future<List<SensorReading>> getSensorReadings(String sessionId) async =>
      _readings[sessionId] ?? const [];

  @override
  Future<void> deleteSession(String id) async {
    _sessions.removeWhere((s) => s.id == id);
    _readings.remove(id);
    notifyListeners();
  }
}

void main() {
  final t0 = DateTime.utc(2026, 9, 10, 10, 0, 0);

  SensorReading readingAt(
    DateTime timestamp, {
    double ip = 20.0,
    double mcp = 10.0,
    double force = 1.0,
    double av = 5.0,
    double mm = 0.1,
  }) =>
      SensorReading(
        timestamp: timestamp,
        ipAngle: ip,
        mcpAngle: mcp,
        force: force,
        angularVelocity: av,
        motionMagnitude: mm,
      );

  MonitoringSession createSession({
    required String id,
    required DateTime start,
    required DateTime end,
    int movementCount = 0,
    double avgIp = 20.0,
    double maxIp = 40.0,
    double avgMcp = 10.0,
    double maxMcp = 30.0,
    double avgForce = 2.0,
    double peakForce = 4.0,
    double avgAngVel = 15.0,
    double avgMotionMag = 0.3,
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

  group('BiomechanicalAnalysis Model & Serialization', () {
    test('1. BiomechanicalAnalysis.empty creates safe zeroed metrics', () {
      final empty = BiomechanicalAnalysis.empty(
        sessionId: 'empty-sess',
        startTime: t0,
        endTime: t0.add(const Duration(minutes: 5)),
      );

      expect(empty.sessionId, 'empty-sess');
      expect(empty.sampleCount, 0);
      expect(empty.hasReadings, isFalse);
      expect(empty.duration, const Duration(minutes: 5));
      expect(empty.movementCount, 0);
      expect(empty.movementsPerMinute, 0.0);
      expect(empty.totalTimeMoving, Duration.zero);
      expect(empty.averageMovementDuration, Duration.zero);
      expect(empty.percentageTimeMoving, 0.0);
      expect(empty.averageRestInterval, Duration.zero);
      expect(empty.ipAngleExcursion, 0.0);
      expect(empty.mcpAngleExcursion, 0.0);
      expect(empty.cumulativeForceExposure, 0.0);
      expect(empty.cumulativeAngularVelocityExposure, 0.0);
    });

    test('2. BiomechanicalAnalysisConfig and BiomechanicalAnalysis serialize to/from JSON faithfully', () {
      const config = BiomechanicalAnalysisConfig(
        forceThreshold: 3.5,
        angularVelocityThreshold: 45.0,
      );

      final analysis = BiomechanicalAnalysis(
        sessionId: 'test-json',
        startTime: t0,
        endTime: t0.add(const Duration(seconds: 60)),
        duration: const Duration(seconds: 60),
        sampleCount: 2,
        config: config,
        movementCount: 1,
        movementsPerMinute: 1.0,
        totalTimeMoving: const Duration(seconds: 5),
        averageMovementDuration: const Duration(seconds: 5),
        percentageTimeMoving: 8.33,
        averageRestInterval: Duration.zero,
        movementIntervals: [
          MovementEventInterval(
            startTime: t0,
            endTime: t0.add(const Duration(seconds: 5)),
          ),
        ],
        ipAngleExcursion: 25.0,
        mcpAngleExcursion: 15.0,
        averageIpAngularChange: 10.0,
        averageMcpAngularChange: 5.0,
        cumulativeAbsoluteIpAngularChange: 10.0,
        cumulativeAbsoluteMcpAngularChange: 5.0,
        averageForce: 2.5,
        peakForce: 4.0,
        cumulativeForceExposure: 150.0,
        forceThresholdExceedanceDuration: const Duration(seconds: 10),
        forceThresholdExceedancePercentage: 16.67,
        forceSampleExceedancePercentage: 50.0,
        averageAngularVelocity: 20.0,
        peakAngularVelocity: 40.0,
        cumulativeAngularVelocityExposure: 1200.0,
        angularVelocityThresholdExceedanceDuration: const Duration(seconds: 8),
        angularVelocityThresholdExceedancePercentage: 13.33,
        angularVelocitySampleExceedancePercentage: 50.0,
      );

      final json = analysis.toJson();
      final restored = BiomechanicalAnalysis.fromJson(json);

      expect(restored.sessionId, analysis.sessionId);
      expect(restored.config.forceThreshold, 3.5);
      expect(restored.config.angularVelocityThreshold, 45.0);
      expect(restored.movementCount, analysis.movementCount);
      expect(restored.cumulativeForceExposure, analysis.cumulativeForceExposure);
      expect(restored.movementIntervals.length, 1);
      expect(restored.movementIntervals.first.duration, const Duration(seconds: 5));
      expect(restored, equals(analysis));
      expect(analysis.toString(), contains('test-json'));
    });
  });

  group('Joint Motion & Kinematics Calculations', () {
    test('3. Computes exact excursions, deltas, and cumulative angular changes', () {
      // 4 samples: transitions are:
      // t0 -> t1: Δip = |30 - 20| = 10, Δmcp = |15 - 10| = 5
      // t1 -> t2: Δip = |10 - 30| = 20, Δmcp = |35 - 15| = 20
      // t2 -> t3: Δip = |45 - 10| = 35, Δmcp = |20 - 35| = 15
      // Sum Δip = 10 + 20 + 35 = 65.0. Avg Δip = 65.0 / 3 = 21.666666...
      // Sum Δmcp = 5 + 20 + 15 = 40.0. Avg Δmcp = 40.0 / 3 = 13.333333...
      // Min ip: 10, Max ip: 45 -> Excursion: 35.0
      // Min mcp: 10, Max mcp: 35 -> Excursion: 25.0
      final readings = [
        readingAt(t0, ip: 20.0, mcp: 10.0),
        readingAt(t0.add(const Duration(seconds: 1)), ip: 30.0, mcp: 15.0),
        readingAt(t0.add(const Duration(seconds: 2)), ip: 10.0, mcp: 35.0),
        readingAt(t0.add(const Duration(seconds: 3)), ip: 45.0, mcp: 20.0),
      ];

      final result = BiomechanicalAnalysisService.analyze(
        sessionId: 'joint-test',
        readings: readings,
      );

      expect(result.ipAngleExcursion, 35.0);
      expect(result.mcpAngleExcursion, 25.0);
      expect(result.cumulativeAbsoluteIpAngularChange, 65.0);
      expect(result.cumulativeAbsoluteMcpAngularChange, 40.0);
      expect(result.averageIpAngularChange, closeTo(65.0 / 3.0, 1e-5));
      expect(result.averageMcpAngularChange, closeTo(40.0 / 3.0, 1e-5));
    });
  });

  group('Force Exposure & Numerical Integration', () {
    test('4. Computes trapezoidal force exposure (N·s) and linear threshold exceedance duration', () {
      // 3 samples over regular 1-second intervals:
      // t0 (0s): Force = 1.0 N
      // t1 (1s): Force = 3.0 N
      // t2 (2s): Force = 5.0 N
      // Trapezoid 1 (0 to 1s): ((1.0 + 3.0)/2) * 1.0 = 2.0 N·s
      // Trapezoid 2 (1 to 2s): ((3.0 + 5.0)/2) * 1.0 = 4.0 N·s
      // Total Force Exposure = 6.0 N·s
      // Average Force = (1 + 3 + 5) / 3 = 3.0 N
      // Peak Force = 5.0 N
      //
      // With forceThreshold = 2.0 N:
      // Interval 1 (1.0 -> 3.0): crosses at (3 - 2)/(3 - 1) = 0.5s above threshold -> 0.5s
      // Interval 2 (3.0 -> 5.0): both above threshold -> 1.0s
      // Total force threshold exceedance duration = 1.5s
      // Total valid time = 2.0s -> Percentage = (1.5 / 2.0) * 100 = 75.0%
      // Samples >= 2.0: 2 samples (3.0 and 5.0) out of 3 -> 66.6666...%
      final readings = [
        readingAt(t0, force: 1.0),
        readingAt(t0.add(const Duration(seconds: 1)), force: 3.0),
        readingAt(t0.add(const Duration(seconds: 2)), force: 5.0),
      ];

      final result = BiomechanicalAnalysisService.analyze(
        sessionId: 'force-test',
        readings: readings,
        config: const BiomechanicalAnalysisConfig(forceThreshold: 2.0),
      );

      expect(result.averageForce, 3.0);
      expect(result.peakForce, 5.0);
      expect(result.cumulativeForceExposure, closeTo(6.0, 1e-5));
      expect(result.forceThresholdExceedanceDuration.inMilliseconds, 1500);
      expect(result.forceThresholdExceedancePercentage, closeTo(75.0, 1e-5));
      expect(result.forceSampleExceedancePercentage, closeTo(200.0 / 3.0, 1e-5));
    });

    test('5. Handles irregular time intervals correctly during integration', () {
      // Irregular intervals:
      // t0 (0s): Force = 2.0 N
      // t1 (0.5s, dt = 0.5s): Force = 4.0 N -> Trapezoid 1: ((2 + 4)/2) * 0.5 = 1.5 N·s
      // t2 (3.5s, dt = 3.0s): Force = 2.0 N -> Trapezoid 2: ((4 + 2)/2) * 3.0 = 9.0 N·s
      // Total cumulative force exposure = 1.5 + 9.0 = 10.5 N·s
      final readings = [
        readingAt(t0, force: 2.0),
        readingAt(t0.add(const Duration(milliseconds: 500)), force: 4.0),
        readingAt(t0.add(const Duration(milliseconds: 3500)), force: 2.0),
      ];

      final result = BiomechanicalAnalysisService.analyze(
        sessionId: 'irregular-dt',
        readings: readings,
      );

      expect(result.cumulativeForceExposure, closeTo(10.5, 1e-5));
    });

    test('6. Skips zero or negative time intervals safely without corrupting exposure', () {
      // Readings with out-of-order or duplicate timestamps:
      // t0 (0s): Force = 2.0 N
      // t0 (0s, dt = 0s): Force = 5.0 N (duplicate timestamp -> skipped for integration)
      // t0 - 1s (negative dt -> skipped)
      // t0 + 2s (dt = 2s from previous): Force = 4.0 N
      // Only valid interval is from the negative sample to t0+2s: dt = 3.0s, ((1 + 4)/2) * 3 = 7.5
      final readings = [
        readingAt(t0, force: 2.0),
        readingAt(t0, force: 5.0),
        readingAt(t0.subtract(const Duration(seconds: 1)), force: 1.0),
        readingAt(t0.add(const Duration(seconds: 2)), force: 4.0),
      ];

      final result = BiomechanicalAnalysisService.analyze(
        sessionId: 'negative-dt',
        readings: readings,
      );

      expect(result.cumulativeForceExposure, isPositive);
      expect(result.forceThresholdExceedancePercentage, isNot(isNaN));
      expect(result.forceThresholdExceedancePercentage, inInclusiveRange(0.0, 100.0));
    });
  });

  group('Motion Intensity & Angular Velocity Exposure', () {
    test('7. Computes angular velocity exposure in degrees (°) and peak values', () {
      // 3 samples:
      // t0: av = 10 °/s
      // t1 (1s): av = 50 °/s
      // t2 (2s): av = 20 °/s
      // Trapezoid 1 (0 to 1s): ((10 + 50)/2) * 1 = 30°
      // Trapezoid 2 (1 to 2s): ((50 + 20)/2) * 1 = 35°
      // Cumulative AngVel Exposure = 65°
      // Peak AngVel = 50 °/s
      // Average AngVel = (10 + 50 + 20)/3 = 26.6666... °/s
      //
      // With angularVelocityThreshold = 30 °/s:
      // Interval 1 (10 -> 50): fraction above = (50 - 30)/40 = 0.5s
      // Interval 2 (50 -> 20): fraction above = (50 - 30)/30 = 2/3s = 0.6666...s
      // Exceedance duration = 0.5 + 0.6666... = 1.16666...s
      final readings = [
        readingAt(t0, av: 10.0),
        readingAt(t0.add(const Duration(seconds: 1)), av: 50.0),
        readingAt(t0.add(const Duration(seconds: 2)), av: 20.0),
      ];

      final result = BiomechanicalAnalysisService.analyze(
        sessionId: 'motion-test',
        readings: readings,
        config: const BiomechanicalAnalysisConfig(angularVelocityThreshold: 30.0),
      );

      expect(result.peakAngularVelocity, 50.0);
      expect(result.averageAngularVelocity, closeTo(80.0 / 3.0, 1e-5));
      expect(result.cumulativeAngularVelocityExposure, closeTo(65.0, 1e-5));
      expect(result.angularVelocityThresholdExceedanceDuration.inMicroseconds, closeTo(1166667, 100));
      expect(result.angularVelocityThresholdExceedancePercentage, closeTo((1.1666667 / 2.0) * 100.0, 0.1));
    });
  });

  group('Movement Detection & Repetition Metrics', () {
    test('8. Extracts movement event duration, percentage time moving, and rest intervals', () {
      // Build a 10-second session with two distinct movement events:
      // Config: ipAngleChangeDeg = 3.0, motionMagnitudeG = 0.15, minDuration = 200ms, debounce = 400ms
      // Event 1: t0+1s to t0+2s (duration 1000ms)
      // Rest: t0+2s to t0+5s (rest interval = 3000ms)
      // Event 2: t0+5s to t0+7s (duration 2000ms)
      // Inactivity to end at t0+10s.
      // Total time moving = 1000 + 2000 = 3000ms.
      // Average movement duration = 3000 / 2 = 1500ms.
      // Session duration = 10,000ms -> Percentage moving = (3000 / 10000) * 100 = 30.0%.
      // Average rest interval = 3000ms.
      final readings = [
        // Baseline rest (0s)
        readingAt(t0, ip: 10.0, mcp: 10.0, av: 0.0, mm: 0.0),
        // Event 1 start (1.0s) -> flex delta = 5.0, mm = 0.3 (active)
        readingAt(t0.add(const Duration(seconds: 1)), ip: 15.0, mcp: 10.0, av: 5.0, mm: 0.3),
        // Event 1 continue (1.5s) -> active
        readingAt(t0.add(const Duration(milliseconds: 1500)), ip: 20.0, mcp: 10.0, av: 5.0, mm: 0.3),
        // Event 1 end (2.0s) -> active
        readingAt(t0.add(const Duration(seconds: 2)), ip: 25.0, mcp: 10.0, av: 5.0, mm: 0.3),
        // Rest period (2.5s, 3.0s, 4.0s) -> debounce closes event at 2.0s
        readingAt(t0.add(const Duration(milliseconds: 2500)), ip: 25.0, mcp: 10.0, av: 0.0, mm: 0.0),
        readingAt(t0.add(const Duration(seconds: 3)), ip: 25.0, mcp: 10.0, av: 0.0, mm: 0.0),
        readingAt(t0.add(const Duration(seconds: 4)), ip: 25.0, mcp: 10.0, av: 0.0, mm: 0.0),
        // Event 2 start (5.0s) -> flex delta = 10.0, mm = 0.4 (active)
        readingAt(t0.add(const Duration(seconds: 5)), ip: 35.0, mcp: 10.0, av: 10.0, mm: 0.4),
        // Event 2 continue (6.0s) -> active
        readingAt(t0.add(const Duration(seconds: 6)), ip: 45.0, mcp: 10.0, av: 10.0, mm: 0.4),
        // Event 2 end (7.0s) -> active
        readingAt(t0.add(const Duration(seconds: 7)), ip: 55.0, mcp: 10.0, av: 10.0, mm: 0.4),
        // Rest until 10s
        readingAt(t0.add(const Duration(milliseconds: 7500)), ip: 55.0, mcp: 10.0, av: 0.0, mm: 0.0),
        readingAt(t0.add(const Duration(seconds: 10)), ip: 55.0, mcp: 10.0, av: 0.0, mm: 0.0),
      ];

      final result = BiomechanicalAnalysisService.analyze(
        sessionId: 'movement-events',
        readings: readings,
        config: const BiomechanicalAnalysisConfig(
          ipAngleChangeDeg: 3.0,
          motionMagnitudeG: 0.15,
          minimumMovementDuration: Duration(milliseconds: 200),
          movementEndDebounce: Duration(milliseconds: 400),
        ),
      );

      expect(result.movementCount, 2);
      expect(result.movementIntervals.length, 2);
      expect(result.movementIntervals[0].duration, const Duration(seconds: 1));
      expect(result.movementIntervals[1].duration, const Duration(seconds: 2));
      expect(result.totalTimeMoving, const Duration(seconds: 3));
      expect(result.averageMovementDuration, const Duration(milliseconds: 1500));
      expect(result.percentageTimeMoving, closeTo(30.0, 0.1));
      expect(result.averageRestInterval, const Duration(seconds: 3));
      // 2 movements in 10s (0.1666 min) -> 12 movements per minute
      expect(result.movementsPerMinute, closeTo(12.0, 0.1));
    });
  });

  group('Edge Cases & Boundary Conditions', () {
    test('9. Empty readings list with null session returns safe empty analysis', () {
      final result = BiomechanicalAnalysisService.analyze(
        sessionId: 'empty-null',
        readings: const [],
      );

      expect(result.sampleCount, 0);
      expect(result.movementCount, 0);
      expect(result.averageForce, 0.0);
      expect(result.cumulativeForceExposure, 0.0);
      expect(result.movementsPerMinute, 0.0);
    });

    test('10. Empty readings list with existing MonitoringSession metadata preserves session summary values', () {
      final sess = createSession(
        id: 'sess-meta',
        start: t0,
        end: t0.add(const Duration(minutes: 2)),
        movementCount: 6,
        avgForce: 3.2,
        peakForce: 6.5,
        avgAngVel: 22.0,
      );

      final result = BiomechanicalAnalysisService.analyze(
        sessionId: 'sess-meta',
        session: sess,
        readings: const [],
      );

      expect(result.sampleCount, 0);
      expect(result.movementCount, 6);
      expect(result.movementsPerMinute, closeTo(3.0, 1e-5)); // 6 movements / 2 minutes = 3.0/min
      expect(result.averageForce, 3.2);
      expect(result.peakForce, 6.5);
      expect(result.averageAngularVelocity, 22.0);
      expect(result.cumulativeForceExposure, 0.0);
    });

    test('11. Single reading session yields 0 excursions, 0 cumulative exposures, and 0 deltas', () {
      final singleReading = [readingAt(t0, ip: 35.0, mcp: 20.0, force: 2.5, av: 12.0)];

      final result = BiomechanicalAnalysisService.analyze(
        sessionId: 'single-sample',
        readings: singleReading,
      );

      expect(result.sampleCount, 1);
      expect(result.ipAngleExcursion, 0.0);
      expect(result.mcpAngleExcursion, 0.0);
      expect(result.averageIpAngularChange, 0.0);
      expect(result.averageMcpAngularChange, 0.0);
      expect(result.cumulativeAbsoluteIpAngularChange, 0.0);
      expect(result.cumulativeAbsoluteMcpAngularChange, 0.0);
      expect(result.cumulativeForceExposure, 0.0);
      expect(result.cumulativeAngularVelocityExposure, 0.0);
      expect(result.averageForce, 2.5);
      expect(result.peakForce, 2.5);
      expect(result.averageAngularVelocity, 12.0);
      expect(result.peakAngularVelocity, 12.0);
      expect(result.percentageTimeMoving, 0.0);
    });

    test('12. Zero-duration session handles movements per minute without division by zero', () {
      final readings = [
        readingAt(t0, ip: 20.0),
        readingAt(t0, ip: 25.0),
      ];

      final result = BiomechanicalAnalysisService.analyze(
        sessionId: 'zero-duration',
        duration: Duration.zero,
        readings: readings,
      );

      expect(result.duration, Duration.zero);
      expect(result.movementsPerMinute, 0.0);
      expect(result.percentageTimeMoving, 0.0);
      expect(result.forceThresholdExceedancePercentage, 0.0);
    });
  });

  group('Repository Integration', () {
    test('13. BiomechanicalAnalysisService consumes data exclusively through MonitoringSessionRepository', () async {
      final repo = FakeMonitoringSessionRepository();
      final sess = createSession(
        id: 'repo-sess-1',
        start: t0,
        end: t0.add(const Duration(seconds: 30)),
        movementCount: 2,
      );
      final rList = [
        readingAt(t0, force: 1.0, av: 10.0),
        readingAt(t0.add(const Duration(seconds: 10)), force: 3.0, av: 20.0),
        readingAt(t0.add(const Duration(seconds: 20)), force: 2.0, av: 15.0),
      ];
      repo.addTestSession(sess, readings: rList);

      final service = BiomechanicalAnalysisService(repo);
      final analysis = await service.analyzeSession('repo-sess-1');

      expect(analysis.sessionId, 'repo-sess-1');
      expect(analysis.sampleCount, 3);
      expect(analysis.averageForce, 2.0);
      expect(analysis.peakForce, 3.0);
      expect(analysis.cumulativeForceExposure, isPositive);
    });

    test('14. analyzeAllSessions returns reports for all available sessions', () async {
      final repo = FakeMonitoringSessionRepository();
      repo.addTestSession(createSession(id: 's1', start: t0, end: t0.add(const Duration(seconds: 10))), readings: [readingAt(t0)]);
      repo.addTestSession(createSession(id: 's2', start: t0, end: t0.add(const Duration(seconds: 20))), readings: [readingAt(t0)]);

      final service = BiomechanicalAnalysisService(repo);
      final reports = await service.analyzeAllSessions();

      expect(reports.length, 2);
      expect(reports.map((r) => r.sessionId), containsAll(['s1', 's2']));
    });
  });
}
