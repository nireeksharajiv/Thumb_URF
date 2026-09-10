/// Configurable engineering thresholds for the movement detection algorithm.
///
/// All values are adjustable research parameters — they are NOT clinically
/// validated thresholds. Adjust as needed during prototype evaluation.
abstract final class MovementDetectionConfig {
  // ── Angle-change triggers (flex sensors) ────────────────────────────────

  /// Minimum change in IP joint angle (°) between consecutive readings
  /// required for the angle signal to contribute to movement detection.
  static const double ipAngleChangeDeg = 8.0;

  /// Minimum change in MCP joint angle (°) between consecutive readings
  /// required for the angle signal to contribute to movement detection.
  static const double mcpAngleChangeDeg = 6.0;

  // ── IMU confirmation triggers ────────────────────────────────────────────

  /// Minimum absolute angular velocity (°/s) from the MPU6050 required for
  /// the IMU signal to confirm movement.
  static const double angularVelocityDegPerSec = 15.0;

  /// Minimum motion magnitude (g) from the MPU6050 required for the IMU
  /// signal to confirm movement.
  static const double motionMagnitudeG = 0.30;

  // ── Temporal gating ─────────────────────────────────────────────────────

  /// A movement event must span at least this long to be counted.
  /// Short transients (sensor noise, micro-vibrations) are excluded.
  static const Duration minimumMovementDuration = Duration(milliseconds: 200);

  /// After the last active reading, wait at least this long before closing
  /// a movement event. Prevents a single continuous gesture from being split
  /// into multiple events due to brief inter-peak lulls.
  static const Duration movementEndDebounce = Duration(milliseconds: 300);
}
