import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thumb_biomech_monitor_glove/core/models/monitoring_session.dart';
import 'package:thumb_biomech_monitor_glove/core/services/session_repository.dart';
import 'package:thumb_biomech_monitor_glove/features/sessions/presentation/sessions_page.dart';

// ---------------------------------------------------------------------------
// Helper — build a minimal valid MonitoringSession.
// ---------------------------------------------------------------------------

MonitoringSession _session({
  String id = 'test-001',
  int movementCount = 5,
  double avgIp = 25.0,
  double maxIp = 40.0,
  double avgMcp = 15.0,
  double maxMcp = 25.0,
  double avgForce = 2.0,
  double peakForce = 4.0,
}) => MonitoringSession(
  id: id,
  startTime: DateTime.utc(2026, 9, 10, 10, 0),
  endTime: DateTime.utc(2026, 9, 10, 10, 5), // 5-minute session
  movementCount: movementCount,
  averageIpAngle: avgIp,
  maximumIpAngle: maxIp,
  averageMcpAngle: avgMcp,
  maximumMcpAngle: maxMcp,
  averageForce: avgForce,
  peakForce: peakForce,
  averageAngularVelocity: 8.0,
  averageMotionMagnitude: 0.4,
);

Widget _wrap(Widget child) => MaterialApp(home: child);

// ---------------------------------------------------------------------------

void main() {
  // ── Test 12a ──────────────────────────────────────────────────────────────

  testWidgets('12a. Shows empty state when repository has no sessions', (
    tester,
  ) async {
    final repo = SessionRepository();
    await tester.pumpWidget(_wrap(SessionsPage(repository: repo)));

    expect(find.text('No completed sessions yet'), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    // No session cards.
    expect(find.text('Completed session'), findsNothing);

    repo.dispose();
  });

  // ── Test 12b ──────────────────────────────────────────────────────────────

  testWidgets('12b. Shows session card after a session is added', (
    tester,
  ) async {
    final repo = SessionRepository();
    await tester.pumpWidget(_wrap(SessionsPage(repository: repo)));

    // Initially empty.
    expect(find.text('No completed sessions yet'), findsOneWidget);

    // Add a session — repository notifies listeners → page rebuilds.
    repo.add(_session(movementCount: 8));
    await tester.pump();

    // Empty state gone.
    expect(find.text('No completed sessions yet'), findsNothing);

    // Session card present.
    expect(find.text('Completed session'), findsOneWidget);
    expect(find.text('8'), findsOneWidget); // movement count
    expect(find.text('Sessions'), findsOneWidget); // page heading

    repo.dispose();
  });

  // ── Test 12c ──────────────────────────────────────────────────────────────

  testWidgets(
    '12c. Shows null-repository empty state (no repository provided)',
    (tester) async {
      await tester.pumpWidget(_wrap(const SessionsPage()));
      expect(find.text('No completed sessions yet'), findsOneWidget);
    },
  );

  // ── Test 12d ──────────────────────────────────────────────────────────────

  testWidgets('12d. Multiple sessions shown newest first', (tester) async {
    final repo = SessionRepository();
    // Add two sessions — page should display newest (added last) at top.
    repo.add(_session(id: 'old', avgIp: 20.0, peakForce: 2.0));
    repo.add(_session(id: 'new', avgIp: 40.0, peakForce: 6.0));

    await tester.pumpWidget(_wrap(SessionsPage(repository: repo)));

    // Both cards present.
    expect(find.text('Completed session'), findsNWidgets(2));

    // Subtitle shows record count.
    expect(find.textContaining('2 records'), findsOneWidget);

    repo.dispose();
  });
}
