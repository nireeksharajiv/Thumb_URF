import 'package:flutter/foundation.dart';

import '../models/monitoring_session.dart';
import '../models/sensor_reading.dart';

/// Abstract contract for managing and persisting biomechanical monitoring sessions
/// and raw sensor readings.
///
/// Extends [Listenable] so UI components (such as `SessionsPage`) can rebuild
/// reactively when sessions are saved or removed.
abstract class MonitoringSessionRepository implements Listenable {
  /// Persists a completed [session], optionally with associated [readings].
  Future<void> saveSession(
    MonitoringSession session, {
    List<SensorReading>? readings,
  });

  /// Retrieves all available sessions, ordered newest first.
  Future<List<MonitoringSession>> getSessions();

  /// Retrieves a specific [MonitoringSession] by its [id], or `null` if not found.
  Future<MonitoringSession?> getSessionById(String id);

  /// Deletes a session and its associated sensor readings by [id].
  Future<void> deleteSession(String id);

  /// Persists a batch of raw [readings] for a specific [sessionId].
  Future<void> saveSensorReadings(
    String sessionId,
    List<SensorReading> readings,
  );

  /// Retrieves raw sensor readings associated with [sessionId], ordered by timestamp ascending.
  Future<List<SensorReading>> getSensorReadings(String sessionId);
}
