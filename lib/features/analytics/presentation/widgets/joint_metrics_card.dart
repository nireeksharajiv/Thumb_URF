import 'package:flutter/material.dart';

import '../../domain/models/session_analytics.dart';

/// Card widget displaying biomechanical joint metrics for IP and MCP joints:
/// Average, Minimum, Maximum, and Excursion (range).
class JointMetricsCard extends StatelessWidget {
  const JointMetricsCard({
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
                    Icons.pan_tool_alt_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'JOINT KINEMATICS',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // IP Joint Section
              _JointSection(
                title: 'IP Joint (Interphalangeal)',
                avg: analytics.averageIpAngle,
                min: analytics.minimumIpAngle,
                max: analytics.maximumIpAngle,
                excursion: analytics.ipAngleExcursion,
                accentColor: const Color(0xFF0B5D5E),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1),
              ),

              // MCP Joint Section
              _JointSection(
                title: 'MCP Joint (Metacarpophalangeal)',
                avg: analytics.averageMcpAngle,
                min: analytics.minimumMcpAngle,
                max: analytics.maximumMcpAngle,
                excursion: analytics.mcpAngleExcursion,
                accentColor: const Color(0xFF1E88E5),
              ),
            ],
          ),
        ),
      );
}

class _JointSection extends StatelessWidget {
  const _JointSection({
    required this.title,
    required this.avg,
    required this.min,
    required this.max,
    required this.excursion,
    required this.accentColor,
  });

  final String title;
  final double avg;
  final double min;
  final double max;
  final double excursion;
  final Color accentColor;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Average',
                  value: '${avg.toStringAsFixed(1)}°',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'Minimum',
                  value: '${min.toStringAsFixed(1)}°',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'Maximum',
                  value: '${max.toStringAsFixed(1)}°',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'Excursion',
                  value: '${excursion.toStringAsFixed(1)}°',
                  highlight: true,
                  highlightColor: accentColor,
                ),
              ),
            ],
          ),
        ],
      );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.highlight = false,
    this.highlightColor,
  });

  final String label;
  final String value;
  final bool highlight;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: highlight
              ? (highlightColor ?? Theme.of(context).colorScheme.primary).withAlpha(25)
              : Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(50),
          borderRadius: BorderRadius.circular(8),
          border: highlight
              ? Border.all(
                  color: (highlightColor ?? Theme.of(context).colorScheme.primary).withAlpha(100),
                  width: 1,
                )
              : null,
        ),
        child: Column(
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
            const SizedBox(height: 3),
            Text(
              value,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: highlight ? highlightColor : null,
                  ),
            ),
          ],
        ),
      );
}
