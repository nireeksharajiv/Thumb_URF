import 'package:flutter_test/flutter_test.dart';
import 'package:thumb_biomech_monitor_glove/core/services/demo_sensor_service.dart';

void main() {
  late DemoSensorService service;

  setUp(() {
    service = DemoSensorService(
      samplingInterval: const Duration(milliseconds: 5),
    );
  });

  tearDown(() => service.dispose());

  // ── Basic emission ───────────────────────────────────────────────────────

  test('start emits at least one reading', () async {
    final nextReading = service.readings.first;
    await service.start();
    await expectLater(
      nextReading.timeout(const Duration(seconds: 1)),
      completes,
    );
  });

  test('readings carry UTC timestamps', () async {
    final nextReading = service.readings.first;
    await service.start();
    final reading = await nextReading.timeout(const Duration(seconds: 1));
    expect(reading.timestamp.isUtc, isTrue);
  });

  test('readings satisfy model validation (non-negative fields)', () async {
    final nextReading = service.readings.first;
    await service.start();
    final reading = await nextReading.timeout(const Duration(seconds: 1));

    // These must hold for SensorReading's internal validation to have passed.
    expect(reading.ipAngle, greaterThanOrEqualTo(0));
    expect(reading.mcpAngle, greaterThanOrEqualTo(0));
    expect(reading.force, greaterThanOrEqualTo(0));
    expect(reading.motionMagnitude, greaterThanOrEqualTo(0));
    expect(reading.timestamp.isUtc, isTrue);
  });

  // ── Pause / resume ───────────────────────────────────────────────────────

  test('pause stops emissions and resume continues them', () async {
    final readings = <Object>[];
    final subscription = service.readings.listen(readings.add);
    addTearDown(subscription.cancel);

    await service.start();
    await Future<void>.delayed(const Duration(milliseconds: 25));
    await service.pause();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final pausedCount = readings.length;

    // No new readings should arrive during pause.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(readings, hasLength(pausedCount));

    // Readings resume after resume().
    await service.resume();
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(readings.length, greaterThan(pausedCount));
  });

  // ── Stop ─────────────────────────────────────────────────────────────────

  test('stop cancels periodic emissions and allows a new start', () async {
    final readings = <Object>[];
    final subscription = service.readings.listen(readings.add);
    addTearDown(subscription.cancel);

    await service.start();
    await Future<void>.delayed(const Duration(milliseconds: 25));
    await service.stop();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final stoppedCount = readings.length;

    // No new readings should arrive after stop.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(readings, hasLength(stoppedCount));

    // A fresh start must work.
    await service.start();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(readings.length, greaterThan(stoppedCount));
  });

  // ── Idempotent start ──────────────────────────────────────────────────────

  test('calling start twice does not create multiple timers or duplicate readings',
      () async {
    // Two concurrent timers would roughly double the emission rate.
    // We verify start() is a no-op when already running.
    final readings = <Object>[];
    final subscription = service.readings.listen(readings.add);
    addTearDown(subscription.cancel);

    await service.start();
    await service.start(); // second call — must not restart timer
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await service.stop();

    // With a 5 ms interval over 50 ms we expect roughly 10 readings (+1 on start).
    // A double-timer would produce roughly 20+. Use 18 as a conservative ceiling.
    expect(readings.length, lessThanOrEqualTo(18));
  });
}

