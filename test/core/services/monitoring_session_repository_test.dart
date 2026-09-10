import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thumb_biomech_monitor_glove/core/errors/supabase_exceptions.dart';
import 'package:thumb_biomech_monitor_glove/core/models/monitoring_session.dart';
import 'package:thumb_biomech_monitor_glove/core/models/sensor_reading.dart';
import 'package:thumb_biomech_monitor_glove/core/services/auth_repository.dart';
import 'package:thumb_biomech_monitor_glove/core/services/local_monitoring_session_repository.dart';
import 'package:thumb_biomech_monitor_glove/core/services/monitoring_session_repository.dart';
import 'package:thumb_biomech_monitor_glove/core/services/sensor_data_source.dart';
import 'package:thumb_biomech_monitor_glove/core/services/supabase_session_repository.dart';
import 'package:thumb_biomech_monitor_glove/features/monitoring/application/monitoring_controller.dart';
import 'package:thumb_biomech_monitor_glove/features/sessions/presentation/sessions_page.dart';

/// Test mock of [AuthRepository] to provide authenticated user identity.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user});

  User? user;

  @override
  User? get currentUser => user;

  @override
  Session? get currentSession => null;

  @override
  bool get isAuthenticated => user != null;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<User?> signIn({required String email, required String password}) async => user;

  @override
  Future<User?> signUp({required String email, required String password}) async => user;

  @override
  Future<void> signOut() async {
    user = null;
  }
}

/// Fake [SensorDataSource] for driving [MonitoringController] in tests.
class FakeSensorDataSource implements SensorDataSource {
  final _controller = StreamController<SensorReading>.broadcast(sync: true);

  @override
  Stream<SensorReading> get readings => _controller.stream;

  void emit(SensorReading r) => _controller.add(r);

  @override
  Future<void> start() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  Future<void> dispose() async {
    await _controller.close();
  }
}

/// Failing repository mock to test error handling & fallback behavior.
class FailingSessionRepository implements MonitoringSessionRepository {
  bool failNext = true;
  final List<MonitoringSession> saved = [];

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  Future<void> saveSession(
    MonitoringSession session, {
    List<SensorReading>? readings,
  }) async {
    if (failNext) {
      throw Exception('Simulated network timeout');
    }
    saved.add(session);
  }

  @override
  Future<List<MonitoringSession>> getSessions() async => saved;

  @override
  Future<MonitoringSession?> getSessionById(String id) async => null;

  @override
  Future<void> deleteSession(String id) async {}

  @override
  Future<void> saveSensorReadings(String sessionId, List<SensorReading> readings) async {}

  @override
  Future<List<SensorReading>> getSensorReadings(String sessionId) async => const [];
}

MonitoringSession _createTestSession({
  required String id,
  required DateTime startTime,
  int movementCount = 5,
  double avgForce = 2.5,
}) {
  return MonitoringSession(
    id: id,
    startTime: startTime,
    endTime: startTime.add(const Duration(minutes: 2)),
    movementCount: movementCount,
    averageIpAngle: 30.0,
    maximumIpAngle: 45.0,
    averageMcpAngle: 25.0,
    maximumMcpAngle: 35.0,
    averageForce: avgForce,
    peakForce: avgForce + 1.5,
    averageAngularVelocity: 15.0,
    averageMotionMagnitude: 1.8,
  );
}

SensorReading _createReading(DateTime timestamp, {double ip = 30, double force = 2}) {
  return SensorReading(
    timestamp: timestamp,
    ipAngle: ip,
    mcpAngle: 20,
    force: force,
    angularVelocity: 10,
    motionMagnitude: 1.5,
  );
}

void main() {
  group('LocalMonitoringSessionRepository (Basic Operations)', () {
    late Directory testTempDir;
    late File testStorageFile;
    late LocalMonitoringSessionRepository repository;

    setUp(() async {
      testTempDir = await Directory.systemTemp.createTemp('local_repo_basic_');
      testStorageFile = File('${testTempDir.path}/sessions.json');
      repository = LocalMonitoringSessionRepository(storageFile: testStorageFile);
    });

    tearDown(() async {
      repository.dispose();
      if (await testTempDir.exists()) {
        await testTempDir.delete(recursive: true);
      }
    });

    test('1. Save local session and retrieve local sessions', () async {
      final s1 = _createTestSession(id: 'sess-1', startTime: DateTime.utc(2026, 9, 10, 10));
      await repository.saveSession(s1);

      final list = await repository.getSessions();
      expect(list, hasLength(1));
      expect(list.first.id, 'sess-1');
      expect(list.first.movementCount, 5);
    });

    test('2. Newest sessions returned first', () async {
      final older = _createTestSession(
        id: 'sess-old',
        startTime: DateTime.utc(2026, 9, 10, 9),
      );
      final newer = _createTestSession(
        id: 'sess-new',
        startTime: DateTime.utc(2026, 9, 10, 11),
      );

      await repository.saveSession(older);
      await repository.saveSession(newer);

      final list = await repository.getSessions();
      expect(list, hasLength(2));
      expect(list[0].id, 'sess-new');
      expect(list[1].id, 'sess-old');
    });

    test('3. Retrieve session by ID and return null for missing', () async {
      final s = _createTestSession(id: 'sess-target', startTime: DateTime.utc(2026, 9, 10, 10));
      await repository.saveSession(s);

      final found = await repository.getSessionById('sess-target');
      expect(found, isNotNull);
      expect(found!.id, 'sess-target');

      final missing = await repository.getSessionById('non-existent');
      expect(missing, isNull);
    });

    test('4. Delete session removes session and associated sensor readings', () async {
      final s = _createTestSession(id: 'sess-del', startTime: DateTime.utc(2026, 9, 10, 10));
      final readings = [
        _createReading(DateTime.utc(2026, 9, 10, 10, 0, 1)),
        _createReading(DateTime.utc(2026, 9, 10, 10, 0, 2)),
      ];

      await repository.saveSession(s, readings: readings);
      expect(await repository.getSessions(), hasLength(1));
      expect(await repository.getSensorReadings('sess-del'), hasLength(2));

      await repository.deleteSession('sess-del');
      expect(await repository.getSessions(), isEmpty);
      expect(await repository.getSensorReadings('sess-del'), isEmpty);
    });

    test('5. Sensor readings associated with correct session', () async {
      final s1 = _createTestSession(id: 'sess-a', startTime: DateTime.utc(2026, 9, 10, 10));
      final s2 = _createTestSession(id: 'sess-b', startTime: DateTime.utc(2026, 9, 10, 11));

      final readingsA = [_createReading(DateTime.utc(2026, 9, 10, 10, 1))];
      final readingsB = [
        _createReading(DateTime.utc(2026, 9, 10, 11, 1)),
        _createReading(DateTime.utc(2026, 9, 10, 11, 2)),
      ];

      await repository.saveSession(s1, readings: readingsA);
      await repository.saveSession(s2, readings: readingsB);

      final resultA = await repository.getSensorReadings('sess-a');
      final resultB = await repository.getSensorReadings('sess-b');

      expect(resultA, hasLength(1));
      expect(resultB, hasLength(2));
    });

    test('6. JSON export and import restores sessions and readings', () async {
      final s = _createTestSession(id: 'json-1', startTime: DateTime.utc(2026, 9, 10, 10));
      final readings = [_createReading(DateTime.utc(2026, 9, 10, 10, 1))];

      await repository.saveSession(s, readings: readings);
      final jsonStr = repository.exportToJsonString();

      final restoredRepo = LocalMonitoringSessionRepository();
      restoredRepo.importFromJsonString(jsonStr);

      expect(restoredRepo.sessions, hasLength(1));
      expect(restoredRepo.sessions.first.id, 'json-1');
      restoredRepo.dispose();
    });
  });

  group('True Local Persistence Across Process Restart (dart:io)', () {
    late Directory restartTempDir;
    late File restartStorageFile;

    setUp(() async {
      restartTempDir = await Directory.systemTemp.createTemp('restart_persist_');
      restartStorageFile = File('${restartTempDir.path}/sessions_persist.json');
    });

    tearDown(() async {
      if (await restartTempDir.exists()) {
        await restartTempDir.delete(recursive: true);
      }
    });

    test('16. Save session in Repo 1 -> Repo 2 (new instance) restores session', () async {
      final repo1 = LocalMonitoringSessionRepository(storageFile: restartStorageFile);
      await repo1.init();

      final s1 = _createTestSession(id: 'restart-s1', startTime: DateTime.utc(2026, 9, 10, 12));
      await repo1.saveSession(s1);
      repo1.dispose();

      // Allocate brand new repository instance pointing to the exact same file (simulating app restart)
      final repo2 = LocalMonitoringSessionRepository(storageFile: restartStorageFile);
      await repo2.init();

      final restored = await repo2.getSessions();
      expect(restored, hasLength(1));
      expect(restored.first.id, 'restart-s1');
      expect(restored.first.movementCount, s1.movementCount);
      repo2.dispose();
    });

    test('17. Save raw readings in Repo 1 -> Repo 2 (new instance) restores readings', () async {
      final repo1 = LocalMonitoringSessionRepository(storageFile: restartStorageFile);
      await repo1.init();

      final s1 = _createTestSession(id: 'restart-s2', startTime: DateTime.utc(2026, 9, 10, 12));
      final readings = [
        _createReading(DateTime.utc(2026, 9, 10, 12, 0, 1), ip: 28, force: 3.2),
        _createReading(DateTime.utc(2026, 9, 10, 12, 0, 2), ip: 32, force: 4.1),
      ];
      await repo1.saveSession(s1, readings: readings);
      repo1.dispose();

      // Brand new instance
      final repo2 = LocalMonitoringSessionRepository(storageFile: restartStorageFile);
      final restoredReadings = await repo2.getSensorReadings('restart-s2');

      expect(restoredReadings, hasLength(2));
      expect(restoredReadings[0].ipAngle, 28);
      expect(restoredReadings[1].force, 4.1);
      repo2.dispose();
    });

    test('18. Delete session in Repo 1 -> Repo 2 (new instance) reflects deletion', () async {
      final repo1 = LocalMonitoringSessionRepository(storageFile: restartStorageFile);
      final s = _createTestSession(id: 'to-delete', startTime: DateTime.utc(2026, 9, 10, 12));
      await repo1.saveSession(s, readings: [_createReading(DateTime.utc(2026, 9, 10, 12, 1))]);
      await repo1.deleteSession('to-delete');
      repo1.dispose();

      final repo2 = LocalMonitoringSessionRepository(storageFile: restartStorageFile);
      expect(await repo2.getSessions(), isEmpty);
      expect(await repo2.getSensorReadings('to-delete'), isEmpty);
      repo2.dispose();
    });

    test('19. Missing file starts cleanly as empty repository', () async {
      final missingFile = File('${restartTempDir.path}/non_existent_file.json');
      final repo = LocalMonitoringSessionRepository(storageFile: missingFile);
      await repo.init();

      expect(await repo.getSessions(), isEmpty);
      expect(repo.sessions, isEmpty);
      repo.dispose();
    });

    test('20. Malformed/corrupt persistence data starts cleanly without crashing', () async {
      await restartStorageFile.writeAsString('{ corrupted json syntax [[[', flush: true);

      final repo = LocalMonitoringSessionRepository(storageFile: restartStorageFile);
      await expectLater(repo.init(), completes);

      expect(await repo.getSessions(), isEmpty);
      expect(repo.sessions, isEmpty);
      repo.dispose();
    });
  });

  group('SupabaseMonitoringSessionRepository Security & Validation', () {
    test('7. Unauthenticated cloud persistence is rejected safely', () async {
      final unauthenticatedAuth = FakeAuthRepository(user: null);
      final repo = SupabaseMonitoringSessionRepository(
        authRepository: unauthenticatedAuth,
      );

      final session = _createTestSession(id: 'cloud-sess-1', startTime: DateTime.utc(2026, 9, 10, 10));

      expect(
        () => repo.saveSession(session),
        throwsA(isA<SupabaseAuthException>()),
      );

      expect(
        () => repo.getSessions(),
        throwsA(isA<SupabaseAuthException>()),
      );

      expect(
        () => repo.deleteSession('cloud-sess-1'),
        throwsA(isA<SupabaseAuthException>()),
      );
    });

    test('8. Unauthenticated error does not wipe or corrupt local fallback', () async {
      final tempDir = await Directory.systemTemp.createTemp('fallback_test_');
      final localFallback = LocalMonitoringSessionRepository(
        storageFile: File('${tempDir.path}/sessions.json'),
      );
      final unauthenticatedAuth = FakeAuthRepository(user: null);
      final repo = SupabaseMonitoringSessionRepository(
        authRepository: unauthenticatedAuth,
        localFallback: localFallback,
      );

      final session = _createTestSession(id: 'fallback-sess', startTime: DateTime.utc(2026, 9, 10, 10));

      try {
        await repo.saveSession(session);
      } catch (_) {}

      expect(localFallback.sessions, isEmpty);
      localFallback.dispose();
      await tempDir.delete(recursive: true);
    });
  });

  group('MonitoringController Integration with Persistence', () {
    late FakeSensorDataSource source;
    late Directory controllerTempDir;
    late LocalMonitoringSessionRepository repository;
    late MonitoringController controller;

    setUp(() async {
      controllerTempDir = await Directory.systemTemp.createTemp('controller_test_');
      source = FakeSensorDataSource();
      repository = LocalMonitoringSessionRepository(
        storageFile: File('${controllerTempDir.path}/sessions.json'),
      );
      controller = MonitoringController(source, repository: repository);
    });

    tearDown(() async {
      controller.dispose();
      await source.dispose();
      repository.dispose();
      if (await controllerTempDir.exists()) {
        await controllerTempDir.delete(recursive: true);
      }
    });

    test('9. Completed session is passed to repository on stop()', () async {
      await controller.start();
      source.emit(_createReading(DateTime.utc(2026, 9, 10, 10, 0, 1), force: 4));
      source.emit(_createReading(DateTime.utc(2026, 9, 10, 10, 0, 2), force: 6));
      await controller.stop();

      final list = await repository.getSessions();
      expect(list, hasLength(1));
      final saved = list.first;
      expect(saved.id, isNotEmpty);
      expect(saved.averageForce, 5.0);
      expect(saved.peakForce, 6.0);
      expect(controller.lastCompletedSession?.id, saved.id);
    });

    test('10. Sensor readings are buffered and persisted with session', () async {
      await controller.start();
      source.emit(_createReading(DateTime.utc(2026, 9, 10, 10, 0, 1), ip: 25));
      source.emit(_createReading(DateTime.utc(2026, 9, 10, 10, 0, 2), ip: 35));
      source.emit(_createReading(DateTime.utc(2026, 9, 10, 10, 0, 3), ip: 45));
      await controller.stop();

      final saved = (await repository.getSessions()).first;
      final storedReadings = await repository.getSensorReadings(saved.id);
      expect(storedReadings, hasLength(3));
      expect(storedReadings[0].ipAngle, 25.0);
      expect(storedReadings[2].ipAngle, 45.0);
    });

    test('11. Persistence failure does not crash monitoring and exposes persistenceError', () async {
      final failingRepo = FailingSessionRepository();
      final tempDir = await Directory.systemTemp.createTemp('failing_test_');
      final localFallback = LocalMonitoringSessionRepository(
        storageFile: File('${tempDir.path}/sessions.json'),
      );
      final safeController = MonitoringController(
        source,
        repository: failingRepo,
        fallbackRepository: localFallback,
      );

      await safeController.start();
      source.emit(_createReading(DateTime.utc(2026, 9, 10, 10, 0, 1), force: 3));

      // stop() must not throw even though primary repository throws
      await expectLater(safeController.stop(), completes);

      expect(safeController.hasPersistenceError, isTrue);
      expect(safeController.persistenceError, contains('Simulated network timeout'));
      expect(safeController.status, MonitoringStatus.stopped);

      // Verify session was preserved in fallback
      expect(localFallback.sessions, hasLength(1));

      safeController.dispose();
      localFallback.dispose();
      await tempDir.delete(recursive: true);
    });
  });

  group('SessionsPage UI & Interactivity', () {
    Widget createTestApp(Widget child) => MaterialApp(
          home: Scaffold(body: child),
        );

    testWidgets('12. Displays empty state when repository has no sessions', (tester) async {
      late Directory tempDir;
      late LocalMonitoringSessionRepository repo;
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp('ui_empty_');
        repo = LocalMonitoringSessionRepository(
          storageFile: File('${tempDir.path}/sessions.json'),
        );
        await repo.init();
      });

      await tester.pumpWidget(createTestApp(SessionsPage(repository: repo)));
      await tester.pump();

      expect(find.text('No completed sessions yet'), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      repo.dispose();
      await tester.runAsync(() async {
        await tempDir.delete(recursive: true);
      });
    });

    testWidgets('13. Displays multiple persisted sessions with formatted statistics', (tester) async {
      late Directory tempDir;
      late LocalMonitoringSessionRepository repo;
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp('ui_mult_');
        repo = LocalMonitoringSessionRepository(
          storageFile: File('${tempDir.path}/sessions.json'),
        );
        await repo.saveSession(_createTestSession(
          id: 'sess-1',
          startTime: DateTime.utc(2026, 9, 10, 9),
          movementCount: 12,
          avgForce: 3.5,
        ));
        await repo.saveSession(_createTestSession(
          id: 'sess-2',
          startTime: DateTime.utc(2026, 9, 10, 10),
          movementCount: 20,
          avgForce: 4.8,
        ));
      });

      await tester.pumpWidget(createTestApp(SessionsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('No completed sessions yet'), findsNothing);
      expect(find.text('Completed session'), findsNWidgets(2));
      expect(find.text('12'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('3.50 N'), findsOneWidget);
      expect(find.text('4.80 N'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      repo.dispose();
      await tester.runAsync(() async {
        await tempDir.delete(recursive: true);
      });
    });

    testWidgets('14. Tapping a session card opens the detailed summary sheet', (tester) async {
      late Directory tempDir;
      late LocalMonitoringSessionRepository repo;
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp('ui_detail_');
        repo = LocalMonitoringSessionRepository(
          storageFile: File('${tempDir.path}/sessions.json'),
        );
        final session = _createTestSession(
          id: 'detail-sess-uuid',
          startTime: DateTime.utc(2026, 9, 10, 14, 30),
          movementCount: 15,
        );
        final readings = [
          _createReading(DateTime.utc(2026, 9, 10, 14, 30, 1)),
          _createReading(DateTime.utc(2026, 9, 10, 14, 30, 2)),
        ];
        await repo.saveSession(session, readings: readings);
      });

      await tester.pumpWidget(createTestApp(SessionsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap on the session card
      await tester.tap(find.text('Completed session').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify bottom sheet appears with details
      expect(find.text('Session Summary'), findsOneWidget);
      expect(find.text('Session ID: detail-sess-uuid'), findsOneWidget);
      expect(find.text('Biomechanical Metrics'), findsOneWidget);
      expect(find.text('2 samples recorded'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      repo.dispose();
      await tester.runAsync(() async {
        await tempDir.delete(recursive: true);
      });
    });

    testWidgets('15. Deleting a session from details sheet removes it', (tester) async {
      late Directory tempDir;
      late LocalMonitoringSessionRepository repo;
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp('ui_del_');
        repo = LocalMonitoringSessionRepository(
          storageFile: File('${tempDir.path}/sessions.json'),
        );
        final session = _createTestSession(
          id: 'delete-me-uuid',
          startTime: DateTime.utc(2026, 9, 10, 15, 0),
        );
        await repo.saveSession(session);
      });

      await tester.pumpWidget(createTestApp(SessionsPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Completed session'), findsOneWidget);

      // Open details
      await tester.tap(find.text('Completed session'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap delete icon in sheet
      await tester.tap(find.byTooltip('Delete session'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Confirm dialog appears
      expect(find.text('Delete Session?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();

      // Sheet closed and session removed
      expect(find.text('Session Summary'), findsNothing);
      expect(find.text('No completed sessions yet'), findsOneWidget);
      expect(await repo.getSessions(), isEmpty);

      await tester.pumpWidget(const SizedBox());
      repo.dispose();
      await tester.runAsync(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
    });
  });
}
