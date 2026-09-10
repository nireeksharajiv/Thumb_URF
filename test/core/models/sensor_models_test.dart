import 'package:flutter_test/flutter_test.dart';
import 'package:thumb_biomech_monitor_glove/core/models/monitoring_session.dart';
import 'package:thumb_biomech_monitor_glove/core/models/movement_data.dart';
import 'package:thumb_biomech_monitor_glove/core/models/sensor_reading.dart';
import 'package:thumb_biomech_monitor_glove/core/models/sensor_type.dart';
import 'package:thumb_biomech_monitor_glove/core/models/stress_result.dart';

void main() {
  group('SensorReading', () {
    test('creates an immutable timestamped reading', () {
      final reading = SensorReading(
        timestamp: DateTime(2026, 9, 10, 12),
        ipAngle: 32.5,
        mcpAngle: 18,
        force: 4.2,
        angularVelocity: 1.8,
        motionMagnitude: 0.7,
      );

      expect(reading.timestamp.isUtc, isTrue);
      expect(reading.ipAngle, 32.5);
      expect(reading.force, 4.2);
    });

    test('serializes and deserializes safely', () {
      final original = SensorReading(
        timestamp: DateTime.utc(2026, 9, 10, 12, 30),
        ipAngle: 30,
        mcpAngle: 20,
        force: 5,
        angularVelocity: 2,
        motionMagnitude: 1,
      );

      final restored = SensorReading.fromJson(original.toJson());

      expect(restored.timestamp, original.timestamp);
      expect(restored.ipAngle, original.ipAngle);
      expect(restored.mcpAngle, original.mcpAngle);
      expect(restored.force, original.force);
      expect(restored.angularVelocity, original.angularVelocity);
      expect(restored.motionMagnitude, original.motionMagnitude);
    });
  });

  test('SensorType exposes each configured glove sensor', () {
    expect(SensorType.values, hasLength(4));
    expect(SensorType.fsr.location, 'Thumb tip / distal phalanx');
    expect(SensorType.mpu6050.measurement, contains('angular velocity'));
  });

  test('MovementData exposes duration and movement frequency', () {
    final movement = MovementData(
      startTime: DateTime.utc(2026, 9, 10, 12),
      endTime: DateTime.utc(2026, 9, 10, 12, 2),
      movementCount: 6,
    );

    expect(movement.duration, const Duration(minutes: 2));
    expect(movement.movementsPerMinute, 3);
  });

  test('MonitoringSession creates a completed biomechanical summary', () {
    final session = MonitoringSession(
      id: 'session-001',
      startTime: DateTime.utc(2026, 9, 10, 12),
      endTime: DateTime.utc(2026, 9, 10, 12, 5),
      movementCount: 10,
      averageIpAngle: 20,
      maximumIpAngle: 40,
      averageMcpAngle: 15,
      maximumMcpAngle: 30,
      averageForce: 2,
      peakForce: 5,
      averageAngularVelocity: 1.5,
      averageMotionMagnitude: 0.8,
    );

    expect(session.duration, const Duration(minutes: 5));
    expect(session.toJson()['peakForce'], 5);
  });

  test('StressResult retains research loading details', () {
    final result = StressResult(
      score: 42,
      level: StressLevel.moderate,
      contributingFactors: ['Repetitive movement', 'Thumb loading'],
    );

    expect(result.level.label, 'Moderate loading');
    expect(result.contributingFactors, hasLength(2));
    expect(result.toJson()['level'], 'moderate');
  });
}
