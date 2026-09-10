import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thumb_biomech_monitor_glove/application/thumb_biomech_app.dart';

void main() {
  testWidgets('shows the research dashboard in demo mode', (tester) async {
    await tester.pumpWidget(const ThumbBiomechApp());

    expect(find.text('Research dashboard'), findsOneWidget);
    expect(find.text('Demo Mode'), findsOneWidget);
    expect(
      find.text('Engineering research monitoring — not a diagnostic tool.'),
      findsOneWidget,
    );
  });

  testWidgets('reaches every application section', (tester) async {
    await tester.pumpWidget(const ThumbBiomechApp());

    await tester.tap(find.text('Monitor'));
    await tester.pump();
    expect(find.text('Live Monitoring'), findsOneWidget);

    await tester.tap(find.text('Device'));
    await tester.pump();
    expect(
      find.text('BLE device connection will be implemented in a later step.'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pump();
    await tester.tap(find.text('Sessions'));
    await tester.pump();
    expect(find.text('No completed sessions yet'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pump();
    await tester.tap(find.text('Analytics'));
    await tester.pump();
    expect(
      find.text(
        'Biomechanical monitoring analytics will be implemented in a later step.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pump();
    await tester.tap(find.text('Recommendations'));
    await tester.pump();
    expect(
      find.text(
        'Preventive recommendations will be implemented in a later step.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pump();
    await tester.tap(find.text('Settings'));
    await tester.pump();
    expect(find.text('Monitoring preferences'), findsOneWidget);
  });
}
