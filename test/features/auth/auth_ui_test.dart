import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thumb_biomech_monitor_glove/core/errors/supabase_exceptions.dart';
import 'package:thumb_biomech_monitor_glove/core/services/auth_repository.dart';
import 'package:thumb_biomech_monitor_glove/features/auth/presentation/auth_gate.dart';
import 'package:thumb_biomech_monitor_glove/features/auth/presentation/login_page.dart';
import 'package:thumb_biomech_monitor_glove/features/auth/presentation/register_page.dart';

/// Test implementation of [AuthRepository] with fine-grained control over responses.
class MockAuthRepository implements AuthRepository {
  User? mockUser;
  Session? mockSession;
  String? forcedError;
  Completer<void>? pendingCompleter;

  final _controller = StreamController<AuthState>.broadcast();

  @override
  User? get currentUser => mockUser;

  @override
  Session? get currentSession => mockSession;

  @override
  Stream<AuthState> get authStateChanges => _controller.stream;

  @override
  bool get isAuthenticated => mockUser != null;

  @override
  Future<User?> signIn({required String email, required String password}) async {
    if (pendingCompleter != null) {
      await pendingCompleter!.future;
    }
    if (forcedError != null) {
      throw SupabaseAuthException(forcedError!);
    }
    mockUser = User(
      id: 'user-123',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: email,
    );
    mockSession = Session(
      accessToken: 'token',
      tokenType: 'bearer',
      user: mockUser!,
    );
    _controller.add(AuthState(AuthChangeEvent.signedIn, mockSession));
    return mockUser;
  }

  @override
  Future<User?> signUp({required String email, required String password}) async {
    if (pendingCompleter != null) {
      await pendingCompleter!.future;
    }
    if (forcedError != null) {
      throw SupabaseAuthException(forcedError!);
    }
    mockUser = User(
      id: 'user-new',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: email,
    );
    // mockSession remains null if email confirmation required
    return mockUser;
  }

  @override
  Future<void> signOut() async {
    mockUser = null;
    mockSession = null;
    _controller.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  late MockAuthRepository mockAuth;

  setUp(() {
    mockAuth = MockAuthRepository();
  });

  tearDown(() {
    mockAuth.dispose();
  });

  Widget createTestWidget(Widget child) => MaterialApp(
        home: child,
      );

  group('LoginPage UI & Validation', () {
    testWidgets('1. Displays login form elements', (tester) async {
      await tester.pumpWidget(createTestWidget(LoginPage(authRepository: mockAuth)));

      expect(find.text('ThumbTrace'), findsOneWidget);
      expect(find.byKey(const Key('login_email_field')), findsOneWidget);
      expect(find.byKey(const Key('login_password_field')), findsOneWidget);
      expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
      expect(find.byKey(const Key('login_register_button')), findsOneWidget);
      expect(find.byKey(const Key('login_demo_mode_button')), findsOneWidget);
    });

    testWidgets('2. Validates empty email and empty password', (tester) async {
      await tester.pumpWidget(createTestWidget(LoginPage(authRepository: mockAuth)));

      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pump();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('3. Validates invalid email format', (tester) async {
      await tester.pumpWidget(createTestWidget(LoginPage(authRepository: mockAuth)));

      await tester.enterText(find.byKey(const Key('login_email_field')), 'not-an-email');
      await tester.enterText(find.byKey(const Key('login_password_field')), 'secret123');
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pump();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });

    testWidgets('4. Successful login invokes callback', (tester) async {
      var successCalled = false;

      await tester.pumpWidget(createTestWidget(
        LoginPage(
          authRepository: mockAuth,
          onLoginSuccess: () => successCalled = true,
        ),
      ));

      await tester.enterText(find.byKey(const Key('login_email_field')), 'user@example.com');
      await tester.enterText(find.byKey(const Key('login_password_field')), 'password123');
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(successCalled, isTrue);
      expect(mockAuth.currentUser?.email, 'user@example.com');
    });

    testWidgets('5. Failed login displays user-friendly error without stack traces',
        (tester) async {
      mockAuth.forcedError = 'Invalid email or password.';

      await tester.pumpWidget(createTestWidget(LoginPage(authRepository: mockAuth)));

      await tester.enterText(find.byKey(const Key('login_email_field')), 'user@example.com');
      await tester.enterText(find.byKey(const Key('login_password_field')), 'wrong_pw');
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password.'), findsOneWidget);
    });

    testWidgets('6. Shows loading indicator during login', (tester) async {
      final completer = Completer<void>();
      mockAuth.pendingCompleter = completer;

      await tester.pumpWidget(createTestWidget(LoginPage(authRepository: mockAuth)));

      await tester.enterText(find.byKey(const Key('login_email_field')), 'user@example.com');
      await tester.enterText(find.byKey(const Key('login_password_field')), 'pw');
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pump(); // Start async work

      // Progress indicator should be visible
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('RegisterPage UI & Validation', () {
    testWidgets('7. Displays registration form', (tester) async {
      await tester.pumpWidget(createTestWidget(RegisterPage(authRepository: mockAuth)));

      expect(find.text('Create an Account'), findsOneWidget);
      expect(find.byKey(const Key('register_email_field')), findsOneWidget);
      expect(find.byKey(const Key('register_password_field')), findsOneWidget);
      expect(find.byKey(const Key('register_confirm_password_field')), findsOneWidget);
      expect(find.byKey(const Key('register_submit_button')), findsOneWidget);
      expect(find.byKey(const Key('register_signin_button')), findsOneWidget);
    });

    testWidgets('8. Validates empty fields and password length', (tester) async {
      await tester.pumpWidget(createTestWidget(RegisterPage(authRepository: mockAuth)));

      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pump();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter a password'), findsOneWidget);

      // Enter short password
      await tester.enterText(find.byKey(const Key('register_email_field')), 'user@example.com');
      await tester.enterText(find.byKey(const Key('register_password_field')), '123');
      await tester.enterText(find.byKey(const Key('register_confirm_password_field')), '123');
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pump();

      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    });

    testWidgets('9. Validates password mismatch', (tester) async {
      await tester.pumpWidget(createTestWidget(RegisterPage(authRepository: mockAuth)));

      await tester.enterText(find.byKey(const Key('register_email_field')), 'user@example.com');
      await tester.enterText(find.byKey(const Key('register_password_field')), 'password123');
      await tester.enterText(find.byKey(const Key('register_confirm_password_field')), 'different');
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('10. Registration with email confirmation displays notification', (tester) async {
      await tester.pumpWidget(createTestWidget(RegisterPage(authRepository: mockAuth)));

      await tester.enterText(find.byKey(const Key('register_email_field')), 'new@example.com');
      await tester.enterText(find.byKey(const Key('register_password_field')), 'secret123');
      await tester.enterText(find.byKey(const Key('register_confirm_password_field')), 'secret123');
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Account created. Please verify your email before signing in.'),
        findsOneWidget,
      );
    });

    testWidgets('11. Registration error displays user-friendly error', (tester) async {
      mockAuth.forcedError = 'An account with this email address already exists.';

      await tester.pumpWidget(createTestWidget(RegisterPage(authRepository: mockAuth)));

      await tester.enterText(find.byKey(const Key('register_email_field')), 'existing@example.com');
      await tester.enterText(find.byKey(const Key('register_password_field')), 'secret123');
      await tester.enterText(find.byKey(const Key('register_confirm_password_field')), 'secret123');
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('An account with this email address already exists.'),
        findsOneWidget,
      );
    });
  });

  group('Authentication Routing via AuthGate', () {
    testWidgets('12. Unauthenticated state shows LoginPage', (tester) async {
      mockAuth.mockUser = null;

      await tester.pumpWidget(createTestWidget(AuthGate(authRepository: mockAuth)));
      await tester.pumpAndSettle();

      expect(find.text('ThumbTrace'), findsOneWidget);
      expect(find.byKey(const Key('login_email_field')), findsOneWidget);
      expect(find.text('Research dashboard'), findsNothing);
    });

    testWidgets('13. Authenticated state shows existing application shell', (tester) async {
      mockAuth.mockUser = User(
        id: 'user-456',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'logged@example.com',
      );

      await tester.pumpWidget(createTestWidget(AuthGate(authRepository: mockAuth)));
      await tester.pumpAndSettle();

      expect(find.text('Research dashboard'), findsOneWidget);
      expect(find.text('ThumbTrace'), findsNothing);
    });

    testWidgets('14. Logout from Settings returns to LoginPage', (tester) async {
      mockAuth.mockUser = User(
        id: 'user-456',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'logged@example.com',
      );

      await tester.pumpWidget(createTestWidget(AuthGate(authRepository: mockAuth)));
      await tester.pumpAndSettle();

      // Navigate to More -> Settings
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Verify email is shown in Account card
      expect(find.text('logged@example.com'), findsOneWidget);

      // Tap Sign Out
      await tester.tap(find.byKey(const Key('settings_sign_out_button')));
      await tester.pumpAndSettle();

      // Should now be on LoginPage
      expect(find.text('ThumbTrace'), findsOneWidget);
      expect(find.byKey(const Key('login_email_field')), findsOneWidget);
    });

    testWidgets('15. Continue in Demo Mode enters application shell', (tester) async {
      mockAuth.mockUser = null;

      await tester.pumpWidget(createTestWidget(AuthGate(authRepository: mockAuth)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_demo_mode_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('login_demo_mode_button')));
      await tester.pumpAndSettle();

      expect(find.text('Research dashboard'), findsOneWidget);
      expect(find.text('Demo Mode'), findsOneWidget);
    });
  });
}
