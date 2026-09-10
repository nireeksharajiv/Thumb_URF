import 'package:flutter_test/flutter_test.dart';
import 'package:thumb_biomech_monitor_glove/core/models/monitoring_session.dart';
import 'package:thumb_biomech_monitor_glove/core/models/sensor_reading.dart';
import 'package:thumb_biomech_monitor_glove/core/models/supabase_mappers.dart';

void main() {
  group('MonitoringSessionSupabaseMapper', () {
    final startTime = DateTime.utc(2026, 9, 10, 10, 0, 0);
    final endTime = DateTime.utc(2026, 9, 10, 10, 5, 30);

    final session = MonitoringSession(
      id: 'test-session-uuid-1',
      startTime: startTime,
      endTime: endTime,
      movementCount: 42,
      averageIpAngle: 35.5,
      maximumIpAngle: 62.0,
      averageMcpAngle: 22.0,
      maximumMcpAngle: 45.0,
      averageForce: 3.2,
      peakForce: 8.5,
      averageAngularVelocity: 110.0,
      averageMotionMagnitude: 2.1,
    );

    test('4. Monitoring models serialize correctly for Supabase', () {
      final map = MonitoringSessionSupabaseMapper.toMap(
        session,
        userId: 'user-uuid-123',
      );

      expect(map['id'], 'test-session-uuid-1');
      expect(map['user_id'], 'user-uuid-123');
      expect(map['started_at'], startTime.toIso8601String());
      expect(map['ended_at'], endTime.toIso8601String());
      expect(map['duration_seconds'], 330); // 5 minutes 30 seconds
      expect(map['movement_count'], 42);
      expect(map['average_ip_angle'], 35.5);
      expect(map['max_ip_angle'], 62.0);
      expect(map['average_mcp_angle'], 22.0);
      expect(map['max_mcp_angle'], 45.0);
      expect(map['average_force'], 3.2);
      expect(map['peak_force'], 8.5);
      expect(map['average_angular_velocity'], 110.0);
      expect(map['average_motion_magnitude'], 2.1);
    });

    test('5. Monitoring models deserialize correctly', () {
      final map = {
        'id': 'session-456',
        'user_id': 'user-uuid-123',
        'started_at': '2026-09-10T10:00:00.000Z',
        'ended_at': '2026-09-10T10:05:30.000Z',
        'duration_seconds': 330,
        'movement_count': 15,
        'average_ip_angle': 30.0,
        'max_ip_angle': 50.0,
        'average_mcp_angle': 20.0,
        'max_mcp_angle': 40.0,
        'average_force': 2.5,
        'peak_force': 6.0,
        'average_angular_velocity': 90.0,
        'average_motion_magnitude': 1.8,
      };

      final deserialized = MonitoringSessionSupabaseMapper.fromMap(map);

      expect(deserialized.id, 'session-456');
      expect(deserialized.startTime.isUtc, isTrue);
      expect(deserialized.endTime.isUtc, isTrue);
      expect(deserialized.movementCount, 15);
      expect(deserialized.averageIpAngle, 30.0);
      expect(deserialized.maximumIpAngle, 50.0);
      expect(deserialized.averageMcpAngle, 20.0);
      expect(deserialized.maximumMcpAngle, 40.0);
      expect(deserialized.averageForce, 2.5);
      expect(deserialized.peakForce, 6.0);
      expect(deserialized.duration, const Duration(minutes: 5, seconds: 30));
    });

    test('6. Repository mapping handles timestamps and timezones correctly', () {
      // Create with non-UTC local DateTime
      final localStart = DateTime(2026, 9, 10, 8, 30, 0);
      final localEnd = DateTime(2026, 9, 10, 8, 35, 0);

      final localSession = MonitoringSession(
        id: 'tz-test',
        startTime: localStart,
        endTime: localEnd,
        movementCount: 5,
        averageIpAngle: 10.0,
        maximumIpAngle: 15.0,
        averageMcpAngle: 10.0,
        maximumMcpAngle: 15.0,
        averageForce: 1.0,
        peakForce: 2.0,
        averageAngularVelocity: 50.0,
        averageMotionMagnitude: 1.0,
      );

      final map = MonitoringSessionSupabaseMapper.toMap(
        localSession,
        userId: 'user-tz',
      );

      expect(map['started_at'], localStart.toUtc().toIso8601String());
      expect(map['ended_at'], localEnd.toUtc().toIso8601String());

      final restored = MonitoringSessionSupabaseMapper.fromMap(map);
      expect(restored.startTime.isUtc, isTrue);
      expect(restored.endTime.isUtc, isTrue);
      expect(restored.startTime, localStart.toUtc());
      expect(restored.endTime, localEnd.toUtc());
    });
  });

  group('SensorReadingSupabaseMapper', () {
    final timestamp = DateTime.utc(2026, 9, 10, 10, 0, 1);
    final reading = SensorReading(
      timestamp: timestamp,
      ipAngle: 42.0,
      mcpAngle: 25.0,
      force: 4.5,
      angularVelocity: 85.0,
      motionMagnitude: 1.4,
    );

    test('Serializes SensorReading correctly for sensor_readings table', () {
      final map = SensorReadingSupabaseMapper.toMap(
        reading,
        sessionId: 'session-123',
        id: 'reading-1',
      );

      expect(map['id'], 'reading-1');
      expect(map['session_id'], 'session-123');
      expect(map['timestamp'], timestamp.toIso8601String());
      expect(map['ip_angle'], 42.0);
      expect(map['mcp_angle'], 25.0);
      expect(map['force'], 4.5);
      expect(map['angular_velocity'], 85.0);
      expect(map['motion_magnitude'], 1.4);
    });

    test('Deserializes SensorReading correctly from row map', () {
      final map = {
        'timestamp': '2026-09-10T10:00:01.000Z',
        'ip_angle': 42.0,
        'mcp_angle': 25.0,
        'force': 4.5,
        'angular_velocity': 85.0,
        'motion_magnitude': 1.4,
      };

      final restored = SensorReadingSupabaseMapper.fromMap(map);
      expect(restored.timestamp, timestamp);
      expect(restored.ipAngle, 42.0);
      expect(restored.mcpAngle, 25.0);
      expect(restored.force, 4.5);
      expect(restored.angularVelocity, 85.0);
      expect(restored.motionMagnitude, 1.4);
    });
  });
}
