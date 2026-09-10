import 'package:flutter_test/flutter_test.dart';
import 'package:thumb_biomech_monitor_glove/core/models/sensor_reading.dart';
import 'package:thumb_biomech_monitor_glove/core/services/movement_detection_service.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// A detector with tight, explicit thresholds so tests use small readable values.
///
/// ipAngle=5°, mcpAngle=5°, angularVelocity=10°/s, motionMagnitude=0.2 g,
/// minimumMovementDuration=200 ms, debounce=300 ms.
MovementDetectionService _makeDetector() => MovementDetectionService(
  ipAngleChangeDeg: 5.0,
  mcpAngleChangeDeg: 5.0,
  angularVelocityDegPerSec: 10.0,
  motionMagnitudeG: 0.2,
  minimumMovementDuration: const Duration(milliseconds: 200),
  movementEndDebounce: const Duration(milliseconds: 300),
);

/// Builds a SensorReading at the given millisecond offset from [_t0].
/// [ipAngle] is supplied explicitly so callers can alternate it to maintain
/// a non-zero delta between consecutive readings.
SensorReading _r(
  int ms, {
  double ipAngle = 20.0,
  double mcpAngle = 15.0,
  double angularVelocity = 2.0, // well below threshold
  double motionMagnitude = 0.05, // well below threshold
}) => SensorReading(
  timestamp: _t0.add(Duration(milliseconds: ms)),
  ipAngle: ipAngle,
  mcpAngle: mcpAngle,
  force: 0.5,
  angularVelocity: angularVelocity,
  motionMagnitude: motionMagnitude,
);

/// A reading that satisfies **both** the flex-sensor signal (ipAngle alternates
/// ±10° relative to [prev]) AND the IMU signal (angularVelocity=20°/s).
///
/// [flip] swings between 20° and 30°, keeping |Δip|=10° on every step.
SensorReading _active(int ms, {required bool flip}) => _r(
  ms,
  ipAngle: flip ? 30.0 : 20.0, // alternates ±10° → delta always = 10 > 5
  angularVelocity: 20.0, // above 10 °/s IMU threshold
  motionMagnitude: 0.5, // above 0.2 g IMU threshold
);

/// A resting reading — both flex and IMU well below threshold.
SensorReading _rest(int ms) => _r(ms);

final _t0 = DateTime.utc(2026, 9, 10, 12);

// ---------------------------------------------------------------------------

void main() {
  // ── Test 1 ────────────────────────────────────────────────────────────────

  test('1. Resting readings produce no movement', () {
    final d = _makeDetector()..reset();

    d.processReading(_rest(0));
    d.processReading(_rest(100));
    d.processReading(_rest(200));
    d.processReading(_rest(300));

    expect(d.isMoving, isFalse);
    expect(d.movementCount, 0);
    expect(d.currentMovementDuration, Duration.zero);
  });

  // ── Test 2 ────────────────────────────────────────────────────────────────

  test('2. Readings crossing the threshold start a movement', () {
    final d = _makeDetector()..reset();

    // prev = rest(ipAngle=20), next = active(ipAngle=30) → delta=10 > 5
    d.processReading(_rest(0));
    d.processReading(_active(100, flip: true));

    expect(d.isMoving, isTrue);
    expect(d.movementCount, 0); // event not yet closed
  });

  // ── Test 3 ────────────────────────────────────────────────────────────────

  test('3. Continuous movement produces ONE open event, not N events', () {
    final d = _makeDetector()..reset();

    // Alternating angle keeps |Δip|=10° on every step → always active.
    d.processReading(_rest(0)); // prev = 20°
    for (var i = 1; i <= 8; i++) {
      d.processReading(_active(i * 100, flip: i.isOdd)); // 30,20,30,20...
    }

    // Event is open but debounce hasn't expired → still one in-progress event.
    expect(d.isMoving, isTrue);
    expect(d.movementCount, 0);
  });

  // ── Test 4 ────────────────────────────────────────────────────────────────

  test('4. Movement ending after debounce produces exactly one completed event',
      () {
    final d = _makeDetector()..reset();

    // Alternating readings keep flex delta=10° on every active step.
    d.processReading(_rest(0)); // baseline: 20°
    d.processReading(_active(100, flip: true)); // 30° → delta=10 → start
    d.processReading(_active(200, flip: false)); // 20° → delta=10 → lastActive=200
    d.processReading(_active(350, flip: true)); // 30° → delta=10 → lastActive=350
    // Rest reading 400 ms after lastActive=350 → 750-350=400 >= debounce(300) → close.
    // duration = lastActive(350ms) - start(100ms) = 250ms >= minDuration(200ms) → count=1
    d.processReading(_rest(750));

    expect(d.isMoving, isFalse);
    expect(d.movementCount, 1);
  });

  // ── Test 5 ────────────────────────────────────────────────────────────────

  test('5. Two separated movement events produce movementCount == 2', () {
    final d = _makeDetector()..reset();

    // Event 1 — t=0 to t=750 ms
    d.processReading(_rest(0));
    d.processReading(_active(100, flip: true)); // start
    d.processReading(_active(200, flip: false));
    d.processReading(_active(350, flip: true)); // lastActive=350
    d.processReading(_rest(750)); // 750-350=400 >= 300 → close; 250ms >= 200ms → count=1

    expect(d.movementCount, 1);

    // Event 2 — starts from the resting state after event 1 ended.
    // prev = _rest(750) at ipAngle=20°, so flip:true gives 30° → delta=10 → active.
    d.processReading(_active(1000, flip: true)); // 30° → prev=20°(rest) → start=1000ms
    d.processReading(_active(1100, flip: false)); // 20° → delta=10 → lastActive=1100ms
    d.processReading(_active(1250, flip: true)); // 30° → delta=10 → lastActive=1250ms
    d.processReading(_rest(1650)); // 1650-1250=400 >= 300 → close; 250ms >= 200ms → count=2

    expect(d.movementCount, 2);
    expect(d.isMoving, isFalse);
  });

  // ── Test 6 ────────────────────────────────────────────────────────────────

  test('6. Sub-threshold sensor fluctuations do not trigger movement', () {
    final d = _makeDetector()..reset();

    // Only 2° angle change — below 5° flex threshold.
    // Only 3 °/s angular velocity — below 10 °/s IMU threshold.
    d.processReading(_r(0, ipAngle: 20.0, angularVelocity: 2.0, motionMagnitude: 0.05));
    d.processReading(_r(100, ipAngle: 22.0, angularVelocity: 3.0, motionMagnitude: 0.08));
    d.processReading(_r(200, ipAngle: 20.0, angularVelocity: 2.0, motionMagnitude: 0.05));
    d.processReading(_r(300, ipAngle: 22.0, angularVelocity: 3.0, motionMagnitude: 0.08));

    expect(d.isMoving, isFalse);
    expect(d.movementCount, 0);
  });

  // ── Test 7 ────────────────────────────────────────────────────────────────

  test('7. Movement shorter than minimumMovementDuration is NOT counted', () {
    final d = _makeDetector()..reset();

    // Only ONE active reading at t=100ms, then nothing for 400ms.
    // Event duration = lastActive(100) - start(100) = 0ms < minDuration(200ms).
    d.processReading(_rest(0)); // baseline 20°
    d.processReading(_active(100, flip: true)); // 30° → start, lastActive=100ms
    // 400ms after lastActive → debounce expired.
    // duration = 100-100 = 0ms < 200ms minDuration → NOT counted.
    d.processReading(_rest(500));

    expect(d.isMoving, isFalse);
    expect(d.movementCount, 0);
  });

  // ── Test 8 ────────────────────────────────────────────────────────────────

  test('8. movementsPerMinute is calculated correctly from timestamps', () {
    final d = _makeDetector()..reset();

    // Event 1: starts at 100ms, lasts until 350ms (lastActive), closed at 750ms.
    d.processReading(_rest(0));
    d.processReading(_active(100, flip: true));
    d.processReading(_active(200, flip: false));
    d.processReading(_active(350, flip: true)); // lastActive=350
    d.processReading(_rest(750)); // close; 250ms >= 200ms → count=1

    // Event 2: same structure, prev after close is _rest(750) at 20°.
    d.processReading(_active(1200, flip: true)); // 30° → prev=20° → start=1200ms
    d.processReading(_active(1350, flip: false)); // 20° → delta=10 → lastActive=1350ms
    d.processReading(_active(1500, flip: true)); // 30° → delta=10 → lastActive=1500ms
    d.processReading(_rest(1900)); // 1900-1500=400 >= 300 → close; 300ms >= 200ms → count=2

    // Advance time to 60 s from session start.
    d.processReading(_rest(60000));

    expect(d.movementCount, 2);
    // session window = 60000ms = 1 min → freq = 2 / 1 = 2.0 /min
    expect(d.movementsPerMinute, closeTo(2.0, 0.05));
  });

  // ── Test 9 ────────────────────────────────────────────────────────────────

  test('9. markStopped closes an open movement and leaves detector resting', () {
    final d = _makeDetector()..reset();

    d.processReading(_rest(0));
    d.processReading(_active(100, flip: true)); // start=100ms
    d.processReading(_active(200, flip: false)); // lastActive=200ms
    d.processReading(_active(350, flip: true)); // lastActive=350ms

    expect(d.isMoving, isTrue);

    d.markStopped();

    expect(d.isMoving, isFalse);
    // duration = lastActive(350) - start(100) = 250ms >= minDuration(200ms) → counted.
    expect(d.movementCount, 1);
  });

  // ── Test 10 ───────────────────────────────────────────────────────────────

  test('10. reset() clears all counters for a new session', () {
    final d = _makeDetector()..reset();

    // Accumulate one completed event.
    d.processReading(_rest(0));
    d.processReading(_active(100, flip: true));
    d.processReading(_active(200, flip: false));
    d.processReading(_active(350, flip: true)); // lastActive=350
    d.processReading(_rest(750)); // close → count=1

    expect(d.movementCount, 1);

    // Start a fresh session.
    d.reset();

    expect(d.isMoving, isFalse);
    expect(d.movementCount, 0);
    expect(d.currentMovementDuration, Duration.zero);
    expect(d.movementsPerMinute, 0.0);
  });
}
