import 'monitoring_session.dart';
import 'sensor_reading.dart';

/// Maps [MonitoringSession] entities to and from Supabase snake_case table records.
abstract final class MonitoringSessionSupabaseMapper {
  /// Converts a [MonitoringSession] to a JSON-compatible map for the `monitoring_sessions` table.
  static Map<String, dynamic> toMap(
    MonitoringSession session, {
    required String userId,
  }) => {
    'id': session.id,
    'user_id': userId,
    'started_at': session.startTime.toUtc().toIso8601String(),
    'ended_at': session.endTime.toUtc().toIso8601String(),
    'duration_seconds': session.duration.inSeconds,
    'movement_count': session.movementCount,
    'average_ip_angle': session.averageIpAngle,
    'max_ip_angle': session.maximumIpAngle,
    'average_mcp_angle': session.averageMcpAngle,
    'max_mcp_angle': session.maximumMcpAngle,
    'average_force': session.averageForce,
    'peak_force': session.peakForce,
    'average_angular_velocity': session.averageAngularVelocity,
    'average_motion_magnitude': session.averageMotionMagnitude,
  };

  /// Constructs a [MonitoringSession] from a Supabase row map.
  static MonitoringSession fromMap(Map<String, dynamic> map) {
    final id = map['id']?.toString() ?? '';
    final startedAtRaw = map['started_at']?.toString();
    final endedAtRaw = map['ended_at']?.toString();

    if (startedAtRaw == null || endedAtRaw == null) {
      throw const FormatException('Session row missing started_at or ended_at timestamp.');
    }

    return MonitoringSession(
      id: id,
      startTime: DateTime.parse(startedAtRaw).toUtc(),
      endTime: DateTime.parse(endedAtRaw).toUtc(),
      movementCount: _readInt(map, 'movement_count'),
      averageIpAngle: _readDouble(map, 'average_ip_angle'),
      maximumIpAngle: _readDouble(map, 'max_ip_angle'),
      averageMcpAngle: _readDouble(map, 'average_mcp_angle'),
      maximumMcpAngle: _readDouble(map, 'max_mcp_angle'),
      averageForce: _readDouble(map, 'average_force'),
      peakForce: _readDouble(map, 'peak_force'),
      averageAngularVelocity: _readDouble(map, 'average_angular_velocity'),
      averageMotionMagnitude: _readDouble(map, 'average_motion_magnitude'),
    );
  }

  static double _readDouble(Map<String, dynamic> map, String key) {
    final val = map[key];
    if (val is num) return val.toDouble();
    throw FormatException('Expected numeric double value for "$key".');
  }

  static int _readInt(Map<String, dynamic> map, String key) {
    final val = map[key];
    if (val is num) return val.toInt();
    throw FormatException('Expected integer value for "$key".');
  }
}

/// Maps [SensorReading] entities to and from Supabase snake_case table records.
abstract final class SensorReadingSupabaseMapper {
  /// Converts a [SensorReading] to a JSON-compatible map for the `sensor_readings` table.
  static Map<String, dynamic> toMap(
    SensorReading reading, {
    required String sessionId,
    String? id,
  }) {
    final map = <String, dynamic>{
      'session_id': sessionId,
      'timestamp': reading.timestamp.toUtc().toIso8601String(),
      'ip_angle': reading.ipAngle,
      'mcp_angle': reading.mcpAngle,
      'force': reading.force,
      'angular_velocity': reading.angularVelocity,
      'motion_magnitude': reading.motionMagnitude,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  /// Constructs a [SensorReading] from a Supabase row map.
  static SensorReading fromMap(Map<String, dynamic> map) {
    final timestampRaw = map['timestamp']?.toString();
    if (timestampRaw == null) {
      throw const FormatException('Sensor reading row missing timestamp.');
    }

    return SensorReading(
      timestamp: DateTime.parse(timestampRaw).toUtc(),
      ipAngle: _readDouble(map, 'ip_angle'),
      mcpAngle: _readDouble(map, 'mcp_angle'),
      force: _readDouble(map, 'force'),
      angularVelocity: _readDouble(map, 'angular_velocity'),
      motionMagnitude: _readDouble(map, 'motion_magnitude'),
    );
  }

  static double _readDouble(Map<String, dynamic> map, String key) {
    final val = map[key];
    if (val is num) return val.toDouble();
    throw FormatException('Expected numeric double value for "$key".');
  }
}
