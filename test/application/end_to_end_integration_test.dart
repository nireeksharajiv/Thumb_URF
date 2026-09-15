import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thumb_biomech_monitor_glove/core/models/monitoring_session.dart';
import 'package:thumb_biomech_monitor_glove/core/models/sensor_reading.dart';
import 'package:thumb_biomech_monitor_glove/core/models/sync_status.dart';
import 'package:thumb_biomech_monitor_glove/core/services/auth_repository.dart';
import 'package:thumb_biomech_monitor_glove/core/services/local_monitoring_session_repository.dart';
import 'package:thumb_biomech_monitor_glove/core/services/monitoring_session_repository.dart';
import 'package:thumb_biomech_monitor_glove/core/services/sensor_data_source.dart';
import 'package:thumb_biomech_monitor_glove/core/services/session_sync_service.dart';
import 'package:thumb_biomech_monitor_glove/features/analytics/application/analytics_service.dart';
import 'package:thumb_biomech_monitor_glove/features/analytics/application/biomechanical_analysis_service.dart';
import 'package:thumb_biomech_monitor_glove/features/analytics/application/research_exposure_index_service.dart';
import 'package:thumb_biomech_monitor_glove/features/analytics/domain/models/biomechanical_analysis.dart';
import 'package:thumb_biomech_monitor_glove/features/analytics/domain/models/research_exposure_index.dart';
import 'package:thumb_biomech_monitor_glove/features/auth/presentation/auth_gate.dart';
import 'package:thumb_biomech_monitor_glove/features/monitoring/application/monitoring_controller.dart';
import 'package:thumb_biomech_monitor_glove/features/recommendations/application/recommendation_service.dart';
import 'package:thumb_biomech_monitor_glove/features/recommendations/domain/models/research_recommendation.dart';
import 'package:thumb_biomech_monitor_glove/features/settings/application/settings_service.dart';

// ── Test doubles ─────────────────────────────────────────────────────────────

class _FakeAuthRepo implements AuthRepository {
  _FakeAuthRepo({this.authenticated = false});
  bool authenticated;
  String? email;
  final _controller = StreamController<AuthState>.broadcast();

  @override
  bool get isAuthenticated => authenticated;

  @override
  User? get currentUser => authenticated
      ? User(
          id: 'test-user-id',
          email: email ?? 'researcher@lab.org',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
        )
      : null;

  @override
  Session? get currentSession => null;

  @override
  Stream<AuthState> get authStateChanges => _controller.stream;

  @override
  Future<User?> signIn({required String email, required String password}) async {
    authenticated = true;
    this.email = email;
    _controller.add(AuthState(AuthChangeEvent.signedIn, null));
    return currentUser;
  }

  @override
  Future<User?> signUp({required String email, required String password}) async {
    authenticated = true;
    this.email = email;
    _controller.add(AuthState(AuthChangeEvent.signedIn, null));
    return currentUser;
  }

  @override
  Future<void> signOut() async {
    authenticated = false;
    email = null;
    _controller.add(AuthState(AuthChangeEvent.signedOut, null));
  }
}

class _InMemoryCloudRepo extends ChangeNotifier implements MonitoringSessionRepository {
  final Map<String, MonitoringSession> sessions = {};
  final Map<String, List<SensorReading>> readings = {};
  bool failNext = false;

  @override
  Future<void> saveSession(MonitoringSession session, {List<SensorReading>? readings}) async {
    if (failNext) throw const SocketException('Cloud unavailable (simulated network failure)');
    sessions[session.id] = session;
    if (readings != null) this.readings[session.id] = readings;
    notifyListeners();
  }

  @override
  Future<List<MonitoringSession>> getSessions() async => sessions.values.toList();

  @override
  Future<MonitoringSession?> getSessionById(String id) async => sessions[id];

  @override
  Future<void> deleteSession(String id) async {
    sessions.remove(id);
    readings.remove(id);
    notifyListeners();
  }

  @override
  Future<void> saveSensorReadings(String sessionId, List<SensorReading> r) async {
    if (failNext) throw const SocketException('Cloud unavailable');
    readings[sessionId] = r;
  }

  @override
  Future<List<SensorReading>> getSensorReadings(String sessionId) async => readings[sessionId] ?? const [];
}

class _ControlledDataSource implements SensorDataSource {
  final _ctrl = StreamController<SensorReading>.broadcast();
  bool paused = false;
  bool stopped = true;

  @override
  Stream<SensorReading> get readings => _ctrl.stream;

  void emit(SensorReading r) {
    if (!paused && !stopped) _ctrl.add(r);
  }

  @override
  Future<void> start() async {
    stopped = false;
    paused = false;
  }

  @override
  Future<void> pause() async {
    paused = true;
  }

  @override
  Future<void> resume() async {
    paused = false;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    paused = false;
  }

  Future<void> dispose() async {
    await _ctrl.close();
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

SensorReading _createReading({
  required DateTime timestamp,
  double force = 2.0,
  double angularVelocity = 20.0,
  double ipAngle = 20.0,
  double mcpAngle = 15.0,
  double motionMagnitude = 0.5,
}) =>
    SensorReading(
      timestamp: timestamp,
      force: force,
      angularVelocity: angularVelocity,
      ipAngle: ipAngle,
      mcpAngle: mcpAngle,
      motionMagnitude: motionMagnitude,
    );

void main() {
  group('Step 14: End-to-End Software Integration & Validation', () {
    late Directory tempDir;
    late File settingsFile;
    late File sessionFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('e2e_integration_test_');
      settingsFile = File('${tempDir.path}/settings.json');
      sessionFile = File('${tempDir.path}/sessions.json');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    // ── 1. Settings threshold propagation ─────────────────────────────────────
    test('1. Settings threshold propagation alters downstream biomech, REI, and recommendations', () async {
      final settingsService = SettingsService(storageFile: settingsFile);
      await settingsService.init();

      // Configure non-default research baselines
      await settingsService.updateForceThreshold(4.0); // Default 2.5 N
      await settingsService.updateAngularVelocityThreshold(60.0); // Default 40.0 °/s
      await settingsService.updateRefMovementsPerMinute(50.0); // Default 30.0 /min

      final localRepo = LocalMonitoringSessionRepository(isInitialized: true);
      final t0 = DateTime.utc(2026, 9, 10, 10, 0, 0);

      // Create a 10-second session with readings between 3.0 N and 5.0 N
      final readings = List.generate(
        10,
        (i) => _createReading(
          timestamp: t0.add(Duration(seconds: i)),
          force: 3.5, // Above default 2.5 N, but below configured 4.0 N!
          angularVelocity: 45.0, // Above default 40.0 °/s, but below configured 60.0 °/s!
        ),
      );

      final session = MonitoringSession(
        id: 'sess-prop-1',
        startTime: t0,
        endTime: t0.add(const Duration(seconds: 10)),
        movementCount: 5,
        averageIpAngle: 25.0,
        maximumIpAngle: 40.0,
        averageMcpAngle: 15.0,
        maximumMcpAngle: 25.0,
        averageForce: 3.5,
        peakForce: 3.5,
        averageAngularVelocity: 45.0,
        averageMotionMagnitude: 0.5,
      );

      await localRepo.saveSession(session, readings: readings);

      final biomechService = BiomechanicalAnalysisService(localRepo);
      final settings = settingsService.settings;

      // Analysis with configured settings
      final configuredBiomech = await biomechService.analyzeSession(
        session.id,
        config: BiomechanicalAnalysisConfig(
          forceThreshold: settings.forceThreshold,
          angularVelocityThreshold: settings.angularVelocityThreshold,
        ),
      );

      // Analysis with baseline defaults
      final defaultBiomech = await biomechService.analyzeSession(
        session.id,
        config: const BiomechanicalAnalysisConfig(),
      );

      // Under default (2.5 N), 3.5 N is an exceedance; under configured (4.0 N), 3.5 N is NOT!
      expect(defaultBiomech.forceThresholdExceedancePercentage, greaterThan(0));
      expect(configuredBiomech.forceThresholdExceedancePercentage, equals(0));

      // REI calculation propagates configured reference frequency
      final configuredREI = ResearchExposureIndexService.calculate(
        configuredBiomech,
        config: ResearchExposureIndexConfig(refMovementsPerMinute: settings.refMovementsPerMinute),
      );
      final defaultREI = ResearchExposureIndexService.calculate(defaultBiomech);

      expect(configuredREI.movementComponent, isNot(equals(defaultREI.movementComponent)));

      // Recommendations engine propagation
      const recService = RecommendationService();
      final configuredRecs = recService.generateRecommendations(
        configuredBiomech,
        config: RecommendationConfig(refMovementsPerMinute: settings.refMovementsPerMinute),
      );
      final defaultRecs = recService.generateRecommendations(defaultBiomech);

      expect(configuredRecs, isNotNull);
      expect(defaultRecs, isNotNull);
    });

    // ── 2. Auto cloud sync enabled ────────────────────────────────────────────
    test('2. Auto cloud sync enabled automatically synchronizes completed session when authenticated', () async {
      final settingsService = SettingsService(storageFile: settingsFile);
      await settingsService.init();
      await settingsService.updateAutoCloudSync(true);

      final localRepo = LocalMonitoringSessionRepository(isInitialized: true);
      final cloudRepo = _InMemoryCloudRepo();
      final authRepo = _FakeAuthRepo(authenticated: true);
      final syncService = SessionSyncService(
        localRepository: localRepo,
        cloudRepository: cloudRepo,
        authRepository: authRepo,
      );

      final source = _ControlledDataSource();
      final controller = MonitoringController(
        source,
        repository: localRepo,
        fallbackRepository: localRepo,
        settingsService: settingsService,
        syncService: syncService,
        authRepository: authRepo,
      );

      await controller.start();
      source.emit(_createReading(timestamp: DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await controller.stop();

      final sessionId = controller.lastCompletedSession!.id;

      // Verify automatically synced
      expect(syncService.getSyncState(sessionId), SyncState.synced);
      expect(cloudRepo.sessions.containsKey(sessionId), isTrue);
    });

    // ── 3. Auto cloud sync disabled ───────────────────────────────────────────
    test('3. Auto cloud sync disabled persists locally and does NOT upload automatically', () async {
      final settingsService = SettingsService(storageFile: settingsFile);
      await settingsService.init();
      await settingsService.updateAutoCloudSync(false);

      final localRepo = LocalMonitoringSessionRepository(isInitialized: true);
      final cloudRepo = _InMemoryCloudRepo();
      final authRepo = _FakeAuthRepo(authenticated: true);
      final syncService = SessionSyncService(
        localRepository: localRepo,
        cloudRepository: cloudRepo,
        authRepository: authRepo,
      );

      final source = _ControlledDataSource();
      final controller = MonitoringController(
        source,
        repository: localRepo,
        fallbackRepository: localRepo,
        settingsService: settingsService,
        syncService: syncService,
        authRepository: authRepo,
      );

      await controller.start();
      source.emit(_createReading(timestamp: DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await controller.stop();

      final sessionId = controller.lastCompletedSession!.id;

      // Verify saved locally, but not uploaded
      expect(localRepo.sessions.any((s) => s.id == sessionId), isTrue);
      expect(cloudRepo.sessions.containsKey(sessionId), isFalse);
      expect(syncService.getSyncState(sessionId), SyncState.localOnly);

      // Manual sync still succeeds
      await syncService.syncSession(sessionId);
      expect(syncService.getSyncState(sessionId), SyncState.synced);
      expect(cloudRepo.sessions.containsKey(sessionId), isTrue);
    });

    // ── 4. Demo mode ──────────────────────────────────────────────────────────
    test('4. Demo mode operates end-to-end without credentials and skips cloud upload safely', () async {
      final settingsService = SettingsService(isInitialized: true);
      final localRepo = LocalMonitoringSessionRepository(isInitialized: true);
      final cloudRepo = _InMemoryCloudRepo();
      final authRepo = _FakeAuthRepo(authenticated: false); // Offline / Demo
      final syncService = SessionSyncService(
        localRepository: localRepo,
        cloudRepository: cloudRepo,
        authRepository: authRepo,
      );

      final source = _ControlledDataSource();
      final controller = MonitoringController(
        source,
        repository: localRepo,
        settingsService: settingsService,
        syncService: syncService,
        authRepository: authRepo,
      );

      await controller.start();
      source.emit(_createReading(timestamp: DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await controller.stop();

      final session = controller.lastCompletedSession!;
      expect(session, isNotNull);
      expect(localRepo.sessions.length, 1);
      expect(cloudRepo.sessions.isEmpty, isTrue);

      // Analytics and Recommendations work on the local session
      final analyticsService = AnalyticsService(localRepo);
      final biomechService = BiomechanicalAnalysisService(localRepo);
      final analytics = await analyticsService.computeSessionAnalytics(session.id);
      final biomech = await biomechService.analyzeSession(session.id);
      final rei = ResearchExposureIndexService.calculate(biomech);
      const recService = RecommendationService();
      final recs = recService.generateRecommendations(biomech);

      expect(analytics, isNotNull);
      expect(biomech, isNotNull);
      expect(rei, isNotNull);
      expect(recs, isNotNull);
    });

    // ── 5. Session persistence ────────────────────────────────────────────────
    test('5. Session metadata and raw readings survive repository reload across separate instances', () async {
      final repo1 = LocalMonitoringSessionRepository(storageFile: sessionFile);
      await repo1.init();

      final t0 = DateTime.utc(2026, 9, 10, 12, 0, 0);
      final session = MonitoringSession(
        id: 'persisted-123',
        startTime: t0,
        endTime: t0.add(const Duration(minutes: 5)),
        movementCount: 18,
        averageIpAngle: 28.0,
        maximumIpAngle: 45.0,
        averageMcpAngle: 18.0,
        maximumMcpAngle: 30.0,
        averageForce: 2.2,
        peakForce: 5.0,
        averageAngularVelocity: 35.0,
        averageMotionMagnitude: 0.6,
      );

      final readings = [
        _createReading(timestamp: t0, force: 1.5),
        _createReading(timestamp: t0.add(const Duration(seconds: 1)), force: 3.2),
      ];

      await repo1.saveSession(session, readings: readings);

      // Recreate repository from same disk storage file
      final repo2 = LocalMonitoringSessionRepository(storageFile: sessionFile);
      await repo2.init();

      final restoredSession = await repo2.getSessionById('persisted-123');
      final restoredReadings = await repo2.getSensorReadings('persisted-123');

      expect(restoredSession, isNotNull);
      expect(restoredSession!.movementCount, 18);
      expect(restoredSession.averageForce, 2.2);
      expect(restoredReadings.length, 2);
      expect(restoredReadings[1].force, 3.2);
    });

    // ── 6. Offline sync failure ───────────────────────────────────────────────
    test('6. Offline sync failure marks syncFailed and preserves local session data untouched', () async {
      final localRepo = LocalMonitoringSessionRepository(isInitialized: true);
      final cloudRepo = _InMemoryCloudRepo();
      final authRepo = _FakeAuthRepo(authenticated: true);
      final syncService = SessionSyncService(
        localRepository: localRepo,
        cloudRepository: cloudRepo,
        authRepository: authRepo,
      );

      final session = MonitoringSession(
        id: 'sess-fail-1',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        movementCount: 2,
        averageIpAngle: 20,
        maximumIpAngle: 30,
        averageMcpAngle: 15,
        maximumMcpAngle: 25,
        averageForce: 2,
        peakForce: 3,
        averageAngularVelocity: 25,
        averageMotionMagnitude: 0.3,
      );

      await localRepo.saveSession(session, readings: [_createReading(timestamp: DateTime.now())]);

      // Simulate network failure
      cloudRepo.failNext = true;

      final info = await syncService.syncSession('sess-fail-1');

      expect(info.state, SyncState.syncFailed);
      expect(syncService.getSyncState('sess-fail-1'), SyncState.syncFailed);
      expect(localRepo.sessions.length, 1);
      expect((await localRepo.getSensorReadings('sess-fail-1')).length, 1);
    });

    // ── 7. Retry sync ─────────────────────────────────────────────────────────
    test('7. Retrying a failed sync successfully updates to synced once network is restored', () async {
      final localRepo = LocalMonitoringSessionRepository(isInitialized: true);
      final cloudRepo = _InMemoryCloudRepo();
      final authRepo = _FakeAuthRepo(authenticated: true);
      final syncService = SessionSyncService(
        localRepository: localRepo,
        cloudRepository: cloudRepo,
        authRepository: authRepo,
      );

      final session = MonitoringSession(
        id: 'retry-sess',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        movementCount: 4,
        averageIpAngle: 22,
        maximumIpAngle: 35,
        averageMcpAngle: 16,
        maximumMcpAngle: 26,
        averageForce: 2.1,
        peakForce: 4.0,
        averageAngularVelocity: 30,
        averageMotionMagnitude: 0.4,
      );
      await localRepo.saveSession(session);

      // Fail first
      cloudRepo.failNext = true;
      await syncService.syncSession('retry-sess');
      expect(syncService.getSyncState('retry-sess'), SyncState.syncFailed);

      // Network restored
      cloudRepo.failNext = false;
      final retried = await syncService.syncSession('retry-sess');

      expect(retried.state, SyncState.synced);
      expect(syncService.getSyncState('retry-sess'), SyncState.synced);
      expect(cloudRepo.sessions.containsKey('retry-sess'), isTrue);
    });

    // ── 8, 9, 10. Session switching consistency ───────────────────────────────
    test('8, 9, 10. Session switching consistency: analytics and recommendations reflect the selected session', () async {
      final repo = LocalMonitoringSessionRepository(isInitialized: true);
      final t0 = DateTime.utc(2026, 9, 10, 10, 0, 0);

      // Session A: High movement, high force
      final sessionA = MonitoringSession(
        id: 'session-A',
        startTime: t0,
        endTime: t0.add(const Duration(minutes: 5)),
        movementCount: 40,
        averageIpAngle: 35,
        maximumIpAngle: 55,
        averageMcpAngle: 25,
        maximumMcpAngle: 40,
        averageForce: 6.0,
        peakForce: 9.0,
        averageAngularVelocity: 75,
        averageMotionMagnitude: 0.8,
      );
      final readingsA = [
        _createReading(timestamp: t0, force: 6.0),
        _createReading(timestamp: t0.add(const Duration(seconds: 1)), force: 9.0),
      ];
      await repo.saveSession(sessionA, readings: readingsA);

      // Session B: Low movement, gentle force
      final sessionB = MonitoringSession(
        id: 'session-B',
        startTime: t0.add(const Duration(hours: 1)),
        endTime: t0.add(const Duration(hours: 1, minutes: 5)),
        movementCount: 5,
        averageIpAngle: 15,
        maximumIpAngle: 25,
        averageMcpAngle: 10,
        maximumMcpAngle: 20,
        averageForce: 1.2,
        peakForce: 2.0,
        averageAngularVelocity: 15,
        averageMotionMagnitude: 0.2,
      );
      final readingsB = [
        _createReading(timestamp: t0.add(const Duration(hours: 1)), force: 1.2),
        _createReading(timestamp: t0.add(const Duration(hours: 1, seconds: 1)), force: 2.0),
      ];
      await repo.saveSession(sessionB, readings: readingsB);

      final analyticsService = AnalyticsService(repo);
      final biomechService = BiomechanicalAnalysisService(repo);
      const recService = RecommendationService();

      // Query A
      final analA = await analyticsService.computeSessionAnalytics('session-A');
      final biomechA = await biomechService.analyzeSession('session-A');
      final reiA = ResearchExposureIndexService.calculate(biomechA);
      final recsA = recService.generateRecommendations(biomechA);

      expect(analA.movementCount, 40);
      expect(analA.averageForce, 7.5);
      expect(reiA.forceComponent, greaterThan(0));

      // Switch to B
      final analB = await analyticsService.computeSessionAnalytics('session-B');
      final biomechB = await biomechService.analyzeSession('session-B');
      final reiB = ResearchExposureIndexService.calculate(biomechB);
      final recsB = recService.generateRecommendations(biomechB);

      expect(analB.movementCount, 5);
      expect(analB.averageForce, 1.6);
      expect(reiA.forceComponent, greaterThan(reiB.forceComponent));
      expect(reiA.overallIndex, greaterThan(reiB.overallIndex));
      expect(recsB, isNot(equals(recsA)));

      // Switch back to A
      final analA2 = await analyticsService.computeSessionAnalytics('session-A');
      expect(analA2.movementCount, 40);
      expect(analA2.averageForce, 7.5);
    });

    // ── 11. Empty state behavior ──────────────────────────────────────────────
    test('11. Services handle empty session repository gracefully without errors or exceptions', () async {
      final emptyRepo = LocalMonitoringSessionRepository(isInitialized: true);
      final biomechService = BiomechanicalAnalysisService(emptyRepo);

      final allBiomech = await biomechService.analyzeAllSessions();
      expect(allBiomech.isEmpty, isTrue);

      expect(await emptyRepo.getSessions(), isEmpty);
      expect(await emptyRepo.getSessionById('non-existent'), isNull);
      expect(await emptyRepo.getSensorReadings('non-existent'), isEmpty);
    });

    // ── 12. Authentication state transition ───────────────────────────────────
    testWidgets('12. Authentication state transitions cleanly between LoginPage and AppNavigationShell', (tester) async {
      final auth = _FakeAuthRepo(authenticated: false);

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authRepository: auth,
            settingsService: SettingsService(isInitialized: true),
          ),
        ),
      );

      // Initially shows Login Page
      expect(find.text('ThumbTrace'), findsOneWidget);
      expect(find.text('Biomechanical Thumb Monitoring'), findsOneWidget);

      // Sign In
      await auth.signIn(email: 'researcher@lab.org', password: 'password123');
      // Use pump+Duration: HomePageState.initState triggers async session loading
      // which prevents pumpAndSettle from settling in test environments.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Shows Navigation Shell — Home tab label in the bottom nav is the
      // most reliable post-login indicator that is independent of page copy.
      expect(find.text('Home'), findsOneWidget);

      // Sign Out
      await auth.signOut();
      await tester.pumpAndSettle();

      // Returns to Login Page
      expect(find.text('ThumbTrace'), findsOneWidget);
      expect(find.text('Biomechanical Thumb Monitoring'), findsOneWidget);
    });

    // ── 13. Theme persistence/change ──────────────────────────────────────────
    test('13. Theme mode updates and persists across service recreation', () async {
      final service1 = SettingsService(storageFile: settingsFile);
      await service1.init();
      expect(service1.settings.themeMode, ThemeMode.system);

      await service1.updateThemeMode(ThemeMode.dark);
      expect(service1.settings.themeMode, ThemeMode.dark);

      // Recreate service from disk
      final service2 = SettingsService(storageFile: settingsFile);
      await service2.init();
      expect(service2.settings.themeMode, ThemeMode.dark);
    });

    // ── 14. Full monitoring lifecycle ─────────────────────────────────────────
    test('14. Full monitoring lifecycle: start -> ingest -> pause -> resume -> stop -> valid session', () async {
      final localRepo = LocalMonitoringSessionRepository(isInitialized: true);
      final source = _ControlledDataSource();
      final controller = MonitoringController(source, repository: localRepo);

      expect(controller.status, MonitoringStatus.stopped);

      await controller.start();
      expect(controller.isActive, isTrue);

      source.emit(_createReading(timestamp: DateTime.now(), force: 2.5, ipAngle: 30));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await controller.pause();
      expect(controller.isPaused, isTrue);

      await controller.resume();
      expect(controller.isActive, isTrue);

      source.emit(_createReading(timestamp: DateTime.now(), force: 3.5, ipAngle: 40));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await controller.stop();
      expect(controller.status, MonitoringStatus.stopped);

      final session = controller.lastCompletedSession;
      expect(session, isNotNull);
      expect(session!.maximumIpAngle, greaterThanOrEqualTo(30));
      expect(controller.lastSessionReadings.length, 2);
      expect(localRepo.sessions.length, 1);
    });

    // ── 15. Local data preserved after cloud failure ───────────────────────────
    test('15. Local data is 100% preserved if cloud repository throws during session finalization', () async {
      final localRepo = LocalMonitoringSessionRepository(isInitialized: true);
      final failingCloudRepo = _InMemoryCloudRepo()..failNext = true;

      final source = _ControlledDataSource();
      final controller = MonitoringController(
        source,
        repository: failingCloudRepo,
        fallbackRepository: localRepo,
      );

      await controller.start();
      source.emit(_createReading(timestamp: DateTime.now(), force: 4.0));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await controller.stop();

      // Cloud had error
      expect(controller.hasPersistenceError, isTrue);

      // But local repository safely preserved session & readings!
      expect(localRepo.sessions.length, 1);
      final savedReadings = await localRepo.getSensorReadings(localRepo.sessions.first.id);
      expect(savedReadings.length, 1);
      expect(savedReadings.first.force, 4.0);
    });
  });
}
