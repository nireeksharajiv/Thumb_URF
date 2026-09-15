import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thumb_biomech_monitor_glove/features/monitoring/presentation/live_monitoring_page.dart';

void main() {
  testWidgets('shows the live monitoring dashboard and controls', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LiveMonitoringPage()));

    // Verify static content visible in the upper portion of the page.
    expect(find.text('Live Monitoring'), findsOneWidget);
    expect(find.textContaining('NOT CONNECTED'), findsOneWidget);
    expect(find.text('IP JOINT ANGLE'), findsOneWidget);
    expect(find.text('MCP JOINT ANGLE'), findsOneWidget);
    expect(find.text('THUMB-TIP FORCE'), findsOneWidget);
    expect(find.text('MOTION'), findsOneWidget);

    // The button may be below the fold in the test viewport — scroll to it.
    final startFinder = find.text('Start Monitoring');
    expect(startFinder, findsOneWidget);
    await tester.ensureVisible(startFinder);
    await tester.pumpAndSettle();

    await tester.tap(startFinder);
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);

    final pauseFinder = find.text('Pause');
    await tester.ensureVisible(pauseFinder);
    await tester.pumpAndSettle();
    await tester.tap(pauseFinder);
    await tester.pump();
    expect(find.text('Resume'), findsOneWidget);

    final resumeFinder = find.text('Resume');
    await tester.ensureVisible(resumeFinder);
    await tester.pumpAndSettle();
    await tester.tap(resumeFinder);
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);

    final stopFinder = find.text('Stop');
    await tester.ensureVisible(stopFinder);
    await tester.pumpAndSettle();
    await tester.tap(stopFinder);
    await tester.pump();
    expect(find.text('Start Monitoring'), findsOneWidget);
  });
}

