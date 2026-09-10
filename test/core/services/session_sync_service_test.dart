import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thumb_biomech_monitor_glove/core/errors/supabase_exceptions.dart';
import 'package:thumb_biomech_monitor_glove/core/models/monitoring_session.dart';
import 'package:thumb_biomech_monitor_glove/core/models/sensor_reading.dart';
import 'package:thumb_biomech_monitor_glove/core/models/supabase_mappers.dart';
import 'package:thumb_biomech_monitor_glove/core/models/sync_status.dart';
import 'package:thumb_biomech_monitor_glove/core/services/auth_repository.dart';
import 'package:thumb_biomech_monitor_glove/core/services/local_monitoring_session_repository.dart';
import 'package:thumb_biomech_monitor_glove/core/services/session_sync_service.dart';
import 'package:thumb_biomech_monitor_glove/core/services/supabase_session_repository.dart';

// ---------------------------------------------------------------------------
// Fakes for testing
// ---------------------------------------------------------------------------

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.authenticated = true, this.userId = 'user-123'});

  bool authenticated;
  String userId;

  @override
  bool get isAuthenticated => authenticated;

  @override
  User? get currentUser => authenticated
      ? User(
          id: userId,
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
        )
      : null;

  @override
  Session? get currentSession => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<User?> signIn({required String email, required String password}) async =>
      currentUser;

  @override
  Future<void> signOut() async {
    authenticated = false;
  }

  @override
  Future<User?> signUp({required String email, required String password}) async =>
      currentUser;
}

class FakeCloudSessionRepository extends SupabaseMonitoringSessionRepository {
  FakeCloudSessionRepository({
    AuthRepository? authRepo,
    super.localFallback,
  }) : super(authRepository: authRepo);

  final Map<String, MonitoringSession> cloudSessions = {};
  final Map<String, List<SensorReading>> cloudReadings = {};
  final List<List<SensorReading>> saveReadingsBatches = [];

  bool shouldThrowNetworkError = false;
  String? failureErrorMessage;

  @override
  Future<void> saveSession(
    MonitoringSession session, {
    List<SensorReading>? readings,
    String? userId,
  }) async {
    if (shouldThrowNetworkError) {
      throw SupabaseRepositoryException(
        failureErrorMessage ?? 'Network connection refused.',
      );
    }
    // Idempotent upsert: replaces existing session with same ID
    cloudSessions[session.id] = session;
    if (readings != null) {
      await saveSensorReadings(session.id, readings);
    }
  }

  @override
  Future<void> saveSensorReadings(
    String sessionId,
    List<SensorReading> readings, {
    int batchSize = 250,
  }) async {
    if (shouldThrowNetworkError) {
      throw SupabaseRepositoryException(
        failureErrorMessage ?? 'Network connection refused.',
      );
    }
    // Idempotency: replace existing readings for this session
    cloudReadings[sessionId] = List.from(readings);

    for (var i = 0; i < readings.length; i += batchSize) {
      final end = (i + batchSize < readings.length) ? i + batchSize : readings.length;
      saveReadingsBatches.add(readings.sublist(i, end));
    }
  }

  @override
  Future<List<MonitoringSession>> getSessions() async {
    if (shouldThrowNetworkError) {
      throw SupabaseRepositoryException('Failed to fetch sessions from cloud.');
    }
    return cloudSessions.values.toList();
  }

  @override
  Future<MonitoringSession?> getSessionById(String id) async {
    if (shouldThrowNetworkError) {
      throw SupabaseRepositoryException('Failed to fetch session from cloud.');
    }
    return cloudSessions[id];
  }

  @override
  Future<List<SensorReading>> getSensorReadings(String sessionId) async {
    if (shouldThrowNetworkError) {
      throw SupabaseRepositoryException('Failed to fetch readings from cloud.');
    }
    return cloudReadings[sessionId] ?? [];
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MonitoringSession _createTestSession({
  String id = 'sess-001',
  int movementCount = 10,
  double avgIp = 32.5,
  double maxIp = 55.0,
  double avgMcp = 20.0,
  double maxMcp = 38.0,
  double avgForce = 2.4,
  double peakForce = 5.2,
  double avgVelocity = 12.0,
  double avgMagnitude = 0.65,
}) =>
    MonitoringSession(
      id: id,
      startTime: DateTime.utc(2026, 9, 10, 14, 0, 0),
      endTime: DateTime.utc(2026, 9, 10, 14, 5, 0),
      movementCount: movementCount,
      averageIpAngle: avgIp,
      maximumIpAngle: maxIp,
      averageMcpAngle: avgMcp,
      maximumMcpAngle: maxMcp,
      averageForce: avgForce,
      peakForce: peakForce,
      averageAngularVelocity: avgVelocity,
      averageMotionMagnitude: avgMagnitude,
    );

List<SensorReading> _createTestReadings(String sessionId, int count) {
  final start = DateTime.utc(2026, 9, 10, 14, 0, 0);
  return List.generate(
    count,
    (i) => SensorReading(
      timestamp: start.add(Duration(milliseconds: i * 100)),
      ipAngle: 25.0 + (i % 10),
      mcpAngle: 15.0 + (i % 8),
      force: 1.0 + ((i % 5) * 0.5),
      angularVelocity: 5.0 + (i % 4),
      motionMagnitude: 0.3 + ((i % 3) * 0.1),
    ),
  );
}

// ---------------------------------------------------------------------------
// Test Suite
// ---------------------------------------------------------------------------

void main() {
  late Directory tempDir;
  late File tempFile;
  late LocalMonitoringSessionRepository localRepo;
  late FakeCloudSessionRepository cloudRepo;
  late FakeAuthRepository authRepo;
  late SessionSyncService syncService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sync_test_');
    tempFile = File('${tempDir.path}/sessions.json');
    localRepo = LocalMonitoringSessionRepository(storageFile: tempFile);
    await localRepo.init();
    authRepo = FakeAuthRepository(authenticated: true, userId: 'user-abc');
    cloudRepo = FakeCloudSessionRepository(authRepo: authRepo, localFallback: localRepo);
    syncService = SessionSyncService(
      localRepository: localRepo,
      cloudRepository: cloudRepo,
      authRepository: authRepo,
    );
  });

  tearDown(() async {
    syncService.dispose();
    cloudRepo.dispose();
    localRepo.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SessionSyncService & Cloud Synchronization', () {
    // Scenario 1: Authenticated session upload creates correct cloud record
    test('1. Authenticated session upload creates correct cloud record', () async {
      final session = _createTestSession(id: 'sess-1');
      await localRepo.saveSession(session);

      final result = await syncService.syncSession('sess-1');

      expect(result.state, equals(SyncState.synced));
      expect(result.syncedAt, isNotNull);
      expect(cloudRepo.cloudSessions.containsKey('sess-1'), isTrue);
      expect(cloudRepo.cloudSessions['sess-1']!.id, equals('sess-1'));
    });

    // Scenario 2: Unauthenticated session upload is rejected cleanly
    test('2. Unauthenticated session upload is rejected cleanly', () async {
      authRepo.authenticated = false;
      final session = _createTestSession(id: 'sess-unauth');
      await localRepo.saveSession(session);

      final result = await syncService.syncSession('sess-unauth');

      expect(result.state, equals(SyncState.syncFailed));
      expect(result.errorMessage, contains('Authentication required'));
      expect(cloudRepo.cloudSessions.containsKey('sess-unauth'), isFalse);
    });

    // Scenario 3: Reading upload maps all fields properly
    test('3. Reading upload maps all fields properly to Supabase schema', () {
      final reading = SensorReading(
        timestamp: DateTime.utc(2026, 9, 10, 12, 0, 0),
        ipAngle: 45.5,
        mcpAngle: 30.2,
        force: 3.8,
        angularVelocity: 14.2,
        motionMagnitude: 0.75,
      );

      final map = SensorReadingSupabaseMapper.toMap(reading, sessionId: 'sess-3');

      expect(map['session_id'], equals('sess-3'));
      expect(map['timestamp'], equals('2026-09-10T12:00:00.000Z'));
      expect(map['ip_angle'], equals(45.5));
      expect(map['mcp_angle'], equals(30.2));
      expect(map['force'], equals(3.8));
      expect(map['angular_velocity'], equals(14.2));
      expect(map['motion_magnitude'], equals(0.75));
    });

    // Scenario 4: Batch reading upload handles chunks correctly
    test('4. Batch reading upload handles chunks correctly with default batch size', () async {
      final session = _createTestSession(id: 'sess-chunks');
      final readings = _createTestReadings('sess-chunks', 600);
      await localRepo.saveSession(session, readings: readings);

      final result = await syncService.syncSession('sess-chunks');

      expect(result.state, equals(SyncState.synced));
      expect(cloudRepo.cloudReadings['sess-chunks']?.length, equals(600));
      // 600 readings chunked at 250: [250, 250, 100] = 3 batches
      expect(cloudRepo.saveReadingsBatches.length, equals(3));
      expect(cloudRepo.saveReadingsBatches[0].length, equals(250));
      expect(cloudRepo.saveReadingsBatches[1].length, equals(250));
      expect(cloudRepo.saveReadingsBatches[2].length, equals(100));
    });

    // Scenario 5: Cloud session download maps all fields back to MonitoringSession correctly
    test('5. Cloud session download maps all fields back to MonitoringSession correctly', () {
      final original = _createTestSession(id: 'sess-map-test');
      final map = MonitoringSessionSupabaseMapper.toMap(original, userId: 'usr-99');
      final restored = MonitoringSessionSupabaseMapper.fromMap(map);

      expect(restored.id, equals(original.id));
      expect(restored.startTime, equals(original.startTime));
      expect(restored.endTime, equals(original.endTime));
      expect(restored.movementCount, equals(original.movementCount));
      expect(restored.averageIpAngle, closeTo(original.averageIpAngle, 0.001));
      expect(restored.maximumIpAngle, closeTo(original.maximumIpAngle, 0.001));
      expect(restored.averageMcpAngle, closeTo(original.averageMcpAngle, 0.001));
      expect(restored.maximumMcpAngle, closeTo(original.maximumMcpAngle, 0.001));
      expect(restored.averageForce, closeTo(original.averageForce, 0.001));
      expect(restored.peakForce, closeTo(original.peakForce, 0.001));
      expect(restored.averageAngularVelocity, closeTo(original.averageAngularVelocity, 0.001));
      expect(restored.averageMotionMagnitude, closeTo(original.averageMotionMagnitude, 0.001));
    });

    // Scenario 6: Cloud readings download preserves timestamps, order, and sensor channels
    test('6. Cloud readings download preserves timestamps, order, and sensor channels', () {
      final original = SensorReading(
        timestamp: DateTime.utc(2026, 9, 10, 15, 30, 45),
        ipAngle: 50.0,
        mcpAngle: 25.0,
        force: 4.5,
        angularVelocity: 16.0,
        motionMagnitude: 0.82,
      );

      final map = SensorReadingSupabaseMapper.toMap(original, sessionId: 'sess-6');
      final restored = SensorReadingSupabaseMapper.fromMap(map);

      expect(restored.timestamp, equals(original.timestamp));
      expect(restored.ipAngle, equals(50.0));
      expect(restored.mcpAngle, equals(25.0));
      expect(restored.force, equals(4.5));
      expect(restored.angularVelocity, equals(16.0));
      expect(restored.motionMagnitude, equals(0.82));
    });

    // Scenario 7: Duplicate session upload is idempotent (upsert/no duplication)
    test('7. Duplicate session upload is idempotent (re-syncing updates without duplicating)', () async {
      final session = _createTestSession(id: 'sess-dup');
      await localRepo.saveSession(session);

      // First sync
      final first = await syncService.syncSession('sess-dup');
      expect(first.state, equals(SyncState.synced));
      expect(cloudRepo.cloudSessions.length, equals(1));

      // Re-sync the exact same session
      final second = await syncService.syncSession('sess-dup');
      expect(second.state, equals(SyncState.synced));
      expect(cloudRepo.cloudSessions.length, equals(1)); // No duplicate row
    });

    // Scenario 8: Duplicate reading sync replaces/avoids duplicate time-series points
    test('8. Duplicate reading sync replaces/avoids duplicate time-series points', () async {
      final session = _createTestSession(id: 'sess-readings-dup');
      final readings = _createTestReadings('sess-readings-dup', 10);
      await localRepo.saveSession(session, readings: readings);

      await syncService.syncSession('sess-readings-dup');
      expect(cloudRepo.cloudReadings['sess-readings-dup']!.length, equals(10));

      // Re-sync with updated/same readings
      await syncService.syncSession('sess-readings-dup');
      expect(cloudRepo.cloudReadings['sess-readings-dup']!.length, equals(10)); // Still 10, not 20
    });

    // Scenario 9: Network failure leaves local session intact
    test('9. Network failure leaves local session intact without dropping data', () async {
      final session = _createTestSession(id: 'sess-fail');
      final readings = _createTestReadings('sess-fail', 20);
      await localRepo.saveSession(session, readings: readings);

      cloudRepo.shouldThrowNetworkError = true;
      cloudRepo.failureErrorMessage = 'SocketException: OS Error 10061 (Connection refused)';

      final result = await syncService.syncSession('sess-fail');

      expect(result.state, equals(SyncState.syncFailed));
      // Local session and readings must still exist
      final localSession = await localRepo.getSessionById('sess-fail');
      final localReadings = await localRepo.getSensorReadings('sess-fail');
      expect(localSession, isNotNull);
      expect(localReadings.length, equals(20));
    });

    // Scenario 10: Sync failure reports meaningful error to user/caller
    test('10. Sync failure reports meaningful error to user/caller', () async {
      final session = _createTestSession(id: 'sess-err');
      await localRepo.saveSession(session);

      cloudRepo.shouldThrowNetworkError = true;
      cloudRepo.failureErrorMessage = 'Server timed out responding to upload request.';

      final result = await syncService.syncSession('sess-err');

      expect(result.state, equals(SyncState.syncFailed));
      expect(result.errorMessage, contains('Server timed out responding to upload request.'));
    });

    // Scenario 11: Empty session (no readings) syncs session record safely
    test('11. Empty session (no readings) syncs session record safely', () async {
      final session = _createTestSession(id: 'sess-empty');
      await localRepo.saveSession(session, readings: []);

      final result = await syncService.syncSession('sess-empty');

      expect(result.state, equals(SyncState.synced));
      expect(cloudRepo.cloudSessions.containsKey('sess-empty'), isTrue);
      expect(cloudRepo.cloudReadings['sess-empty'] ?? [], isEmpty);
    });

    // Scenario 12: Large reading count (500+ readings) syncs successfully via chunking
    test('12. Large reading count (550 readings) syncs successfully via chunking', () async {
      final session = _createTestSession(id: 'sess-large');
      final readings = _createTestReadings('sess-large', 550);
      await localRepo.saveSession(session, readings: readings);

      final result = await syncService.syncSession('sess-large');

      expect(result.state, equals(SyncState.synced));
      expect(cloudRepo.cloudReadings['sess-large']?.length, equals(550));
      // 550 readings / 250 chunk size = 3 chunks (250, 250, 50)
      expect(cloudRepo.saveReadingsBatches.length, equals(3));
      expect(cloudRepo.saveReadingsBatches[2].length, equals(50));
    });

    // Scenario 13: Sync service correctly transitions sync state (localOnly -> syncing -> synced)
    test('13. Sync service correctly transitions sync state (localOnly -> syncing -> synced)', () async {
      final session = _createTestSession(id: 'sess-trans');
      await localRepo.saveSession(session);

      expect(syncService.getSyncState('sess-trans'), equals(SyncState.localOnly));

      final statesObserved = <SyncState>[];
      syncService.addListener(() {
        statesObserved.add(syncService.getSyncState('sess-trans'));
      });

      await syncService.syncSession('sess-trans');

      expect(statesObserved, contains(SyncState.syncing));
      expect(statesObserved.last, equals(SyncState.synced));
    });

    // Scenario 14: Sync service transitions to syncFailed on cloud error
    test('14. Sync service transitions to syncFailed on cloud error', () async {
      final session = _createTestSession(id: 'sess-trans-err');
      await localRepo.saveSession(session);

      cloudRepo.shouldThrowNetworkError = true;

      final statesObserved = <SyncState>[];
      syncService.addListener(() {
        statesObserved.add(syncService.getSyncState('sess-trans-err'));
      });

      await syncService.syncSession('sess-trans-err');

      expect(statesObserved, contains(SyncState.syncing));
      expect(statesObserved.last, equals(SyncState.syncFailed));
    });

    // Scenario 15: Sync all un-synced sessions processes multiple sessions
    test('15. Sync all un-synced sessions processes multiple sessions', () async {
      final sess1 = _createTestSession(id: 'sess-all-1');
      final sess2 = _createTestSession(id: 'sess-all-2');
      final sess3 = _createTestSession(id: 'sess-all-3');
      await localRepo.saveSession(sess1);
      await localRepo.saveSession(sess2);
      await localRepo.saveSession(sess3);

      final count = await syncService.syncAllUnsynced();

      expect(count, equals(3));
      expect(cloudRepo.cloudSessions.length, equals(3));
      expect(syncService.getSyncState('sess-all-1'), equals(SyncState.synced));
      expect(syncService.getSyncState('sess-all-2'), equals(SyncState.synced));
      expect(syncService.getSyncState('sess-all-3'), equals(SyncState.synced));

      // Calling again should sync 0 because all are already synced
      final countAgain = await syncService.syncAllUnsynced();
      expect(countAgain, equals(0));
    });

    // Scenario 16: Demo / unauthenticated mode operates without crash and marks as unauthenticated
    test('16. Demo / unauthenticated mode operates without crash and marks as unauthenticated', () async {
      final demoSync = SessionSyncService(
        localRepository: localRepo,
        cloudRepository: cloudRepo,
        authRepository: null, // Demo mode: no auth repository
      );

      final session = _createTestSession(id: 'sess-demo');
      await localRepo.saveSession(session);

      final result = await demoSync.syncSession('sess-demo');

      expect(result.state, equals(SyncState.syncFailed));
      expect(result.errorMessage, contains('Authentication required'));
      expect(demoSync.getSyncState('sess-demo'), equals(SyncState.syncFailed));

      demoSync.dispose();
    });
  });
}
