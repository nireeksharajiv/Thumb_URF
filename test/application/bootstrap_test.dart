import 'package:flutter_test/flutter_test.dart';
import 'package:thumb_biomech_monitor_glove/application/bootstrap.dart';
import 'package:thumb_biomech_monitor_glove/application/thumb_biomech_app.dart';
import 'package:thumb_biomech_monitor_glove/core/services/supabase_service.dart';

void main() {
  testWidgets(
    'initApplicationServices and ThumbBiomechApp launch cleanly in unconfigured mode',
    (tester) async {
      final initialized = await initApplicationServices();
      expect(initialized, isFalse);
      expect(SupabaseService.instance.isInitialized, isFalse);

      // Launch with initialDemoMode: true so AppNavigationShell is shown
      // (no Supabase configured → AuthGate would otherwise show Login).
      await tester.pumpWidget(const ThumbBiomechApp(initialDemoMode: true));
      // Use pump+Duration instead of pumpAndSettle: HomePage._loadLatestSession
      // can trigger async SharedPreferences I/O that causes pumpAndSettle to timeout.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Home tab is the first landing page — brand heading is visible.
      expect(find.text('ThumbTrace'), findsWidgets);
      // Greeting row is shown.
      expect(find.textContaining('Hello,'), findsOneWidget);
    },
  );
}
