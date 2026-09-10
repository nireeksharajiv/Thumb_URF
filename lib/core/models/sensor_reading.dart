/// A complete, timestamped biomechanical sample independent of its source.
class SensorReading {
  SensorReading({
    required DateTime timestamp,
    required this.ipAngle,
    required this.mcpAngle,
    required this.force,
    required this.angularVelocity,
    required this.motionMagnitude,
  }) : timestamp = timestamp.toUtc() {
    _validateNonNegative('ipAngle', ipAngle);
    _validateNonNegative('mcpAngle', mcpAngle);
    _validateNonNegative('force', force);
    _validateNonNegative('motionMagnitude', motionMagnitude);
  }

  final DateTime timestamp;
  final double ipAngle;
  final double mcpAngle;
  final double force;
  final double angularVelocity;
  final double motionMagnitude;

  Map<String, Object> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'ipAngle': ipAngle,
    'mcpAngle': mcpAngle,
    'force': force,
    'angularVelocity': angularVelocity,
    'motionMagnitude': motionMagnitude,
  };

  factory SensorReading.fromJson(Map<String, Object?> json) => SensorReading(
    timestamp: _readTimestamp(json, 'timestamp'),
    ipAngle: _readNumber(json, 'ipAngle'),
    mcpAngle: _readNumber(json, 'mcpAngle'),
    force: _readNumber(json, 'force'),
    angularVelocity: _readNumber(json, 'angularVelocity'),
    motionMagnitude: _readNumber(json, 'motionMagnitude'),
  );

  static DateTime _readTimestamp(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String) {
      return DateTime.parse(value).toUtc();
    }
    throw FormatException('Expected an ISO-8601 timestamp for "$key".');
  }

  static double _readNumber(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is num) {
      return value.toDouble();
    }
    throw FormatException('Expected a number for "$key".');
  }

  static void _validateNonNegative(String name, double value) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(
        value,
        name,
        'Must be a finite non-negative value.',
      );
    }
  }
}
