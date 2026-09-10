import 'package:flutter/material.dart';

import '../../domain/models/session_analytics.dart';

/// Card widget displaying high-level session overview metrics:
/// duration, sensor sample count, movement events, and movement rate.
class AnalyticsOverviewCard extends StatelessWidget {
  const AnalyticsOverviewCard({
    required this.analytics,
    super.key,
  });

  final SessionAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final dur = analytics.duration;
    final durLabel =
        '${dur.inMinutes.toString().padLeft(2, '0')}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}';
    final freqLabel = analytics.movementsPerMinute > 0
        ? '${analytics.movementsPerMinute.toStringAsFixed(1)} /min'
        : '0.0 /min';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'SESSION OVERVIEW',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _OverviewItem(
                    label: 'Duration',
                    value: durLabel,
                    icon: Icons.timer_outlined,
                  ),
                ),
                Expanded(
                  child: _OverviewItem(
                    label: 'Samples',
                    value: '${analytics.sampleCount}',
                    icon: Icons.scatter_plot_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _OverviewItem(
                    label: 'Movements',
                    value: '${analytics.movementCount}',
                    icon: Icons.touch_app_outlined,
                  ),
                ),
                Expanded(
                  child: _OverviewItem(
                    label: 'Rate',
                    value: freqLabel,
                    icon: Icons.speed_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewItem extends StatelessWidget {
  const _OverviewItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      );
}
