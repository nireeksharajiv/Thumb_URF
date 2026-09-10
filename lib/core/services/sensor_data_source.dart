import '../models/sensor_reading.dart';

/// Common lifecycle and reading contract for future Demo and BLE sources.
///
/// Implementations own their transport or simulation details; consumers only
/// observe [readings] and control this lifecycle.
abstract interface class SensorDataSource {
  Stream<SensorReading> get readings;

  Future<void> start();
  Future<void> stop();
  Future<void> pause();
  Future<void> resume();
}
