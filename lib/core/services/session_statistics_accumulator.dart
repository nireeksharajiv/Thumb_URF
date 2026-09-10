import '../models/sensor_reading.dart';

/// Accumulates running statistics from a stream of [SensorReading]s.
///
/// Uses O(1) memory — only running sums and maxima are kept, never a
/// list of all readings.
///
/// Call [reset] before each new monitoring session and [add] for every
/// reading received while the session is active.
///
/// All getters return 0 when no readings have been added, so callers never
/// need to guard against an empty session.
class SessionStatisticsAccumulator {
  int _count = 0;

  // Running sums (for averages).
  double _sumIp = 0;
  double _sumMcp = 0;
  double _sumForce = 0;
  double _sumAngularVelocity = 0; // accumulates absolute value
  double _sumMotionMagnitude = 0;

  // Running maxima.
  double _maxIp = 0;
  double _maxMcp = 0;
  double _maxForce = 0;

  // ── Public getters ────────────────────────────────────────────────────────

  /// Number of readings added since the last [reset].
  int get readingCount => _count;

  double get averageIpAngle => _count == 0 ? 0 : _sumIp / _count;
  double get maximumIpAngle => _maxIp;

  double get averageMcpAngle => _count == 0 ? 0 : _sumMcp / _count;
  double get maximumMcpAngle => _maxMcp;

  double get averageForce => _count == 0 ? 0 : _sumForce / _count;
  double get peakForce => _maxForce;

  /// Average of the **absolute** angular velocity values (always ≥ 0).
  double get averageAngularVelocity =>
      _count == 0 ? 0 : _sumAngularVelocity / _count;

  double get averageMotionMagnitude =>
      _count == 0 ? 0 : _sumMotionMagnitude / _count;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Resets all accumulators to zero. Call before each new monitoring session.
  void reset() {
    _count = 0;
    _sumIp = 0;
    _sumMcp = 0;
    _sumForce = 0;
    _sumAngularVelocity = 0;
    _sumMotionMagnitude = 0;
    _maxIp = 0;
    _maxMcp = 0;
    _maxForce = 0;
  }

  /// Records one [SensorReading] into the running statistics.
  void add(SensorReading reading) {
    _count++;

    _sumIp += reading.ipAngle;
    if (reading.ipAngle > _maxIp) _maxIp = reading.ipAngle;

    _sumMcp += reading.mcpAngle;
    if (reading.mcpAngle > _maxMcp) _maxMcp = reading.mcpAngle;

    _sumForce += reading.force;
    if (reading.force > _maxForce) _maxForce = reading.force;

    _sumAngularVelocity += reading.angularVelocity.abs();
    _sumMotionMagnitude += reading.motionMagnitude;
  }
}
