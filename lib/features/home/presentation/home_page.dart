import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/demo_mode_config.dart';
import '../../../core/widgets/app_section_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.appName,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Research dashboard',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thumb biomechanics monitoring workspace',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),
            AppSectionCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.science_outlined,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DemoModeConfig.isEnabled
                              ? 'Demo Mode'
                              : 'Device Mode',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        const Text('Foundation ready for research workflows.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('System scope', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  const Text(
                    'This app is designed to organize biomechanical monitoring, thumb loading, and repetitive movement research data.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(AppStrings.researchNotice, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
