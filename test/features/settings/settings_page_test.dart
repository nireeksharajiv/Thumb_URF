import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thumb_biomech_monitor_glove/core/models/monitoring_session.dart';
import 'package:thumb_biomech_monitor_glove/core/services/auth_repository.dart';
import 'package:thumb_biomech_monitor_glove/core/services/local_monitoring_session_repository.dart';
import 'package:thumb_biomech_monitor_glove/features/settings/application/settings_service.dart';
import 'package:thumb_biomech_monitor_glove/features/settings/presentation/settings_page.dart';

class _FakeAuthRepo implements AuthRepository {
  _FakeAuthRepo({this.authenticated = false, this.email});
  bool authenticated;
  final String? email;

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
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<User?> signIn({required String email, required String password}) async {
    authenticated = true;
    return currentUser;
  }

  @override
  Future<User?> signUp({required String email, required String password}) async {
    authenticated = true;
    return currentUser;
  }

  @override
  Future<void> signOut() async {
    authenticated = false;
  }
}

MonitoringSession _buildSession({required String id}) => MonitoringSession(
      id: id,
      startTime: DateTime.utc(2026, 9, 10, 10, 0),
      endTime: DateTime.utc(2026, 9, 10, 10, 5),
      movementCount: 15,
      averageIpAngle: 25.0,
      maximumIpAngle: 40.0,
      averageMcpAngle: 15.0,
      maximumMcpAngle: 25.0,
      averageForce: 2.0,
      peakForce: 4.0,
      averageAngularVelocity: 8.0,
      averageMotionMagnitude: 0.4,
    );

void main() {
  group('SettingsPage Widget Tests', () {
    late SettingsService settingsService;
    late LocalMonitoringSessionRepository localRepo;

    setUp(() {
      settingsService = SettingsService(isInitialized: true);
      localRepo = LocalMonitoringSessionRepository(isInitialized: true);
    });

    testWidgets('renders all major sections and research preferences', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              settingsService: settingsService,
              repository: localRepo,
            ),
          ),
        ),
      );

      // Section titles
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Monitoring preferences'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Local Storage & Cache'), findsOneWidget);
      expect(find.text('About this project'), findsOneWidget);

      // Sliders and defaults
      expect(find.text('Force Exceedance Threshold'), findsOneWidget);
      expect(find.text('2.5 N'), findsOneWidget);
      expect(find.text('Angular Velocity Threshold'), findsOneWidget);
      expect(find.text('40 °/s'), findsOneWidget);
      expect(find.text('Reference Movement Frequency'), findsOneWidget);
      expect(find.text('30 /min'), findsOneWidget);

      // Non-diagnostic disclaimer
      expect(
        find.textContaining('Engineering Research Prototype: Developed for biomechanical'),
        findsOneWidget,
      );
    });

    testWidgets('shows signed in user account info and triggers sign out callback', (tester) async {
      var signOutCalled = false;
      final auth = _FakeAuthRepo(
        authenticated: true,
        email: 'researcher@lab.org',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              authRepository: auth,
              settingsService: settingsService,
              repository: localRepo,
              onSignOut: () => signOutCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Account'), findsOneWidget);
      expect(find.text('researcher@lab.org'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings_sign_out_button')));
      await tester.pump();
      expect(signOutCalled, isTrue);
    });

    testWidgets('toggles auto cloud sync switch', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              settingsService: settingsService,
              repository: localRepo,
            ),
          ),
        ),
      );

      expect(settingsService.settings.autoCloudSync, isFalse);

      await tester.tap(find.byKey(const Key('auto_cloud_sync_switch')));
      await tester.pump();

      expect(settingsService.settings.autoCloudSync, isTrue);
    });

    testWidgets('changes theme mode using segmented button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              settingsService: settingsService,
              repository: localRepo,
            ),
          ),
        ),
      );

      expect(settingsService.settings.themeMode, ThemeMode.system);

      final darkBtn = find.text('Dark');
      await tester.ensureVisible(darkBtn);
      await tester.tap(darkBtn);
      await tester.pump();

      expect(settingsService.settings.themeMode, ThemeMode.dark);

      final lightBtn = find.text('Light');
      await tester.ensureVisible(lightBtn);
      await tester.tap(lightBtn);
      await tester.pump();

      expect(settingsService.settings.themeMode, ThemeMode.light);
    });

    testWidgets('reset button restores default research thresholds and shows SnackBar', (tester) async {
      await settingsService.updateForceThreshold(6.5);
      await settingsService.updateAngularVelocityThreshold(90.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              settingsService: settingsService,
              repository: localRepo,
            ),
          ),
        ),
      );

      expect(find.text('6.5 N'), findsOneWidget);
      expect(find.text('90 °/s'), findsOneWidget);

      // Tap Reset
      final resetBtn = find.byKey(const Key('reset_settings_button'));
      await tester.ensureVisible(resetBtn);
      await tester.tap(resetBtn);
      await tester.pump();

      expect(settingsService.settings.forceThreshold, 2.5);
      expect(settingsService.settings.angularVelocityThreshold, 40.0);
      expect(find.text('2.5 N'), findsOneWidget);
      expect(find.text('Settings reset to research default baselines.'), findsOneWidget);
    });

    testWidgets('clearing local cache shows confirmation dialog and removes sessions when confirmed', (tester) async {
      localRepo.add(_buildSession(id: 'sess-1'));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              settingsService: settingsService,
              repository: localRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 completed session(s) persisted locally.'), findsOneWidget);

      // 1. Open dialog and Cancel
      final clearBtn = find.byKey(const Key('clear_cache_button'));
      await tester.ensureVisible(clearBtn);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      expect(find.text('Clear Local Sessions?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(localRepo.sessions.length, 1);

      // 2. Open dialog and Confirm Clear
      await tester.ensureVisible(clearBtn);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_clear_cache_button')));
      await tester.pumpAndSettle();

      expect(localRepo.sessions.isEmpty, isTrue);
      expect(find.text('0 completed session(s) persisted locally.'), findsOneWidget);
      expect(find.text('Local session cache cleared.'), findsOneWidget);
    });
  });
}
