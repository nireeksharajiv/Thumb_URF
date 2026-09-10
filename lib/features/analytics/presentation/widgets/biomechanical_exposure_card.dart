import 'package:flutter/material.dart';

import '../../domain/models/biomechanical_analysis.dart';

/// Card widget presenting deep biomechanical exposure, motion dynamics,
/// and repetition metrics derived by [BiomechanicalAnalysisService].
///
/// **Non-Diagnostic Notice**: Displays research telemetry only. Does NOT
/// diagnose RSI, clinical stress, or medical risk.
class BiomechanicalExposureCard extends StatelessWidget {
  const BiomechanicalExposureCard({
    required this.analysis,
    super.key,
  });

  final BiomechanicalAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Icon(
                  Icons.biotech_outlined,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'BIOMECHANICAL EXPOSURE',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Cumulative loading, kinematic transitions & threshold exceedance',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),

            // 1. MOVEMENT DYNAMICS
            _SubHeader(
              title: 'Movement & Repetition Exposure',
              icon: Icons.repeat_outlined,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ExposureTile(
                    label: 'Movement Count',
                    value: '${analysis.movementCount}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ExposureTile(
                    label: 'Movements/Min',
                    value: '${analysis.movementsPerMinute.toStringAsFixed(1)} /min',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ExposureTile(
                    label: 'Avg Movement Duration',
                    value: _formatDurationSec(analysis.averageMovementDuration),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ExposureTile(
                    label: 'Total Time Moving',
                    value: _formatDurationSec(analysis.totalTimeMoving),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ExposureTile(
                    label: 'Percentage Moving',
                    value: '${analysis.percentageTimeMoving.toStringAsFixed(1)}%',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ExposureTile(
                    label: 'Avg Rest Interval',
                    value: analysis.averageRestInterval > Duration.zero
                        ? _formatDurationSec(analysis.averageRestInterval)
                        : 'N/A',
                  ),
                ),
              ],
            ),
            const Divider(height: 28),

            // 2. JOINT MOTION & ANGULAR CHANGE
            _SubHeader(
              title: 'Joint Motion & Angular Change',
              icon: Icons.timeline_outlined,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ExposureTile(
                    label: 'IP Angle Excursion',
                    value: '${analysis.ipAngleExcursion.toStringAsFixed(1)}°',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ExposureTile(
                    label: 'MCP Angle Excursion',
                    value: '${analysis.mcpAngleExcursion.toStringAsFixed(1)}°',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ExposureTile(
                    label: 'Cumulative IP Δ',
                    value: '${analysis.cumulativeAbsoluteIpAngularChange.toStringAsFixed(1)}°',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ExposureTile(
                    label: 'Cumulative MCP Δ',
                    value: '${analysis.cumulativeAbsoluteMcpAngularChange.toStringAsFixed(1)}°',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ExposureTile(
                    label: 'Avg IP Δ / sample',
                    value: '${analysis.averageIpAngularChange.toStringAsFixed(2)}°',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ExposureTile(
                    label: 'Avg MCP Δ / sample',
                    value: '${analysis.averageMcpAngularChange.toStringAsFixed(2)}°',
                  ),
                ),
              ],
            ),
            const Divider(height: 28),

            // 3. FORCE EXPOSURE
            _SubHeader(
              title: 'Force Exposure & Threshold Exceedance',
              icon: Icons.compress_outlined,
              badge: 'Threshold: ≥ ${analysis.config.forceThreshold.toStringAsFixed(1)} N',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ExposureTile(
                    label: 'Average Force',
                    value: '${analysis.averageForce.toStringAsFixed(2)} N',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ExposureTile(
                    label: 'Peak Force',
                    value: '${analysis.peakForce.toStringAsFixed(2)} N',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ExposureTile(
              label: 'Cumulative Force Exposure (Integral)',
              value: '${analysis.cumulativeForceExposure.toStringAsFixed(2)} N·s',
              highlight: true,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ExposureTile(
                    label: 'Force Exceedance Time',
                    value: _formatDurationSec(analysis.forceThresholdExceedanceDuration),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ExposureTile(
                    label: 'Force Exceedance %',
                    value: '${analysis.forceThresholdExceedancePercentage.toStringAsFixed(1)}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ExposureTile(
              label: 'Force Sample Exceedance',
              value: '${analysis.forceSampleExceedancePercentage.toStringAsFixed(1)}% of samples',
            ),
            const Divider(height: 28),

            // 4. MOTION INTENSITY
            _SubHeader(
              title: 'Motion Intensity & Angular Velocity Exposure',
              icon: Icons.speed_outlined,
              badge: 'Threshold: ≥ ${analysis.config.angularVelocityThreshold.toStringAsFixed(1)} °/s',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ExposureTile(
                    label: 'Average Angular Velocity',
                    value: '${analysis.averageAngularVelocity.toStringAsFixed(1)} °/s',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ExposureTile(
                    label: 'Peak Angular Velocity',
                    value: '${analysis.peakAngularVelocity.toStringAsFixed(1)} °/s',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ExposureTile(
              label: 'Cumulative Angular Velocity Exposure (Integral)',
              value: '${analysis.cumulativeAngularVelocityExposure.toStringAsFixed(1)}°',
              highlight: true,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ExposureTile(
                    label: 'Motion Exceedance Time',
                    value: _formatDurationSec(analysis.angularVelocityThresholdExceedanceDuration),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ExposureTile(
                    label: 'Motion Exceedance %',
                    value: '${analysis.angularVelocityThresholdExceedancePercentage.toStringAsFixed(1)}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ExposureTile(
              label: 'Motion Sample Exceedance',
              value: '${analysis.angularVelocitySampleExceedancePercentage.toStringAsFixed(1)}% of samples',
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDurationSec(Duration d) {
    final ms = d.inMilliseconds;
    if (ms < 1000) {
      return '$ms ms';
    }
    return '${(ms / 1000.0).toStringAsFixed(2)} s';
  }
}

class _SubHeader extends StatelessWidget {
  const _SubHeader({
    required this.title,
    required this.icon,
    this.badge,
  });

  final String title;
  final IconData icon;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (badge != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ExposureTile extends StatelessWidget {
  const _ExposureTile({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: highlight
            ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: highlight ? theme.colorScheme.primary : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
