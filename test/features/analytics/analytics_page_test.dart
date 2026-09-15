import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thumb_biomech_monitor_glove/application/app_navigation_shell.dart';
import 'package:thumb_biomech_monitor_glove/core/models/monitoring_session.dart';
import 'package:thumb_biomech_monitor_glove/core/models/sensor_reading.dart';
import 'package:thumb_biomech_monitor_glove/core/services/monitoring_session_repository.dart';
import 'package:thumb_biomech_monitor_glove/features/analytics/presentation/analytics_page.dart';
import 'package:thumb_biomech_monitor_glove/features/analytics/presentation/widgets/biomech_time_series_chart.dart';
import 'package:thumb_biomech_monitor_glove/features/analytics/presentation/widgets/biomechanical_exposure_card.dart';
import 'package:thumb_biomech_monitor_glove/features/analytics/presentation/widgets/research_exposure_index_card.dart';

/// In-memory fake repository for deterministic, fast UI widget testing.
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
    double avgIp = 35.0,
    double maxIp = 50.0,
    double avgMcp = 25.0,
    double maxMcp = 40.0,
    double avgForce = 2.0,
    double peakForce = 4.0,
    double avgAngVel = 15.0,
    double avgMotionMag = 0.5,
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

  Widget createTestApp(Widget child) => MaterialApp(
        home: child,
      );

  group('AnalyticsPage Widget Tests', () {
    testWidgets('1. Shows clean empty state when repository has no sessions', (tester) async {
      final repo = FakeMonitoringSessionRepository();

      await tester.pumpWidget(createTestApp(AnalyticsPage(repository: repo)));
      await tester.pump();

      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('No Analytics Available'), findsOneWidget);
      expect(
        find.textContaining('Record a biomechanical monitoring session on the Monitor tab'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.insights_outlined), findsOneWidget);
      expect(find.text('SESSION OVERVIEW'), findsNothing);
    });

    testWidgets('2. Displays overview, joint kinematics, force/motion, and research disclaimer for recorded session', (tester) async {
      final repo = FakeMonitoringSessionRepository();
      final s1 = session(
        id: 'sess-alpha',
        start: t0,
        end: t0.add(const Duration(seconds: 120)), // 2 minutes
        movementCount: 8,
      );
      final rList = [
        reading(0, ip: 20, mcp: 10, force: 1.0, av: 10, mm: 0.2),
        reading(60, ip: 40, mcp: 30, force: 3.0, av: 20, mm: 0.6),
        reading(120, ip: 60, mcp: 20, force: 5.0, av: 30, mm: 0.4),
      ];
      repo.addTestSession(s1, readings: rList);

      await tester.pumpWidget(createTestApp(AnalyticsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Page Title
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Biomechanical research telemetry & kinematics'), findsOneWidget);

      // Section Cards
      expect(find.text('SESSION OVERVIEW'), findsOneWidget);
      expect(find.text('JOINT KINEMATICS'), findsOneWidget);
      expect(find.text('FORCE & DYNAMICS'), findsOneWidget);
      expect(find.text('BIOMECHANICAL EXPOSURE'), findsOneWidget);
      expect(find.byType(BiomechanicalExposureCard), findsOneWidget);
      expect(find.text('TELEMETRY TIME-SERIES'), findsOneWidget);

      // Session Overview values
      expect(find.text('02:00'), findsOneWidget); // Duration
      expect(find.text('3'), findsOneWidget); // Samples count
      expect(find.text('8'), findsOneWidget); // Movements
      expect(find.text('4.0 /min'), findsOneWidget); // Rate: 8 / 2 min = 4.0/min

      // Joint Kinematics values
      expect(find.text('IP Joint (Interphalangeal)'), findsOneWidget);
      expect(find.text('40.0°'), findsWidgets); // IP Avg (40.0) and IP Excursion (60-20=40.0)
      expect(find.text('20.0°'), findsWidgets); // IP Min (20) and MCP Excursion (30-10=20)
      expect(find.text('60.0°'), findsOneWidget); // IP Max (60)
      expect(find.text('MCP Joint (Metacarpophalangeal)'), findsOneWidget);
      expect(find.text('10.0°'), findsOneWidget); // MCP Min (10)
      expect(find.text('30.0°'), findsWidgets); // MCP Max (30)

      // Force & Dynamics values
      expect(find.text('3.00 N'), findsWidgets); // Force Avg: (1+3+5)/3 = 3.0
      expect(find.text('5.00 N'), findsWidgets); // Force Peak: 5.0
      expect(find.text('20.0 °/s'), findsWidgets); // Avg Ang Vel: (10+20+30)/3 = 20.0
      expect(find.text('30.0 °/s'), findsWidgets); // Peak Ang Vel: 30.0
      expect(find.text('0.40'), findsOneWidget); // Avg Magnitude: (0.2+0.6+0.4)/3 = 0.4
      expect(find.text('0.60'), findsOneWidget); // Peak Magnitude: 0.6

      // Research Disclaimer
      expect(find.textContaining('Research Prototype:'), findsOneWidget);
      expect(find.textContaining('does not provide medical diagnoses'), findsOneWidget);
    });

    testWidgets('3. Session selector dropdown allows switching between sessions', (tester) async {
      final repo = FakeMonitoringSessionRepository();
      final sOld = session(
        id: 'sess-old',
        start: t0,
        end: t0.add(const Duration(seconds: 60)),
        movementCount: 4,
      );
      final rOld = [reading(0, ip: 25, mcp: 15, force: 1.5, av: 10, mm: 0.2)];

      final sNew = session(
        id: 'sess-new',
        start: t0.add(const Duration(hours: 1)),
        end: t0.add(const Duration(hours: 1, seconds: 60)),
        movementCount: 15,
      );
      final rNew = [reading(0, ip: 55, mcp: 35, force: 4.5, av: 25, mm: 0.8)];

      repo.addTestSession(sOld, readings: rOld);
      repo.addTestSession(sNew, readings: rNew);

      await tester.pumpWidget(createTestApp(AnalyticsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Defaults to newest first ('sess-new')
      expect(find.text('15'), findsWidgets); // Movement count of new session
      expect(find.text('55.0°'), findsWidgets); // IP angle of new session

      // Open Dropdown
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      // Tap the older session
      final dropdownItem = find.textContaining('4 mov').last;
      await tester.tap(dropdownItem);
      await tester.pumpAndSettle();

      // Verified switched to older session
      expect(find.text('4'), findsWidgets); // Movement count of old session
      expect(find.text('25.0°'), findsWidgets); // IP angle of old session
    });

    testWidgets('4. Time-series chart renders canvas and channel selection chips', (tester) async {
      final repo = FakeMonitoringSessionRepository();
      final s = session(id: 'sess-chart', start: t0, end: t0.add(const Duration(seconds: 60)));
      final rList = [
        reading(0, ip: 30, mcp: 20, force: 2.0, av: 10, mm: 0.3),
        reading(30, ip: 45, mcp: 25, force: 3.5, av: 15, mm: 0.5),
      ];
      repo.addTestSession(s, readings: rList);

      await tester.pumpWidget(createTestApp(AnalyticsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check chart container & channel chips
      expect(find.byType(BiomechTimeSeriesChart), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('IP Angle (°)'), findsOneWidget);
      expect(find.text('MCP Angle (°)'), findsOneWidget);
      expect(find.text('Contact Force (N)'), findsOneWidget);
      expect(find.text('Angular Velocity (°/s)'), findsOneWidget);
      expect(find.text('Motion Magnitude (g)'), findsOneWidget);

      // Tap other chips to ensure active channel switching works without error
      await tester.ensureVisible(find.text('MCP Angle (°)'));
      await tester.tap(find.text('MCP Angle (°)'));
      await tester.pump();

      await tester.ensureVisible(find.text('Contact Force (N)'));
      await tester.tap(find.text('Contact Force (N)'));
      await tester.pump();

      await tester.ensureVisible(find.text('Angular Velocity (°/s)'));
      await tester.tap(find.text('Angular Velocity (°/s)'));
      await tester.pump();

      await tester.ensureVisible(find.text('Motion Magnitude (g)'));
      await tester.tap(find.text('Motion Magnitude (g)'));
      await tester.pump();

      expect(find.byType(BiomechTimeSeriesChart), findsOneWidget);
    });

    testWidgets('5. Handles single-reading session safely with excursion 0 and chart dot', (tester) async {
      final repo = FakeMonitoringSessionRepository();
      final s = session(id: 'sess-single', start: t0, end: t0.add(const Duration(seconds: 10)), movementCount: 1);
      final rList = [reading(0, ip: 37.5, mcp: 22.0, force: 1.8, av: 8.0, mm: 0.25)];
      repo.addTestSession(s, readings: rList);

      await tester.pumpWidget(createTestApp(AnalyticsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('37.5°'), findsWidgets); // Avg, min, max are identical
      expect(find.text('0.0°'), findsWidgets); // Excursion is 0
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('6. Handles empty readings in existing session summary', (tester) async {
      final repo = FakeMonitoringSessionRepository();
      final s = session(
        id: 'sess-empty-r',
        start: t0,
        end: t0.add(const Duration(seconds: 30)),
        movementCount: 0,
        avgIp: 28.0,
        maxIp: 28.0,
      );
      repo.addTestSession(s, readings: const []);

      await tester.pumpWidget(createTestApp(AnalyticsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Chart displays empty indicator
      expect(find.text('No sensor samples recorded for this session'), findsOneWidget);
      // Falls back to session summary metadata
      expect(find.text('28.0°'), findsWidgets);
    });

    testWidgets('7. Navigation to and from Analytics in AppNavigationShell', (tester) async {
      final repo = FakeMonitoringSessionRepository();
      final s = session(id: 'nav-sess', start: t0, end: t0.add(const Duration(minutes: 1)), movementCount: 3);
      repo.addTestSession(s, readings: [reading(0)]);

      await tester.pumpWidget(createTestApp(AppNavigationShell(repository: repo)));
      // Use pump+Duration instead of pumpAndSettle: FakeMonitoringSessionRepository
      // completes asynchronously, keeping the engine unsettled.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Starts on Home — greeting is visible.
      expect(find.textContaining('Hello,'), findsOneWidget);

      // Navigate to Analytics via the Home quick-access card.
      // Use ensureVisible: the card may be below the fold in the 800x600 test viewport.
      final analyticsFinder = find.text('Analytics');
      await tester.ensureVisible(analyticsFinder);
      await tester.tap(analyticsFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verifies Analytics dashboard is reached.
      expect(find.text('Biomechanical research telemetry & kinematics'), findsOneWidget);
      expect(find.text('SESSION OVERVIEW'), findsOneWidget);
    });

    testWidgets('8. BiomechanicalExposureCard renders movement, joint motion, force, and motion intensity metrics with units and thresholds', (tester) async {
      final repo = FakeMonitoringSessionRepository();
      final s = session(id: 'sess-bio', start: t0, end: t0.add(const Duration(seconds: 120)), movementCount: 4);
      final rList = [
        reading(0, ip: 20, mcp: 10, force: 1.0, av: 10, mm: 0.1),
        reading(60, ip: 40, mcp: 25, force: 3.0, av: 40, mm: 0.5),
        reading(120, ip: 50, mcp: 15, force: 2.0, av: 20, mm: 0.2),
      ];
      repo.addTestSession(s, readings: rList);

      await tester.pumpWidget(createTestApp(AnalyticsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(BiomechanicalExposureCard), findsOneWidget);
      expect(find.text('BIOMECHANICAL EXPOSURE'), findsOneWidget);

      // Section Subheaders
      expect(find.text('Movement & Repetition Exposure'), findsOneWidget);
      expect(find.text('Joint Motion & Angular Change'), findsOneWidget);
      expect(find.text('Force Exposure & Threshold Exceedance'), findsOneWidget);
      expect(find.text('Motion Intensity & Angular Velocity Exposure'), findsOneWidget);

      // Threshold badges
      expect(find.text('Threshold: ≥ 2.0 N'), findsOneWidget);
      expect(find.text('Threshold: ≥ 30.0 °/s'), findsOneWidget);

      // Exposure integrals and units
      expect(find.text('Cumulative Force Exposure (Integral)'), findsOneWidget);
      expect(find.text('Cumulative Angular Velocity Exposure (Integral)'), findsOneWidget);

      // Ensure visible and check tiles
      await tester.ensureVisible(find.text('Cumulative Force Exposure (Integral)'));
      expect(find.textContaining('N·s'), findsWidgets);

      await tester.ensureVisible(find.text('Cumulative Angular Velocity Exposure (Integral)'));
      expect(find.text('Motion Exceedance Time'), findsOneWidget);
      expect(find.text('Motion Exceedance %'), findsOneWidget);
    });

    testWidgets('9. Biomechanical exposure metrics update dynamically on session switching', (tester) async {
      final repo = FakeMonitoringSessionRepository();
      final sA = session(id: 'sess-A', start: t0, end: t0.add(const Duration(seconds: 60)), movementCount: 2);
      final rA = [reading(0, ip: 20, force: 1.5), reading(60, ip: 30, force: 1.5)];

      final sB = session(id: 'sess-B', start: t0.add(const Duration(hours: 2)), end: t0.add(const Duration(hours: 2, seconds: 60)), movementCount: 9);
      final rB = [reading(0, ip: 60, force: 4.5), reading(60, ip: 80, force: 4.5)];

      repo.addTestSession(sA, readings: rA);
      repo.addTestSession(sB, readings: rB);

      await tester.pumpWidget(createTestApp(AnalyticsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Defaults to sB (newest)
      expect(find.text('4.50 N'), findsWidgets);

      // Switch to sA
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('2 mov').last);
      await tester.pumpAndSettle();

      expect(find.text('1.50 N'), findsWidgets);
    });

    testWidgets('10. Handles zero-reading session gracefully in BiomechanicalExposureCard', (tester) async {
      final repo = FakeMonitoringSessionRepository();
      final sEmpty = session(
        id: 'sess-zero-readings',
        start: t0,
        end: t0.add(const Duration(seconds: 45)),
        movementCount: 0,
        avgForce: 1.2,
        peakForce: 2.4,
      );
      repo.addTestSession(sEmpty, readings: const []);

      await tester.pumpWidget(createTestApp(AnalyticsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(BiomechanicalExposureCard), findsOneWidget);
      expect(find.text('BIOMECHANICAL EXPOSURE'), findsOneWidget);
      expect(find.text('0.00 N·s'), findsOneWidget);
      expect(find.text('1.20 N'), findsWidgets); // Average force fallback from session metadata
    });

    testWidgets('11. ResearchExposureIndexCard renders with overall score, category, and components', (tester) async {
      final repo = FakeMonitoringSessionRepository();
      final s = session(
        id: 'sess-exposure-1',
        start: t0,
        end: t0.add(const Duration(seconds: 60)),
        movementCount: 4,
      );
      final rList = [
        reading(0, ip: 20, mcp: 15, force: 2.0, av: 20.0),
        reading(30, ip: 50, mcp: 35, force: 3.0, av: 40.0),
        reading(60, ip: 20, mcp: 15, force: 2.0, av: 20.0),
      ];
      repo.addTestSession(s, readings: rList);

      await tester.pumpWidget(createTestApp(AnalyticsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify card presence
      expect(find.byType(ResearchExposureIndexCard), findsOneWidget);
      expect(find.text('RESEARCH EXPOSURE INDEX'), findsOneWidget);
      expect(find.text('Overall Exposure Score'), findsOneWidget);
      expect(find.text('/ 100'), findsWidgets);

      // 2. Component breakdown subheader & 4 dimensions
      await tester.ensureVisible(find.text('Component Breakdown'));
      expect(find.text('Movement Exposure'), findsOneWidget);
      expect(find.text('Joint Motion Exposure'), findsOneWidget);
      expect(find.text('Force Exposure'), findsOneWidget);
      expect(find.text('Motion Intensity Exposure'), findsOneWidget);

      // 3. Contribution breakdown & explainability
      await tester.ensureVisible(find.text('Loading Contribution Breakdown'));
      expect(find.text('Loading Contribution Breakdown'), findsOneWidget);
      expect(find.textContaining('Primary Contributor:'), findsOneWidget);
    });

    testWidgets('12. High exposure session correctly displays High Exposure category badge', (tester) async {
      final repo = FakeMonitoringSessionRepository();
      final s = session(
        id: 'sess-high-exposure',
        start: t0,
        end: t0.add(const Duration(seconds: 60)),
        movementCount: 50,
      );
      // High forces and high velocities to trigger high exposure
      final rList = [
        reading(0, ip: 10, mcp: 10, force: 9.0, av: 180.0),
        reading(30, ip: 90, mcp: 80, force: 9.5, av: 200.0),
        reading(60, ip: 10, mcp: 10, force: 9.0, av: 180.0),
      ];
      repo.addTestSession(s, readings: rList);

      await tester.pumpWidget(createTestApp(AnalyticsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('High Exposure'), findsOneWidget);
    });

    testWidgets('13. Expandable configuration tile displays prototype reference baselines and non-clinical notice', (tester) async {
      final repo = FakeMonitoringSessionRepository();
      final s = session(id: 'sess-config', start: t0, end: t0.add(const Duration(seconds: 30)));
      repo.addTestSession(s, readings: [reading(0), reading(30)]);

      await tester.pumpWidget(createTestApp(AnalyticsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final configTile = find.text('Prototype Configuration & Reference Baselines');
      await tester.ensureVisible(configTile);
      expect(configTile, findsOneWidget);

      // Tap to expand
      await tester.tap(configTile);
      await tester.pumpAndSettle();

      expect(find.text('Ref Movements / Min'), findsOneWidget);
      expect(find.text('Ref Average Force'), findsOneWidget);
      expect(find.text('Category Boundaries'), findsOneWidget);
      expect(find.textContaining('Reference values are configurable research-prototype parameters'), findsOneWidget);
      expect(find.textContaining('They are NOT clinical thresholds'), findsOneWidget);
    });

    testWidgets('14. Session selector dynamically updates ResearchExposureIndex', (tester) async {
      final repo = FakeMonitoringSessionRepository();
      final sLow = session(id: 'sess-low', start: t0, end: t0.add(const Duration(seconds: 60)), movementCount: 1);
      final rLow = [reading(0, force: 0.5, av: 5), reading(60, force: 0.5, av: 5)];

      final sHigh = session(
        id: 'sess-high',
        start: t0.add(const Duration(hours: 1)),
        end: t0.add(const Duration(hours: 1, seconds: 60)),
        movementCount: 40,
      );
      final rHigh = [
        reading(0, ip: 10, mcp: 10, force: 9.0, av: 180),
        reading(30, ip: 90, mcp: 80, force: 9.5, av: 200),
        reading(60, ip: 10, mcp: 10, force: 9.0, av: 180),
      ];

      repo.addTestSession(sLow, readings: rLow);
      repo.addTestSession(sHigh, readings: rHigh);

      await tester.pumpWidget(createTestApp(AnalyticsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Defaults to sHigh (most recent)
      expect(find.byType(ResearchExposureIndexCard), findsOneWidget);
      expect(find.text('High Exposure'), findsOneWidget);

      // Switch to sLow
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('1 mov').last);
      await tester.pumpAndSettle();

      expect(find.text('Low Exposure'), findsOneWidget);
    });

    testWidgets('15. Zero-reading session safely displays 0.0 index and Low Exposure in ResearchExposureIndexCard', (tester) async {
      final repo = FakeMonitoringSessionRepository();
      final sEmpty = session(
        id: 'sess-zero-readings',
        start: t0,
        end: t0.add(const Duration(seconds: 30)),
        movementCount: 0,
      );
      repo.addTestSession(sEmpty, readings: const []);

      await tester.pumpWidget(createTestApp(AnalyticsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ResearchExposureIndexCard), findsOneWidget);
      expect(find.text('Low Exposure'), findsOneWidget);
      expect(find.text('0.0 / 100'), findsWidgets);
    });

    testWidgets('16. Research prototype disclaimer is prominently rendered with non-diagnostic framing', (tester) async {
      final repo = FakeMonitoringSessionRepository();
      final s = session(id: 'sess-disclaimer', start: t0, end: t0.add(const Duration(seconds: 30)));
      repo.addTestSession(s, readings: [reading(0), reading(30)]);

      await tester.pumpWidget(createTestApp(AnalyticsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check the card's research disclaimer
      await tester.ensureVisible(find.textContaining('Research prototype exposure metric. This index is not a clinical risk prediction'));
      expect(find.textContaining('Research prototype exposure metric. This index is not a clinical risk prediction, diagnosis, or medical assessment and has not been clinically validated.'), findsOneWidget);

      // Prohibited terminology check
      expect(find.textContaining('injury risk'), findsNothing);
      expect(find.textContaining('RSI risk'), findsNothing);
      expect(find.textContaining('arthritis risk'), findsNothing);
      expect(find.textContaining('disease risk'), findsNothing);
      expect(find.textContaining('clinical stress'), findsNothing);
      expect(find.textContaining('medical risk'), findsNothing);
    });
  });
}
