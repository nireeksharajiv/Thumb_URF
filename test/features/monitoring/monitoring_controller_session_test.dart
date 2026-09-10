import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thumb_biomech_monitor_glove/core/models/sensor_reading.dart';
import 'package:thumb_biomech_monitor_glove/core/services/sensor_data_source.dart';
import 'package:thumb_biomech_monitor_glove/core/services/session_repository.dart';
import 'package:thumb_biomech_monitor_glove/features/monitoring/application/monitoring_controller.dart';

// ---------------------------------------------------------------------------
// Fake sensor data source — controllable in tests.
// ---------------------------------------------------------------------------

class FakeSensorDataSource implements SensorDataSource {
  final _controller = StreamController<SensorReading>.broadcast(sync: true);

  @override
  Stream<SensorReading> get readings => _controller.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  Future<void> dispose() async => _controller.close();

  /// Emit a reading directly into the stream.
  void emit(SensorReading reading) => _controller.add(reading);
}

// ---------------------------------------------------------------------------
// Helper — build a minimal SensorReading.
// ---------------------------------------------------------------------------

final _t0 = DateTime.utc(2026, 9, 10, 12);

SensorReading _r(
  int offsetMs, {
  double ip = 20.0,
  double mcp = 15.0,
  double force = 2.0,
  double av = 5.0,
  double mm = 0.3,
}) => SensorReading(
  timestamp: _t0.add(Duration(milliseconds: offsetMs)),
  ipAngle: ip,
  mcpAngle: mcp,
  force: force,
  angularVelocity: av,
  motionMagnitude: mm,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late Directory tempDir;
  late FakeSensorDataSource source;
  late SessionRepository repository;
  late MonitoringController controller;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ctrl_sess_test_');
    source = FakeSensorDataSource();
    repository = SessionRepository(
      storageFile: File('${tempDir.path}/test_sessions.json'),
    );
    controller = MonitoringController(source, repository: repository);
  });

  tearDown(() async {
    controller.dispose();
    await source.dispose();
    repository.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // ── Test 5 ────────────────────────────────────────────────────────────────

  test('5. start() creates fresh session state — does not inherit prior stats',
      () async {
    // First session.
    await controller.start();
    source.emit(_r(100, ip: 40, force: 5));
    source.emit(_r(200, ip: 40, force: 5));
    await controller.stop();
    expect(repository.sessions, hasLength(1));
    expect(repository.sessions.first.averageIpAngle, greaterThan(0));

    // Second session must start with zeroed statistics.
    await controller.start();
    // No readings this session.
    await controller.stop();
    expect(repository.sessions, hasLength(2));
    final second = repository.sessions[1];
    expect(second.averageIpAngle, 0.0);
    expect(second.movementCount, 0);
  });

  // ── Test 6 ────────────────────────────────────────────────────────────────

  test('6. Sensor readings accumulate during an active session', () async {
    await controller.start();
    source.emit(_r(100, ip: 30, force: 3));
    source.emit(_r(200, ip: 50, force: 7));
    await controller.stop();

    final s = repository.sessions.first;
    expect(s.averageIpAngle, closeTo(40.0, 0.001)); // (30+50)/2
    expect(s.maximumIpAngle, 50.0);
    expect(s.averageForce, closeTo(5.0, 0.001)); // (3+7)/2
    expect(s.peakForce, 7.0);
  });

  // ── Test 7 ────────────────────────────────────────────────────────────────

  test('7. pause() preserves accumulated statistics — paused readings ignored',
      () async {
    await controller.start();
    source.emit(_r(100, ip: 30, force: 3)); // counted: avg ip=30, force=3
    await controller.pause();
    // These readings arrive while paused — must NOT be counted.
    source.emit(_r(200, ip: 60, force: 10));
    source.emit(_r(300, ip: 60, force: 10));
    await controller.stop();

    final s = repository.sessions.first;
    // Only the reading before pause was accumulated.
    expect(s.averageIpAngle, closeTo(30.0, 0.001));
    expect(s.peakForce, closeTo(3.0, 0.001));
  });

  // ── Test 8 ────────────────────────────────────────────────────────────────

  test('8. resume() continues accumulation after pause', () async {
    await controller.start();
    source.emit(_r(100, ip: 20, force: 2)); // session reading 1
    await controller.pause();
    source.emit(_r(200, ip: 99, force: 99)); // ignored
    await controller.resume();
    source.emit(_r(300, ip: 40, force: 6)); // session reading 2
    await controller.stop();

    final s = repository.sessions.first;
    // avg ip = (20+40)/2 = 30, peak force = 6
    expect(s.averageIpAngle, closeTo(30.0, 0.001));
    expect(s.peakForce, closeTo(6.0, 0.001));
  });

  // ── Test 9 ────────────────────────────────────────────────────────────────

  test('9. stop() finalises the session and pushes it to the repository',
      () async {
    expect(repository.sessions, isEmpty);

    await controller.start();
    source.emit(_r(100, ip: 25, mcp: 18, force: 3));
    await controller.stop();

    expect(repository.sessions, hasLength(1));
    final s = repository.sessions.first;
    expect(s.id, isNotEmpty);
    expect(s.startTime, isNotNull);
    expect(s.endTime.isAfter(s.startTime), isTrue);
    expect(s.averageIpAngle, closeTo(25.0, 0.001));
    expect(s.averageMcpAngle, closeTo(18.0, 0.001));
    expect(s.averageForce, closeTo(3.0, 0.001));
  });

  // ── Test 10 ───────────────────────────────────────────────────────────────

  test('10. Empty session (no readings) is handled safely — all stats zero',
      () async {
    await controller.start();
    // Emit no readings.
    await controller.stop();

    expect(repository.sessions, hasLength(1));
    final s = repository.sessions.first;
    expect(s.averageIpAngle, 0.0);
    expect(s.maximumIpAngle, 0.0);
    expect(s.averageForce, 0.0);
    expect(s.peakForce, 0.0);
    expect(s.movementCount, 0);
    expect(s.endTime.isAfter(s.startTime), isTrue);
  });

  // ── Test 11 ───────────────────────────────────────────────────────────────

  test('11. Session history stores completed sessions in insertion order',
      () async {
    // Session 1.
    await controller.start();
    source.emit(_r(100, ip: 20, force: 1));
    await controller.stop();

    // Session 2.
    await controller.start();
    source.emit(_r(100, ip: 40, force: 5));
    await controller.stop();

    // Session 3.
    await controller.start();
    source.emit(_r(100, ip: 60, force: 9));
    await controller.stop();

    expect(repository.sessions, hasLength(3));
    // Oldest first in the repository.
    expect(repository.sessions[0].averageIpAngle, closeTo(20.0, 0.001));
    expect(repository.sessions[1].averageIpAngle, closeTo(40.0, 0.001));
    expect(repository.sessions[2].averageIpAngle, closeTo(60.0, 0.001));
  });
}
