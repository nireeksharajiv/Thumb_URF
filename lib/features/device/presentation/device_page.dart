import 'package:flutter/material.dart';

import '../../../core/widgets/feature_placeholder_page.dart';

class DevicePage extends StatelessWidget {
  const DevicePage({super.key});

  @override
  Widget build(BuildContext context) => const FeaturePlaceholderPage(
    title: 'Device',
    description: 'BLE device connection will be implemented in a later step.',
    icon: Icons.sensors_outlined,
  );
}
