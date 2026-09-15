import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/sensor_reading.dart';
import '../../../core/services/demo_sensor_service.dart';
import '../../../core/services/monitoring_session_repository.dart';
import '../../monitoring/application/monitoring_controller.dart';
import 'widgets/sensor_metric_card.dart';

class LiveMonitoringPage extends StatefulWidget {
  const LiveMonitoringPage({this.controller, this.repository, super.key});

  final MonitoringController? controller;
  final MonitoringSessionRepository? repository;

  @override
  State<LiveMonitoringPage> createState() => _LiveMonitoringPageState();
}

class _LiveMonitoringPageState extends State<LiveMonitoringPage> {
  late final MonitoringController _controller;
  DemoSensorService? _ownedService;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      // Stand-alone mode (e.g. widget tests without a shell).
      _ownedService = DemoSensorService();
      _controller = MonitoringController(
        _ownedService!,
        repository: widget.repository,
      );
    }
  }

  @override
  void dispose() {
    if (_ownedService != null) {
      unawaited(_ownedService!.dispose());
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final reading = _controller.currentReading;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live Monitoring',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const _ConnectionStatusBanner(),
              const SizedBox(height: 16),
              Text(
                'Non-diagnostic research prototype. Measurements are for biomechanical monitoring only.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              _SensorGrid(reading: reading),
              const SizedBox(height: 20),
              _SessionInformation(controller: _controller),
              const SizedBox(height: 16),
              _MovementActivityCard(controller: _controller),
              const SizedBox(height: 16),
              // Post-stop completed-session notice (shown only after a session
              // has been finalised).
              if (_controller.status == MonitoringStatus.stopped &&
                  _controller.lastCompletedSession != null) ...[
                _CompletedSessionBanner(
                  activeDuration: _controller.lastCompletedDuration,
                  movementCount:
                      _controller.lastCompletedSession!.movementCount,
                ),
                const SizedBox(height: 16),
              ],
              const _SensorStatus(),
              const SizedBox(height: 20),
              _MonitoringControls(controller: _controller),
            ],
          ),
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the current device connection state.
/// Until BLE hardware is paired, this always displays NOT CONNECTED.
class _ConnectionStatusBanner extends StatelessWidget {
  const _ConnectionStatusBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: cs.onSurface.withAlpha(100),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'NOT CONNECTED',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.onSurface.withAlpha(160),
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Icon(
              Icons.bluetooth_disabled_outlined,
              size: 18,
              color: cs.onSurface.withAlpha(120),
            ),
          ],
        ),
      ),
    );
  }
}

class _SensorGrid extends StatelessWidget {
  const _SensorGrid({required this.reading});
  final SensorReading? reading;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth > 520
          ? (constraints.maxWidth - 12) / 2
          : constraints.maxWidth;
      // Capture a non-nullable local to allow Dart's flow analysis to promote.
      final r = reading;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: width,
            child: SensorMetricCard(
              title: 'IP JOINT ANGLE',
              location: 'IP joint · Flex sensor',
              value: r == null ? '—' : r.ipAngle.toStringAsFixed(1),
              unit: '°',
              progress: r == null ? 0 : r.ipAngle / 90,
              icon: Icons.straighten_outlined,
            ),
          ),
          SizedBox(
            width: width,
            child: SensorMetricCard(
              title: 'MCP JOINT ANGLE',
              location: 'MCP joint · Flex sensor',
              value: r == null ? '—' : r.mcpAngle.toStringAsFixed(1),
              unit: '°',
              progress: r == null ? 0 : r.mcpAngle / 70,
              icon: Icons.straighten_outlined,
            ),
          ),
          SizedBox(
            width: width,
            child: SensorMetricCard(
              title: 'THUMB-TIP FORCE',
              location: 'Distal phalanx · FSR sensor',
              value: r == null ? '—' : r.force.toStringAsFixed(2),
              unit: 'N',
              progress: r == null ? 0 : r.force / 8,
              icon: Icons.touch_app_outlined,
            ),
          ),
          SizedBox(
            width: width,
            child: SensorMetricCard(
              title: 'MOTION',
              location: 'Near CMC joint · MPU6050 IMU',
              value: r == null
                  ? '—'
                  : r.angularVelocity.abs().toStringAsFixed(1),
              unit: '°/s',
              progress: r == null ? 0 : r.motionMagnitude / 2.5,
              icon: Icons.motion_photos_on_outlined,
              secondaryValue: r == null
                  ? 'Motion magnitude: awaiting reading'
                  : 'Motion magnitude: ${r.motionMagnitude.toStringAsFixed(2)} g',
            ),
          ),
        ],
      );
    },
  );
}

class _SessionInformation extends StatelessWidget {
  const _SessionInformation({required this.controller});
  final MonitoringController controller;

  @override
  Widget build(BuildContext context) {
    final duration = controller.elapsedDuration;
    final durationLabel =
        '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    final active = (controller.currentReading?.motionMagnitude ?? 0) > 0.35;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Active Duration', value: durationLabel),
            _InfoRow(
              label: 'Movement Activity',
              value: active
                  ? 'Observed sensor activity'
                  : 'Resting-level activity',
            ),
            _InfoRow(
              label: 'Current Sensor Status',
              value: controller.status == MonitoringStatus.stopped
                  ? 'Ready'
                  : controller.status.name,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: Theme.of(context).textTheme.labelLarge),
      ],
    ),
  );
}

class _MovementActivityCard extends StatelessWidget {
  const _MovementActivityCard({required this.controller});
  final MonitoringController controller;

  @override
  Widget build(BuildContext context) {
    final moving = controller.isMoving;
    final count = controller.movementCount;
    final freq = controller.movementsPerMinute;
    final dur = controller.currentMovementDuration;

    final statusLabel = moving ? 'MOVING' : 'RESTING';
    final statusColor = moving
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outline;
    final countLabel =
        controller.status == MonitoringStatus.stopped ? '—' : '$count';
    final freqLabel = controller.status == MonitoringStatus.stopped
        ? '—'
        : '${freq.toStringAsFixed(1)} /min';
    final durLabel = controller.status == MonitoringStatus.stopped
        ? '—'
        : moving
            ? '${(dur.inMilliseconds / 1000).toStringAsFixed(1)} s'
            : '0.0 s';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.repeat_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Movement Activity',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Biomechanical movement monitoring',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('Movement Status')),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withAlpha(80)),
                  ),
                  child: Text(
                    statusLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(label: 'Movement Count', value: countLabel),
            _InfoRow(label: 'Movement Frequency', value: freqLabel),
            _InfoRow(label: 'Current Duration', value: durLabel),
          ],
        ),
      ),
    );
  }
}

/// Shown after a session is stopped, summarising the just-completed session.
class _CompletedSessionBanner extends StatelessWidget {
  const _CompletedSessionBanner({
    required this.activeDuration,
    required this.movementCount,
  });

  final Duration activeDuration;
  final int movementCount;

  @override
  Widget build(BuildContext context) {
    final mins = activeDuration.inMinutes.toString().padLeft(2, '0');
    final secs =
        (activeDuration.inSeconds % 60).toString().padLeft(2, '0');

    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session completed',
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Active time $mins:$secs · $movementCount movement event${movementCount == 1 ? '' : 's'} detected · View in Sessions',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSecondaryContainer.withAlpha(180),
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

class _SensorStatus extends StatelessWidget {
  const _SensorStatus();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sensor Status', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: Icon(Icons.sensors_outlined, size: 18),
                label: Text('Thumb-tip FSR'),
              ),
              Chip(
                avatar: Icon(Icons.sensors_outlined, size: 18),
                label: Text('IP Flex Sensor'),
              ),
              Chip(
                avatar: Icon(Icons.sensors_outlined, size: 18),
                label: Text('MCP Flex Sensor'),
              ),
              Chip(
                avatar: Icon(Icons.sensors_outlined, size: 18),
                label: Text('MPU-6050 IMU'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _MonitoringControls extends StatelessWidget {
  const _MonitoringControls({required this.controller});
  final MonitoringController controller;
  @override
  Widget build(BuildContext context) {
    if (controller.status == MonitoringStatus.stopped) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: controller.start,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Monitoring'),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: controller.isPaused
                ? controller.resume
                : controller.pause,
            icon:
                Icon(controller.isPaused ? Icons.play_arrow : Icons.pause),
            label: Text(controller.isPaused ? 'Resume' : 'Pause'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: controller.stop,
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
          ),
        ),
      ],
    );
  }
}
