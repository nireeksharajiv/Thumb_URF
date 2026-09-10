import 'package:flutter/material.dart';

import '../../../core/widgets/feature_placeholder_page.dart';

class RecommendationsPage extends StatelessWidget {
  const RecommendationsPage({super.key});

  @override
  Widget build(BuildContext context) => const FeaturePlaceholderPage(
    title: 'Recommendations',
    description:
        'Preventive recommendations will be implemented in a later step.',
    icon: Icons.lightbulb_outline,
  );
}
