import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../services/ble/ble_sensor_service.dart';

/// Connect page — the primary destination for wearable device pairing.
///
/// Shows current connection state and a Scan CTA.
/// Implements real BLE scanning to discover and connect to the ESP32.
class DevicePage extends StatefulWidget {
  const DevicePage({required this.bleService, super.key});

  final BleSensorService bleService;

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  StreamSubscription<BleConnectionState>? _stateSub;
  StreamSubscription<String>? _dataSub;

  BleConnectionState _connectionState = BleConnectionState.disconnected;
  String _latestData = '';

  @override
  void initState() {
    super.initState();
    _connectionState = widget.bleService.state;
    
    _stateSub = widget.bleService.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _connectionState = state;
        });
      }
    });

    _dataSub = widget.bleService.incomingData.listen((data) {
      if (mounted) {
        setState(() {
          _latestData = data;
        });
      }
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _dataSub?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissionsAndScan() async {
    // Request Bluetooth permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothScan]?.isDenied ?? false) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth scan permission is required to find the glove.')),
      );
      return;
    }

    try {
      await widget.bleService.connect();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect: $e')),
      );
    }
  }

  Future<void> _disconnect() async {
    await widget.bleService.disconnect();
  }

  String _getConnectionStatusText() {
    switch (_connectionState) {
      case BleConnectionState.disconnected:
        return 'No device connected';
      case BleConnectionState.scanning:
        return 'Scanning for ThumbTrace Glove...';
      case BleConnectionState.connecting:
        return 'Connecting...';
      case BleConnectionState.connected:
        return 'Connected';
      case BleConnectionState.disconnecting:
        return 'Disconnecting...';
    }
  }

  Color _getConnectionStatusColor(ColorScheme cs) {
    switch (_connectionState) {
      case BleConnectionState.connected:
        return Colors.green;
      case BleConnectionState.scanning:
      case BleConnectionState.connecting:
        return Colors.orange;
      case BleConnectionState.disconnected:
      case BleConnectionState.disconnecting:
        return cs.onSurface.withAlpha(100);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bool isConnected = _connectionState == BleConnectionState.connected;
    final bool isBusy = _connectionState == BleConnectionState.scanning || 
                        _connectionState == BleConnectionState.connecting ||
                        _connectionState == BleConnectionState.disconnecting;

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
                            isConnected ? Icons.bluetooth_connected : Icons.watch_outlined,
                            size: 26,
                            color: isConnected ? Colors.green : cs.onSurface.withAlpha(140),
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
                                      color: _getConnectionStatusColor(cs),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      _getConnectionStatusText(),
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: cs.onSurface.withAlpha(160),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    if (isConnected && _latestData.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer.withAlpha(80),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Test Data: $_latestData',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: cs.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],

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
                        onPressed: isBusy 
                            ? null 
                            : (isConnected ? _disconnect : _requestPermissionsAndScan),
                        icon: Icon(isConnected ? Icons.bluetooth_disabled : Icons.bluetooth_searching_outlined),
                        label: Text(isConnected ? 'Disconnect' : 'Scan for devices'),
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
