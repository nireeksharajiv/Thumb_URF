/// A completed monitoring-session summary for future local or database storage.
class MonitoringSession {
  MonitoringSession({
    required this.id,
    this.userId,
    required DateTime startTime,
    required DateTime endTime,
    required this.movementCount,
    required this.averageIpAngle,
    required this.maximumIpAngle,
    required this.averageMcpAngle,
    required this.maximumMcpAngle,
    required this.averageForce,
    required this.peakForce,
    required this.averageAngularVelocity,
    required this.averageMotionMagnitude,
  }) : startTime = startTime.toUtc(),
       endTime = endTime.toUtc() {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Cannot be empty.');
    }
    if (this.endTime.isBefore(this.startTime)) {
      throw ArgumentError.value(
        endTime,
        'endTime',
        'Cannot be before startTime.',
      );
    }
    if (movementCount < 0) {
      throw ArgumentError.value(
        movementCount,
        'movementCount',
        'Cannot be negative.',
      );
    }
    _validateSummaryValues();
  }

  final String id;
  final String? userId;
  final DateTime startTime;
  final DateTime endTime;
  final int movementCount;
  final double averageIpAngle;
  final double maximumIpAngle;
  final double averageMcpAngle;
  final double maximumMcpAngle;
  final double averageForce;
  final double peakForce;
  final double averageAngularVelocity;
  final double averageMotionMagnitude;

  Duration get duration => endTime.difference(startTime);

  Map<String, Object> toJson() {
    final map = <String, Object>{
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'movementCount': movementCount,
      'averageIpAngle': averageIpAngle,
      'maximumIpAngle': maximumIpAngle,
      'averageMcpAngle': averageMcpAngle,
      'maximumMcpAngle': maximumMcpAngle,
      'averageForce': averageForce,
      'peakForce': peakForce,
      'averageAngularVelocity': averageAngularVelocity,
      'averageMotionMagnitude': averageMotionMagnitude,
    };
    if (userId != null) {
      map['userId'] = userId!;
    }
    return map;
  }

  factory MonitoringSession.fromJson(Map<String, Object?> json) {
    final id = json['id']?.toString() ?? '';
    final userId = json['userId']?.toString();
    final startTimeStr = json['startTime']?.toString();
    final endTimeStr = json['endTime']?.toString();
    if (startTimeStr == null || endTimeStr == null) {
      throw const FormatException('Session json missing startTime or endTime.');
    }

    double readDouble(String key) {
      final v = json[key];
      if (v is num) return v.toDouble();
      throw FormatException('Expected numeric value for "$key".');
    }

    int readInt(String key) {
      final v = json[key];
      if (v is num) return v.toInt();
      throw FormatException('Expected integer value for "$key".');
    }

    return MonitoringSession(
      id: id,
      userId: userId,
      startTime: DateTime.parse(startTimeStr).toUtc(),
      endTime: DateTime.parse(endTimeStr).toUtc(),
      movementCount: readInt('movementCount'),
      averageIpAngle: readDouble('averageIpAngle'),
      maximumIpAngle: readDouble('maximumIpAngle'),
      averageMcpAngle: readDouble('averageMcpAngle'),
      maximumMcpAngle: readDouble('maximumMcpAngle'),
      averageForce: readDouble('averageForce'),
      peakForce: readDouble('peakForce'),
      averageAngularVelocity: readDouble('averageAngularVelocity'),
      averageMotionMagnitude: readDouble('averageMotionMagnitude'),
    );
  }

  void _validateSummaryValues() {
    final values = [
      averageIpAngle,
      maximumIpAngle,
      averageMcpAngle,
      maximumMcpAngle,
      averageForce,
      peakForce,
      averageAngularVelocity,
      averageMotionMagnitude,
    ];
    if (values.any((value) => !value.isFinite || value < 0)) {
      throw ArgumentError(
        'Session summary values must be finite and non-negative.',
      );
    }
    if (maximumIpAngle < averageIpAngle ||
        maximumMcpAngle < averageMcpAngle ||
        peakForce < averageForce) {
      throw ArgumentError(
        'Maximum and peak values cannot be lower than their averages.',
      );
    }
  }
}
