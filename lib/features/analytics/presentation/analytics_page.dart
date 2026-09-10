import 'package:flutter/material.dart';

import '../../../core/widgets/feature_placeholder_page.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) => const FeaturePlaceholderPage(
    title: 'Analytics',
    description: 'Biomechanical monitoring analytics will be implemented in a later step.',
    icon: Icons.insights_outlined,
  );
}
