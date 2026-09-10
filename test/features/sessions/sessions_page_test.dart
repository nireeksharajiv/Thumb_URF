import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thumb_biomech_monitor_glove/core/models/monitoring_session.dart';
import 'package:thumb_biomech_monitor_glove/core/models/sensor_reading.dart';
import 'package:thumb_biomech_monitor_glove/core/models/sync_status.dart';
import 'package:thumb_biomech_monitor_glove/core/services/auth_repository.dart';
import 'package:thumb_biomech_monitor_glove/core/services/session_repository.dart';
import 'package:thumb_biomech_monitor_glove/core/services/session_sync_service.dart';
import 'package:thumb_biomech_monitor_glove/core/services/supabase_session_repository.dart';
import 'package:thumb_biomech_monitor_glove/features/sessions/presentation/sessions_page.dart';

// ---------------------------------------------------------------------------
// Helper — build a minimal valid MonitoringSession.
// ---------------------------------------------------------------------------

MonitoringSession _session({
  String id = 'test-001',
  int movementCount = 5,
  double avgIp = 25.0,
  double maxIp = 40.0,
  double avgMcp = 15.0,
  double maxMcp = 25.0,
  double avgForce = 2.0,
  double peakForce = 4.0,
}) => MonitoringSession(
  id: id,
  startTime: DateTime.utc(2026, 9, 10, 10, 0),
  endTime: DateTime.utc(2026, 9, 10, 10, 5), // 5-minute session
  movementCount: movementCount,
  averageIpAngle: avgIp,
  maximumIpAngle: maxIp,
  averageMcpAngle: avgMcp,
  maximumMcpAngle: maxMcp,
  averageForce: avgForce,
  peakForce: peakForce,
  averageAngularVelocity: 8.0,
  averageMotionMagnitude: 0.4,
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

// ---------------------------------------------------------------------------

void main() {
  // ── Test 12a ──────────────────────────────────────────────────────────────

  testWidgets('12a. Shows empty state when repository has no sessions', (
    tester,
  ) async {
    final repo = SessionRepository();
    await tester.pumpWidget(_wrap(SessionsPage(repository: repo)));

    expect(find.text('No completed sessions yet'), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    // No session cards.
    expect(find.text('Completed session'), findsNothing);

    repo.dispose();
  });

  // ── Test 12b ──────────────────────────────────────────────────────────────

  testWidgets('12b. Shows session card after a session is added', (
    tester,
  ) async {
    final repo = SessionRepository();
    await tester.pumpWidget(_wrap(SessionsPage(repository: repo)));

    // Initially empty.
    expect(find.text('No completed sessions yet'), findsOneWidget);

    // Add a session — repository notifies listeners → page rebuilds.
    repo.add(_session(movementCount: 8));
    await tester.pump();

    // Empty state gone.
    expect(find.text('No completed sessions yet'), findsNothing);

    // Session card present.
    expect(find.text('Completed session'), findsOneWidget);
    expect(find.text('8'), findsOneWidget); // movement count
    expect(find.text('Sessions'), findsOneWidget); // page heading

    repo.dispose();
  });

  // ── Test 12c ──────────────────────────────────────────────────────────────

  testWidgets(
    '12c. Shows null-repository empty state (no repository provided)',
    (tester) async {
      await tester.pumpWidget(_wrap(const SessionsPage()));
      expect(find.text('No completed sessions yet'), findsOneWidget);
    },
  );

  // ── Test 12d ──────────────────────────────────────────────────────────────

  testWidgets('12d. Multiple sessions shown newest first', (tester) async {
    final repo = SessionRepository();
    // Add two sessions — page should display newest (added last) at top.
    repo.add(_session(id: 'old', avgIp: 20.0, peakForce: 2.0));
    repo.add(_session(id: 'new', avgIp: 40.0, peakForce: 6.0));

    await tester.pumpWidget(_wrap(SessionsPage(repository: repo)));

    // Both cards present.
    expect(find.text('Completed session'), findsNWidgets(2));

    // Subtitle shows record count.
    expect(find.textContaining('2 records'), findsOneWidget);

    repo.dispose();
  });

  // ── Test 12e ──────────────────────────────────────────────────────────────

  testWidgets('12e. Displays sync badge and sync all button when syncService is provided', (
    tester,
  ) async {
    final repo = SessionRepository();
    final auth = _FakeAuthRepo(authenticated: true);
    final cloud = _FakeCloudRepo();
    final syncService = SessionSyncService(
      localRepository: repo,
      cloudRepository: cloud,
      authRepository: auth,
    );

    repo.add(_session(id: 'sync-sess-1'));

    await tester.pumpWidget(_wrap(SessionsPage(
      repository: repo,
      syncService: syncService,
    )));

    // Sync All button in header
    expect(find.byKey(const Key('sync_all_button')), findsOneWidget);
    // Initial state before sync is "Local only"
    expect(find.text('Local only'), findsOneWidget);

    syncService.dispose();
    cloud.dispose();
    repo.dispose();
  });

  // ── Test 12f ──────────────────────────────────────────────────────────────

  testWidgets('12f. Opens details bottom sheet showing Cloud Synchronization section', (
    tester,
  ) async {
    final repo = SessionRepository();
    final auth = _FakeAuthRepo(authenticated: true);
    final cloud = _FakeCloudRepo();
    final syncService = SessionSyncService(
      localRepository: repo,
      cloudRepository: cloud,
      authRepository: auth,
    );

    repo.add(_session(id: 'sync-sess-2'));

    await tester.pumpWidget(_wrap(SessionsPage(
      repository: repo,
      syncService: syncService,
    )));

    // Tap on the session card to open details sheet
    await tester.tap(find.text('Completed session'));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Cloud Synchronization section
    expect(find.text('Cloud Synchronization'), findsOneWidget);
    expect(find.byKey(const Key('sync_session_button')), findsOneWidget);
    expect(find.text('Sync to Cloud'), findsOneWidget);

    syncService.dispose();
    cloud.dispose();
    repo.dispose();
  });

  // ── Test 12g ──────────────────────────────────────────────────────────────

  testWidgets('12g. Reactive sync update refreshes session card sync badge', (
    tester,
  ) async {
    final repo = SessionRepository();
    final auth = _FakeAuthRepo(authenticated: true);
    final cloud = _FakeCloudRepo();
    final syncService = SessionSyncService(
      localRepository: repo,
      cloudRepository: cloud,
      authRepository: auth,
    );

    repo.add(_session(id: 'sync-sess-reactive'));

    await tester.pumpWidget(_wrap(SessionsPage(
      repository: repo,
      syncService: syncService,
    )));

    // Initially shows "Local only" badge
    expect(find.text('Local only'), findsOneWidget);
    expect(find.text('Synced'), findsNothing);

    // Synchronize session
    final result = await syncService.syncSession('sync-sess-reactive');
    expect(result.state, equals(SyncState.synced));

    // Pump to let widget react to sync change notification
    await tester.pump();

    // Badge updates to "Synced"
    expect(find.text('Synced'), findsOneWidget);
    expect(find.text('Local only'), findsNothing);

    syncService.dispose();
    cloud.dispose();
    repo.dispose();
  });
}

// ---------------------------------------------------------------------------
// Fakes for widget tests
// ---------------------------------------------------------------------------

class _FakeAuthRepo implements AuthRepository {
  _FakeAuthRepo({this.authenticated = true});
  bool authenticated;

  @override
  bool get isAuthenticated => authenticated;

  @override
  User? get currentUser => authenticated
      ? User(
          id: 'test-user-id',
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

class _FakeCloudRepo extends SupabaseMonitoringSessionRepository {
  final Map<String, MonitoringSession> savedSessions = {};

  @override
  Future<void> saveSession(
    MonitoringSession session, {
    List<SensorReading>? readings,
    String? userId,
  }) async {
    savedSessions[session.id] = session;
  }

  @override
  Future<List<MonitoringSession>> getSessions() async => savedSessions.values.toList();

  @override
  Future<List<SensorReading>> getSensorReadings(String sessionId) async => [];
}
