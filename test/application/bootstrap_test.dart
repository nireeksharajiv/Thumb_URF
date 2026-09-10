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

      await tester.pumpWidget(const ThumbBiomechApp());
      await tester.pumpAndSettle();

      expect(find.text('Research dashboard'), findsOneWidget);
      expect(find.text('Demo Mode'), findsOneWidget);
    },
  );
}
