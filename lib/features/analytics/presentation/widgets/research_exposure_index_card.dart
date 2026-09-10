import 'package:flutter/material.dart';

import '../../domain/models/research_exposure_index.dart';

/// Card widget presenting the composite [ResearchExposureIndex],
/// multi-dimensional component breakdown, loading contributor explainability,
/// prototype configuration transparency, and non-diagnostic research framing.
class ResearchExposureIndexCard extends StatelessWidget {
  const ResearchExposureIndexCard({
    required this.exposureIndex,
    super.key,
  });

  final ResearchExposureIndex exposureIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = exposureIndex.config;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header
            Row(
              children: [
                Icon(
                  Icons.assessment_outlined,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'RESEARCH EXPOSURE INDEX',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Composite biomechanical loading index & dimensional breakdown',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),

            // 2. Overall Score & Category Banner
            _OverallScoreBanner(index: exposureIndex),
            const SizedBox(height: 20),

            // 3. Dimensional Component Breakdown
            _SectionSubheader(
              title: 'Component Breakdown',
              icon: Icons.pie_chart_outline,
            ),
            const SizedBox(height: 12),
            _ComponentBarTile(
              label: 'Movement Exposure',
              score: exposureIndex.movementComponent,
              weightPct: config.effectiveMovementWeight * 100,
              accentColor: const Color(0xFF0284C7),
              description: 'Repetition rate and percentage of time moving',
            ),
            const SizedBox(height: 10),
            _ComponentBarTile(
              label: 'Joint Motion Exposure',
              score: exposureIndex.jointMotionComponent,
              weightPct: config.effectiveJointMotionWeight * 100,
              accentColor: const Color(0xFF7C3AED),
              description: 'IP & MCP joint excursion and angular change rate',
            ),
            const SizedBox(height: 10),
            _ComponentBarTile(
              label: 'Force Exposure',
              score: exposureIndex.forceComponent,
              weightPct: config.effectiveForceWeight * 100,
              accentColor: const Color(0xFFD97706),
              description: 'Average, peak contact force and threshold exceedance',
            ),
            const SizedBox(height: 10),
            _ComponentBarTile(
              label: 'Motion Intensity Exposure',
              score: exposureIndex.motionIntensityComponent,
              weightPct: config.effectiveMotionIntensityWeight * 100,
              accentColor: const Color(0xFFDC2626),
              description: 'Angular velocity magnitude and velocity threshold exceedance',
            ),
            const SizedBox(height: 18),

            // 4. Loading Contributor Explainability
            _SectionSubheader(
              title: 'Loading Contribution Breakdown',
              icon: Icons.lightbulb_outline,
            ),
            const SizedBox(height: 8),
            _ExplainabilityBox(index: exposureIndex),
            const SizedBox(height: 14),

            // 5. Expandable Configuration Transparency
            _ConfigurationDetailsTile(config: config),
            const SizedBox(height: 14),

            // 6. Non-Diagnostic Research Framing Disclaimer
            _IndexResearchDisclaimer(),
          ],
        ),
      ),
    );
  }
}

class _OverallScoreBanner extends StatelessWidget {
  const _OverallScoreBanner({required this.index});

  final ResearchExposureIndex index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = index.overallIndex;
    final (badgeColor, badgeBg, categoryLabel) = switch (index.category) {
      ResearchExposureCategory.low => (
          const Color(0xFF0F766E),
          const Color(0xFFCCFBF1),
          'Low Exposure',
        ),
      ResearchExposureCategory.moderate => (
          const Color(0xFFB45309),
          const Color(0xFFFEF3C7),
          'Moderate Exposure',
        ),
      ResearchExposureCategory.high => (
          const Color(0xFFBE123C),
          const Color(0xFFFFE4E6),
          'High Exposure',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Exposure Score',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          score.toStringAsFixed(1),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '/ 100',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      categoryLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (score / 100.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentBarTile extends StatelessWidget {
  const _ComponentBarTile({
    required this.label,
    required this.score,
    required this.weightPct,
    required this.accentColor,
    required this.description,
  });

  final String label;
  final double score;
  final double weightPct;
  final Color accentColor;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clampedScore = score.clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Weight: ${weightPct.toStringAsFixed(0)}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${clampedScore.toStringAsFixed(1)} / 100',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: clampedScore / 100.0,
              minHeight: 6,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplainabilityBox extends StatelessWidget {
  const _ExplainabilityBox({required this.index});

  final ResearchExposureIndex index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Identify the component with the highest score
    final components = [
      (label: 'Movement Exposure', score: index.movementComponent),
      (label: 'Joint Motion Exposure', score: index.jointMotionComponent),
      (label: 'Force Exposure', score: index.forceComponent),
      (label: 'Motion Intensity Exposure', score: index.motionIntensityComponent),
    ];
    components.sort((a, b) => b.score.compareTo(a.score));
    final highest = components.first;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.trending_up,
                size: 16,
                color: Color(0xFF475569),
              ),
              const SizedBox(width: 6),
              Text(
                highest.score > 0
                    ? 'Primary Contributor: ${highest.label} (${highest.score.toStringAsFixed(1)} / 100)'
                    : 'No active loading detected in this session',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            index.explanation,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF475569),
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigurationDetailsTile extends StatelessWidget {
  const _ConfigurationDetailsTile({required this.config});

  final ResearchExposureIndexConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: const Icon(Icons.tune_outlined, size: 18, color: Color(0xFF64748B)),
          title: Text(
            'Prototype Configuration & Reference Baselines',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
          children: [
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 10),
            _ConfigRow(label: 'Ref Movements / Min', value: '${config.refMovementsPerMinute.toStringAsFixed(0)} /min'),
            _ConfigRow(label: 'Ref IP Excursion', value: '${config.refIpExcursion.toStringAsFixed(0)}°'),
            _ConfigRow(label: 'Ref MCP Excursion', value: '${config.refMcpExcursion.toStringAsFixed(0)}°'),
            _ConfigRow(label: 'Ref Angular Change Rate', value: '${config.refAngularChangeRate.toStringAsFixed(0)}°/s'),
            _ConfigRow(label: 'Ref Average Force', value: '${config.refAverageForce.toStringAsFixed(1)} N'),
            _ConfigRow(label: 'Ref Peak Force', value: '${config.refPeakForce.toStringAsFixed(1)} N'),
            _ConfigRow(label: 'Ref Avg Angular Velocity', value: '${config.refAverageAngularVelocity.toStringAsFixed(0)}°/s'),
            _ConfigRow(label: 'Ref Peak Angular Velocity', value: '${config.refPeakAngularVelocity.toStringAsFixed(0)}°/s'),
            _ConfigRow(
              label: 'Category Boundaries',
              value: 'Low < ${config.moderateThreshold.toStringAsFixed(1)} | Mod ≤ ${config.highThreshold.toStringAsFixed(1)} | High > ${config.highThreshold.toStringAsFixed(1)}',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '• Reference values are configurable research-prototype parameters.\n'
                '• They are NOT clinical thresholds.\n'
                '• The index is NOT clinically validated.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF475569),
                  fontSize: 10.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
          ),
        ],
      ),
    );
  }
}

class _IndexResearchDisclaimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 16,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Research prototype exposure metric. This index is not a clinical risk prediction, '
              'diagnosis, or medical assessment and has not been clinically validated.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.amber.shade900,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionSubheader extends StatelessWidget {
  const _SectionSubheader({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
