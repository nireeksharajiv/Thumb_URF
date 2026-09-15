import 'package:flutter/material.dart';

/// Connect page — the primary destination for wearable device pairing.
///
/// Shows current connection state (no device connected) and a Scan CTA.
/// BLE scanning will be implemented when hardware integration is added.
class DevicePage extends StatelessWidget {
  const DevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Text(
              'Connect',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ThumbTrace Glove',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),

            // ── Connection status card ────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.watch_outlined,
                            size: 26,
                            color: cs.onSurface.withAlpha(140),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ThumbTrace Glove',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: cs.onSurface.withAlpha(100),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    'No device connected',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: cs.onSurface.withAlpha(160),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Turn on your ThumbTrace glove and make sure Bluetooth is enabled.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface.withAlpha(180),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('connect_scan_button'),
                        onPressed: () => _showScanUnavailable(context),
                        icon: const Icon(Icons.bluetooth_searching_outlined),
                        label: const Text('Scan for devices'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Future sensors section ────────────────────────────────────────
            Text(
              'ThumbTrace Sensor Suite',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withAlpha(160),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 12),
            _SensorRow(
              theme: theme,
              icon: Icons.rotate_90_degrees_cw_outlined,
              name: 'MPU-6050 IMU',
              description: 'Angular velocity & motion magnitude',
            ),
            _SensorRow(
              theme: theme,
              icon: Icons.straighten_outlined,
              name: 'IP Flex Sensor',
              description: 'Interphalangeal joint angle',
            ),
            _SensorRow(
              theme: theme,
              icon: Icons.straighten_outlined,
              name: 'MCP Flex Sensor',
              description: 'Metacarpophalangeal joint angle',
            ),
            _SensorRow(
              theme: theme,
              icon: Icons.touch_app_outlined,
              name: 'Thumb-tip FSR',
              description: 'Distal phalanx contact force',
            ),

            const SizedBox(height: 24),

            // ── Connection technology notice ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withAlpha(120),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withAlpha(60)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bluetooth_outlined,
                    size: 16,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Connects via Bluetooth Low Energy (BLE) through the ESP32 microcontroller.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withAlpha(160),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showScanUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Bluetooth scanning is available once your ThumbTrace glove is powered on.',
        ),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _SensorRow extends StatelessWidget {
  const _SensorRow({
    required this.theme,
    required this.icon,
    required this.name,
    required this.description,
  });
  final ThemeData theme;
  final IconData icon;
  final String name;
  final String description;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withAlpha(140),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
