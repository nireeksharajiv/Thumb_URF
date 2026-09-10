import 'package:flutter_test/flutter_test.dart';
import 'package:thumb_biomech_monitor_glove/core/models/sensor_reading.dart';
import 'package:thumb_biomech_monitor_glove/core/services/session_statistics_accumulator.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _t0 = DateTime.utc(2026, 9, 10, 12);

SensorReading _reading({
  int offsetMs = 0,
  double ip = 20.0,
  double mcp = 15.0,
  double force = 2.0,
  double av = 10.0,
  double mm = 0.5,
}) => SensorReading(
  timestamp: _t0.add(Duration(milliseconds: offsetMs)),
  ipAngle: ip,
  mcpAngle: mcp,
  force: force,
  angularVelocity: av,
  motionMagnitude: mm,
);

// ---------------------------------------------------------------------------

void main() {
  // ── Test 1 ────────────────────────────────────────────────────────────────

  test('1. Fresh accumulator returns all-zero defaults', () {
    final a = SessionStatisticsAccumulator();

    expect(a.readingCount, 0);
    expect(a.averageIpAngle, 0.0);
    expect(a.maximumIpAngle, 0.0);
    expect(a.averageMcpAngle, 0.0);
    expect(a.maximumMcpAngle, 0.0);
    expect(a.averageForce, 0.0);
    expect(a.peakForce, 0.0);
    expect(a.averageAngularVelocity, 0.0);
    expect(a.averageMotionMagnitude, 0.0);
  });

  // ── Test 2 ────────────────────────────────────────────────────────────────

  test('2. Single reading — all stats equal that reading\'s values', () {
    final a = SessionStatisticsAccumulator();
    a.add(_reading(ip: 30.0, mcp: 20.0, force: 4.0, av: -15.0, mm: 0.8));

    expect(a.readingCount, 1);
    expect(a.averageIpAngle, 30.0);
    expect(a.maximumIpAngle, 30.0);
    expect(a.averageMcpAngle, 20.0);
    expect(a.maximumMcpAngle, 20.0);
    expect(a.averageForce, 4.0);
    expect(a.peakForce, 4.0);
    // averageAngularVelocity uses absolute value: |-15| = 15.
    expect(a.averageAngularVelocity, 15.0);
    expect(a.averageMotionMagnitude, 0.8);
  });

  // ── Test 3 ────────────────────────────────────────────────────────────────

  test('3. Multiple readings — averages and maxima are correct', () {
    final a = SessionStatisticsAccumulator();

    // Reading A: ip=20, mcp=10, force=2, av=10, mm=0.4
    a.add(_reading(ip: 20, mcp: 10, force: 2, av: 10, mm: 0.4));
    // Reading B: ip=40, mcp=30, force=6, av=-20, mm=0.8
    a.add(_reading(ip: 40, mcp: 30, force: 6, av: -20, mm: 0.8));

    expect(a.readingCount, 2);

    // Averages: (20+40)/2=30, (10+30)/2=20, (2+6)/2=4, (10+20)/2=15, (0.4+0.8)/2=0.6
    expect(a.averageIpAngle, closeTo(30.0, 0.001));
    expect(a.averageMcpAngle, closeTo(20.0, 0.001));
    expect(a.averageForce, closeTo(4.0, 0.001));
    expect(a.averageAngularVelocity, closeTo(15.0, 0.001)); // |10|+|-20| / 2
    expect(a.averageMotionMagnitude, closeTo(0.6, 0.001));

    // Maxima.
    expect(a.maximumIpAngle, 40.0);
    expect(a.maximumMcpAngle, 30.0);
    expect(a.peakForce, 6.0);
  });

  // ── Test 4 ────────────────────────────────────────────────────────────────

  test('4. reset() clears all accumulated state', () {
    final a = SessionStatisticsAccumulator();
    a.add(_reading(ip: 35, mcp: 25, force: 5, av: 20, mm: 0.7));

    expect(a.readingCount, 1);

    a.reset();

    expect(a.readingCount, 0);
    expect(a.averageIpAngle, 0.0);
    expect(a.maximumIpAngle, 0.0);
    expect(a.peakForce, 0.0);
    expect(a.averageMotionMagnitude, 0.0);
  });
}
