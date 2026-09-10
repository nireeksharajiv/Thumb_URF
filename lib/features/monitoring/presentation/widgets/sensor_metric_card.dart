import 'package:flutter/material.dart';

class SensorMetricCard extends StatelessWidget {
  const SensorMetricCard({
    required this.title,
    required this.location,
    required this.value,
    required this.unit,
    required this.progress,
    required this.icon,
    this.secondaryValue,
    super.key,
  });

  final String title;
  final String location;
  final String value;
  final String unit;
  final double progress;
  final IconData icon;
  final String? secondaryValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: theme.textTheme.labelLarge)),
              ],
            ),
            const SizedBox(height: 16),
            RichText(
              text: TextSpan(
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(text: value),
                  TextSpan(text: ' $unit', style: theme.textTheme.titleSmall),
                ],
              ),
            ),
            if (secondaryValue != null) ...[
              const SizedBox(height: 4),
              Text(secondaryValue!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress.clamp(0, 1).toDouble(),
              minHeight: 6,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 10),
            Text(location, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
