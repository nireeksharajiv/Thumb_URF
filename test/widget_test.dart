import 'package:flutter_test/flutter_test.dart';
import 'package:thumb_biomech_monitor_glove/application/thumb_biomech_app.dart';

void main() {
  /// Helper: pump the widget tree after creating it.
  ///
  /// Uses pump+Duration instead of pumpAndSettle to avoid timeouts caused by
  /// the async [HomePage._loadLatestSession] SharedPreferences I/O cycle.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('home page shows ThumbTrace brand and research quick-access', (tester) async {
    await tester.pumpWidget(const ThumbBiomechApp(initialDemoMode: true));
    await pumpApp(tester);

    // Brand heading visible on Home.
    expect(find.text('ThumbTrace'), findsWidgets);
    // Tagline visible.
    expect(find.text('Biomechanical Thumb Monitoring'), findsWidgets);
    // Greeting shown — plain Text widget contains 'Hello,'.
    expect(find.textContaining('Hello,'), findsOneWidget);
    // Research notice visible.
    expect(
      find.text(
        'Research prototype for biomechanical monitoring. Not a diagnostic tool.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('reaches every primary navigation section', (tester) async {
    await tester.pumpWidget(const ThumbBiomechApp(initialDemoMode: true));
    await pumpApp(tester);

    // ── Monitor ──────────────────────────────────────────────────────────────
    await tester.tap(find.text('Monitor'));
    await tester.pump();
    expect(find.text('Live Monitoring'), findsOneWidget);

    // ── Connect (previously "Device") ────────────────────────────────────────
    await tester.tap(find.text('Connect'));
    await tester.pump();
    expect(find.text('No device connected'), findsOneWidget);

    // ── Settings (now a primary tab, no longer buried in More) ───────────────
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Monitoring preferences'), findsOneWidget);

    // ── Home ─────────────────────────────────────────────────────────────────
    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Hello,'), findsOneWidget);
  });

  testWidgets('secondary research sections reachable via Home quick-access', (tester) async {
    await tester.pumpWidget(const ThumbBiomechApp(initialDemoMode: true));
    await pumpApp(tester);

    // The Research quick-access cards may be below the fold in the 800x600
    // test viewport, so scroll to them before tapping.
    final sessionsFinder = find.text('Sessions');
    await tester.ensureVisible(sessionsFinder);
    await tester.tap(sessionsFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('No completed sessions yet'), findsOneWidget);

    // Navigate back to Home, scroll to Analytics, tap.
    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final analyticsFinder = find.text('Analytics');
    await tester.ensureVisible(analyticsFinder);
    await tester.tap(analyticsFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('No Analytics Available'), findsOneWidget);

    // Navigate back to Home, scroll to Recommendations, tap.
    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final recsFinder = find.text('Recommendations');
    await tester.ensureVisible(recsFinder);
    await tester.tap(recsFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('No Recommendations Available'), findsOneWidget);
  });
}
