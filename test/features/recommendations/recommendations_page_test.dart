import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thumb_biomech_monitor_glove/core/models/monitoring_session.dart';
import 'package:thumb_biomech_monitor_glove/core/models/sensor_reading.dart';
import 'package:thumb_biomech_monitor_glove/core/services/monitoring_session_repository.dart';
import 'package:thumb_biomech_monitor_glove/features/recommendations/presentation/recommendations_page.dart';

/// In-memory fake repository for deterministic recommendations widget testing.
class FakeMonitoringSessionRepository extends ChangeNotifier
    implements MonitoringSessionRepository {
  final List<MonitoringSession> _sessions = [];
  final Map<String, List<SensorReading>> _readings = {};

  void addTestSession(MonitoringSession session, {List<SensorReading>? readings}) {
    _sessions.add(session);
    if (readings != null) {
      _readings[session.id] = readings;
    }
    notifyListeners();
  }

  @override
  Future<void> saveSession(MonitoringSession session, {List<SensorReading>? readings}) async {
    _sessions.removeWhere((s) => s.id == session.id);
    _sessions.add(session);
    if (readings != null) {
      _readings[session.id] = readings;
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
    for (final s in _sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Future<void> deleteSession(String id) async {
    _sessions.removeWhere((s) => s.id == id);
    _readings.remove(id);
    notifyListeners();
  }

  @override
  Future<void> saveSensorReadings(String sessionId, List<SensorReading> readings) async {
    _readings[sessionId] = readings;
  }

  @override
  Future<List<SensorReading>> getSensorReadings(String sessionId) async {
    return _readings[sessionId] ?? const [];
  }
}

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: child,
  );
}

void main() {
  final t0 = DateTime.utc(2026, 9, 10, 10, 0, 0);

  SensorReading reading(int offsetSec, {
    double ip = 30.0,
    double mcp = 20.0,
    double force = 2.5,
    double av = 15.0,
    double mm = 0.4,
  }) =>
      SensorReading(
        timestamp: t0.add(Duration(seconds: offsetSec)),
        ipAngle: ip,
        mcpAngle: mcp,
        force: force,
        angularVelocity: av,
        motionMagnitude: mm,
      );

  MonitoringSession session({
    required String id,
    required DateTime start,
    required DateTime end,
    int movementCount = 5,
  }) =>
      MonitoringSession(
        id: id,
        startTime: start,
        endTime: end,
        movementCount: movementCount,
        averageIpAngle: 30.0,
        maximumIpAngle: 50.0,
        averageMcpAngle: 25.0,
        maximumMcpAngle: 40.0,
        averageForce: 2.0,
        peakForce: 4.0,
        averageAngularVelocity: 15.0,
        averageMotionMagnitude: 0.5,
      );

  group('RecommendationsPage Widget Tests', () {
    testWidgets('1. Shows clean empty state when repository has no sessions', (tester) async {
      final repo = FakeMonitoringSessionRepository();

      await tester.pumpWidget(createTestApp(RecommendationsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('No Recommendations Available'), findsOneWidget);
      expect(
        find.textContaining('Record a monitoring session on the Monitor tab'),
        findsOneWidget,
      );
    });

    testWidgets('2. Displays recommendations dashboard with disclaimer, count, and recommendation card', (tester) async {
      final repo = FakeMonitoringSessionRepository();
      final s = session(
        id: 'sess-1',
        start: t0,
        end: t0.add(const Duration(seconds: 60)),
        movementCount: 4,
      );
      // High force reading to trigger force recommendation
      final rList = [
        reading(0, ip: 20, force: 9.0),
        reading(30, ip: 40, force: 9.5),
        reading(60, ip: 20, force: 9.0),
      ];
      repo.addTestSession(s, readings: rList);

      await tester.pumpWidget(createTestApp(RecommendationsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Recommendations'), findsOneWidget);
      expect(find.text('RESEARCH RECOMMENDATIONS'), findsOneWidget);
      expect(find.textContaining('Available'), findsOneWidget);

      // Verify disclaimer banner is visible
      expect(
        find.textContaining('Research-oriented recommendations based on observed biomechanical telemetry'),
        findsOneWidget,
      );

      // Verify force recommendation card
      expect(find.text('Elevated Peak Contact Force Observed'), findsOneWidget);
      expect(find.text('Thumb Contact Force'), findsWidgets);
      expect(find.text('Elevated Priority'), findsWidgets);
      expect(find.textContaining('Peak force reached 9.5 N'), findsOneWidget);
    });

    testWidgets('3. Low exposure session renders baseline informational recommendation', (tester) async {
      final repo = FakeMonitoringSessionRepository();
      final s = session(
        id: 'sess-low',
        start: t0,
        end: t0.add(const Duration(seconds: 60)),
        movementCount: 1,
      );
      final rList = [
        reading(0, force: 1.0, av: 10),
        reading(60, force: 1.0, av: 10),
      ];
      repo.addTestSession(s, readings: rList);

      await tester.pumpWidget(createTestApp(RecommendationsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Baseline Biomechanical Loading Observed'), findsOneWidget);
      expect(find.text('Informational'), findsOneWidget);
      expect(find.text('Session Loading Structure'), findsOneWidget);
    });

    testWidgets('4. Session switching updates recommendations dynamically', (tester) async {
      final repo = FakeMonitoringSessionRepository();

      final sBaseline = session(
        id: 'sess-baseline',
        start: t0,
        end: t0.add(const Duration(seconds: 60)),
        movementCount: 1,
      );
      final rBaseline = [reading(0, force: 1.0), reading(60, force: 1.0)];

      final sHighForce = session(
        id: 'sess-high-force',
        start: t0.add(const Duration(hours: 1)),
        end: t0.add(const Duration(hours: 1, seconds: 60)),
        movementCount: 20,
      );
      final rHighForce = [reading(0, force: 9.0), reading(60, force: 9.0)];

      repo.addTestSession(sBaseline, readings: rBaseline);
      repo.addTestSession(sHighForce, readings: rHighForce);

      await tester.pumpWidget(createTestApp(RecommendationsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Defaults to sHighForce (newest)
      expect(find.text('Elevated Peak Contact Force Observed'), findsOneWidget);

      // Switch to sBaseline
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('1 mov').last);
      await tester.pumpAndSettle();

      expect(find.text('Baseline Biomechanical Loading Observed'), findsOneWidget);
    });

    testWidgets('5. Zero-reading session safely renders empty recommendations box', (tester) async {
      final repo = FakeMonitoringSessionRepository();
      final sEmpty = session(
        id: 'sess-empty',
        start: t0,
        end: t0.add(const Duration(seconds: 30)),
        movementCount: 0,
      );
      repo.addTestSession(sEmpty, readings: const []);

      await tester.pumpWidget(createTestApp(RecommendationsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('No research recommendations are available for this session yet.'),
        findsOneWidget,
      );
      expect(
        find.text('This session contains no recorded sensor samples or active movements.'),
        findsOneWidget,
      );
    });

    testWidgets('6. Research disclaimer is prominently rendered without prohibited clinical terms', (tester) async {
      final repo = FakeMonitoringSessionRepository();
      final s = session(id: 'sess-disc', start: t0, end: t0.add(const Duration(seconds: 30)));
      repo.addTestSession(s, readings: [reading(0), reading(30)]);

      await tester.pumpWidget(createTestApp(RecommendationsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check disclaimer
      expect(
        find.textContaining('Research-oriented recommendations based on observed biomechanical telemetry. These are not medical advice, diagnosis, or clinical recommendations.'),
        findsOneWidget,
      );

      // Ensure zero prohibited clinical terms
      expect(find.textContaining('injury risk'), findsNothing);
      expect(find.textContaining('RSI risk'), findsNothing);
      expect(find.textContaining('arthritis risk'), findsNothing);
      expect(find.textContaining('disease risk'), findsNothing);
      expect(find.textContaining('clinical stress'), findsNothing);
      expect(find.textContaining('medical risk'), findsNothing);
    });
  });
}
