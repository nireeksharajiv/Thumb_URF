import 'package:flutter/material.dart';

import '../../domain/models/session_analytics.dart';

/// Card widget displaying Thumb-Tip Force and Kinematic Motion metrics:
/// - Force: Average, Peak (N)
/// - Motion: Average/Peak Angular Velocity (°/s), Average/Peak Motion Magnitude.
class ForceMotionCard extends StatelessWidget {
  const ForceMotionCard({
    required this.analytics,
    super.key,
  });

  final SessionAnalytics analytics;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.fitness_center_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'FORCE & DYNAMICS',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Force Section
              Text(
                'Thumb-Tip Contact Force',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Tile(
                      label: 'Average Force',
                      value: '${analytics.averageForce.toStringAsFixed(2)} N',
                      icon: Icons.compress,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Tile(
                      label: 'Peak Force',
                      value: '${analytics.peakForce.toStringAsFixed(2)} N',
                      icon: Icons.vertical_align_top,
                      isPeak: true,
                    ),
                  ),
                ],
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1),
              ),

              // Motion Section
              Text(
                'Motion Dynamics & Velocity',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Tile(
                      label: 'Avg Angular Vel',
                      value: '${analytics.averageAngularVelocity.toStringAsFixed(1)} °/s',
                      icon: Icons.rotate_right,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Tile(
                      label: 'Peak Angular Vel',
                      value: '${analytics.peakAngularVelocity.toStringAsFixed(1)} °/s',
                      icon: Icons.speed,
                      isPeak: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Tile(
                      label: 'Avg Magnitude',
                      value: analytics.averageMotionMagnitude.toStringAsFixed(2),
                      icon: Icons.waves,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Tile(
                      label: 'Peak Magnitude',
                      value: analytics.peakMotionMagnitude.toStringAsFixed(2),
                      icon: Icons.trending_up,
                      isPeak: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.icon,
    this.isPeak = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isPeak;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isPeak
              ? Colors.amber.withAlpha(25)
              : Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(50),
          borderRadius: BorderRadius.circular(10),
          border: isPeak
              ? Border.all(
                  color: Colors.amber.shade700.withAlpha(120),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isPeak ? Colors.amber.shade900 : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
