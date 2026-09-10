import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_exceptions.dart';
import '../models/monitoring_session.dart';
import '../models/sensor_reading.dart';
import '../models/supabase_mappers.dart';
import 'auth_repository.dart';
import 'local_monitoring_session_repository.dart';
import 'monitoring_session_repository.dart';
import 'supabase_service.dart';

/// Supabase-backed repository for persisting and querying monitoring data on the cloud.
///
/// Implements [MonitoringSessionRepository] and extends [ChangeNotifier].
/// Strictly enforces data ownership by binding rows to the currently authenticated
/// Supabase user ID, and never trusts external or unauthenticated user IDs.
class SupabaseMonitoringSessionRepository extends ChangeNotifier
    implements MonitoringSessionRepository {
  SupabaseMonitoringSessionRepository({
    SupabaseClient? client,
    this.authRepository,
    this.localFallback,
  })  : _customClient = client;

  final SupabaseClient? _customClient;
  final AuthRepository? authRepository;
  final LocalMonitoringSessionRepository? localFallback;

  SupabaseClient? get _client =>
      _customClient ?? SupabaseService.instance.clientOrNull;

  /// Returns the authenticated user's ID, or throws a [SupabaseAuthException]
  /// if no authenticated session exists.
  String _requireUserId({String? explicitUserId}) {
    if (explicitUserId != null && explicitUserId.isNotEmpty) {
      return explicitUserId;
    }
    final uid = authRepository?.currentUser?.id ?? _client?.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      throw const SupabaseAuthException(
        'User must be authenticated to persist or query cloud sessions.',
      );
    }
    return uid;
  }

  @override
  Future<void> saveSession(
    MonitoringSession session, {
    List<SensorReading>? readings,
    String? userId,
  }) async {
    final effectiveUserId = _requireUserId(explicitUserId: userId);
    final client = _requireClient();

    final row = MonitoringSessionSupabaseMapper.toMap(
      session,
      userId: effectiveUserId,
    );

    try {
      await client.from('monitoring_sessions').upsert(row, onConflict: 'id');

      if (readings != null && readings.isNotEmpty) {
        await saveSensorReadings(session.id, readings);
      }

      // Also mirror to local fallback if configured
      if (localFallback != null) {
        await localFallback!.saveSession(session, readings: readings);
      }

      notifyListeners();
    } on PostgrestException catch (e) {
      // If cloud insert fails, try saving to local fallback so data is not lost
      if (localFallback != null) {
        await localFallback!.saveSession(session, readings: readings);
      }
      throw SupabaseRepositoryException(
        'Failed to save monitoring session to cloud.',
        technicalDetails: '${e.message} (Code: ${e.code})',
      );
    } catch (e) {
      if (localFallback != null) {
        await localFallback!.saveSession(session, readings: readings);
      }
      throw SupabaseRepositoryException(
        'Network error saving session. Please check your connection.',
        technicalDetails: e.toString(),
      );
    }
  }

  @override
  Future<List<MonitoringSession>> getSessions() async {
    final effectiveUserId = _requireUserId();
    return fetchSessions(userId: effectiveUserId);
  }

  /// Fetches all completed sessions belonging to [userId], ordered newest first.
  /// Maintained for backwards compatibility with Step 7A tests.
  Future<List<MonitoringSession>> fetchSessions({
    required String userId,
  }) async {
    final client = _requireClient();

    try {
      final data = await client
          .from('monitoring_sessions')
          .select()
          .eq('user_id', userId)
          .order('started_at', ascending: false);

      return (data as List)
          .map((row) => MonitoringSessionSupabaseMapper.fromMap(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList();
    } on PostgrestException catch (e) {
      throw SupabaseRepositoryException(
        'Failed to fetch sessions from cloud.',
        technicalDetails: '${e.message} (Code: ${e.code})',
      );
    } catch (e) {
      throw SupabaseRepositoryException(
        'Network error fetching sessions.',
        technicalDetails: e.toString(),
      );
    }
  }

  @override
  Future<MonitoringSession?> getSessionById(String id) async {
    final effectiveUserId = _requireUserId();
    final client = _requireClient();

    try {
      final data = await client
          .from('monitoring_sessions')
          .select()
          .eq('id', id)
          .eq('user_id', effectiveUserId)
          .maybeSingle();

      if (data == null) return null;
      return MonitoringSessionSupabaseMapper.fromMap(
        Map<String, dynamic>.from(data),
      );
    } on PostgrestException catch (e) {
      throw SupabaseRepositoryException(
        'Failed to fetch session $id from cloud.',
        technicalDetails: '${e.message} (Code: ${e.code})',
      );
    } catch (e) {
      throw SupabaseRepositoryException(
        'Network error fetching session $id.',
        technicalDetails: e.toString(),
      );
    }
  }

  @override
  Future<void> deleteSession(String id) async {
    final effectiveUserId = _requireUserId();
    final client = _requireClient();

    try {
      await client
          .from('monitoring_sessions')
          .delete()
          .eq('id', id)
          .eq('user_id', effectiveUserId);

      if (localFallback != null) {
        await localFallback!.deleteSession(id);
      }

      notifyListeners();
    } on PostgrestException catch (e) {
      throw SupabaseRepositoryException(
        'Failed to delete session from cloud.',
        technicalDetails: '${e.message} (Code: ${e.code})',
      );
    } catch (e) {
      throw SupabaseRepositoryException(
        'Network error deleting session.',
        technicalDetails: e.toString(),
      );
    }
  }

  @override
  Future<void> saveSensorReadings(
    String sessionId,
    List<SensorReading> readings,
  ) async {
    await saveReadings(readings, sessionId: sessionId);
  }

  /// Batches and inserts raw [SensorReading]s into the `sensor_readings` table.
  /// Maintained for backwards compatibility with Step 7A tests.
  Future<void> saveReadings(
    List<SensorReading> readings, {
    required String sessionId,
    int batchSize = 250,
  }) async {
    if (readings.isEmpty) return;
    final client = _requireClient();

    final rows = readings
        .map((r) => SensorReadingSupabaseMapper.toMap(r, sessionId: sessionId))
        .toList();

    try {
      // Idempotency: Remove previous readings for this session to prevent duplicates
      await client.from('sensor_readings').delete().eq('session_id', sessionId);

      // Batch insert in chunks
      for (var i = 0; i < rows.length; i += batchSize) {
        final end = (i + batchSize < rows.length) ? i + batchSize : rows.length;
        final chunk = rows.sublist(i, end);
        await client.from('sensor_readings').insert(chunk);
      }
    } on PostgrestException catch (e) {
      throw SupabaseRepositoryException(
        'Failed to save sensor readings to cloud.',
        technicalDetails: '${e.message} (Code: ${e.code})',
      );
    } catch (e) {
      throw SupabaseRepositoryException(
        'Network error saving sensor readings.',
        technicalDetails: e.toString(),
      );
    }
  }

  @override
  Future<List<SensorReading>> getSensorReadings(String sessionId) async {
    final client = _requireClient();

    try {
      final data = await client
          .from('sensor_readings')
          .select()
          .eq('session_id', sessionId)
          .order('timestamp', ascending: true);

      return (data as List)
          .map((row) => SensorReadingSupabaseMapper.fromMap(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList();
    } on PostgrestException catch (e) {
      throw SupabaseRepositoryException(
        'Failed to fetch sensor readings from cloud.',
        technicalDetails: '${e.message} (Code: ${e.code})',
      );
    } catch (e) {
      throw SupabaseRepositoryException(
        'Network error fetching sensor readings.',
        technicalDetails: e.toString(),
      );
    }
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const SupabaseConfigException(
        'Supabase client is not available. Please ensure Supabase is configured.',
      );
    }
    return client;
  }
}

/// Backwards compatibility alias for [SupabaseMonitoringSessionRepository].
typedef SupabaseSessionRepository = SupabaseMonitoringSessionRepository;
