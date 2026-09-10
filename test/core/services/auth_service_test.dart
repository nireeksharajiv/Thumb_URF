import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thumb_biomech_monitor_glove/core/errors/supabase_exceptions.dart';
import 'package:thumb_biomech_monitor_glove/core/services/auth_repository.dart';
import 'package:thumb_biomech_monitor_glove/core/services/auth_service.dart';
import 'package:thumb_biomech_monitor_glove/core/services/supabase_service.dart';

/// Test implementation of [AuthRepository] demonstrating interface usability
/// and decoupled behavior for testing.
class FakeAuthRepository implements AuthRepository {
  User? _currentUser;
  Session? _currentSession;
  final _controller = StreamController<AuthState>.broadcast();

  @override
  User? get currentUser => _currentUser;

  @override
  Session? get currentSession => _currentSession;

  @override
  Stream<AuthState> get authStateChanges => _controller.stream;

  @override
  bool get isAuthenticated => _currentUser != null;

  @override
  Future<User?> signUp({required String email, required String password}) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw const SupabaseAuthException('Email and password cannot be empty.');
    }
    _currentUser = User(
      id: 'test-user-id-123',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: cleanEmail,
    );
    _controller.add(AuthState(AuthChangeEvent.signedIn, _currentSession));
    return _currentUser;
  }

  @override
  Future<User?> signIn({required String email, required String password}) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw const SupabaseAuthException('Email and password cannot be empty.');
    }
    if (password == 'wrong_password') {
      throw const SupabaseAuthException('Invalid email or password.');
    }
    _currentUser = User(
      id: 'test-user-id-123',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: cleanEmail,
    );
    _controller.add(AuthState(AuthChangeEvent.signedIn, _currentSession));
    return _currentUser;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _currentSession = null;
    _controller.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  group('AuthService with uninitialized Supabase', () {
    late AuthService authService;

    setUp(() {
      SupabaseService.instance.setClientForTesting(null);
      authService = AuthService();
    });

    test('1. Returns null user/session and false for isAuthenticated when uninitialized', () {
      expect(authService.currentUser, isNull);
      expect(authService.currentSession, isNull);
      expect(authService.isAuthenticated, isFalse);
    });

    test('2. authStateChanges emits nothing when uninitialized', () async {
      expect(await authService.authStateChanges.isEmpty, isTrue);
    });

    test('3. signUp rejects empty email and password before contacting client', () {
      expect(
        () => authService.signUp(email: '', password: 'secretpassword'),
        throwsA(
          isA<SupabaseAuthException>().having(
            (e) => e.message,
            'message',
            'Email and password cannot be empty.',
          ),
        ),
      );

      expect(
        () => authService.signUp(email: 'test@example.com', password: ''),
        throwsA(
          isA<SupabaseAuthException>().having(
            (e) => e.message,
            'message',
            'Email and password cannot be empty.',
          ),
        ),
      );
    });

    test('4. signIn rejects empty email and password before contacting client', () {
      expect(
        () => authService.signIn(email: '   ', password: 'secretpassword'),
        throwsA(
          isA<SupabaseAuthException>().having(
            (e) => e.message,
            'message',
            'Email and password cannot be empty.',
          ),
        ),
      );

      expect(
        () => authService.signIn(email: 'test@example.com', password: ''),
        throwsA(
          isA<SupabaseAuthException>().having(
            (e) => e.message,
            'message',
            'Email and password cannot be empty.',
          ),
        ),
      );
    });

    test('5. signUp and signIn throw SupabaseConfigException when unconfigured', () {
      expect(
        () => authService.signUp(email: 'user@example.com', password: 'password123'),
        throwsA(isA<SupabaseConfigException>()),
      );

      expect(
        () => authService.signIn(email: 'user@example.com', password: 'password123'),
        throwsA(isA<SupabaseConfigException>()),
      );
    });

    test('6. signOut does not throw when uninitialized', () async {
      await expectLater(authService.signOut(), completes);
    });
  });

  group('AuthService.mapAuthErrorMessage', () {
    test('7. Maps invalid credentials correctly', () {
      const ex = AuthException('Invalid login credentials');
      expect(AuthService.mapAuthErrorMessage(ex), 'Invalid email or password.');
    });

    test('8. Maps existing user correctly', () {
      const ex = AuthException('User already registered');
      expect(
        AuthService.mapAuthErrorMessage(ex),
        'An account with this email address already exists.',
      );
    });

    test('9. Maps short password correctly', () {
      const ex = AuthException('Password should be at least 6 characters');
      expect(
        AuthService.mapAuthErrorMessage(ex),
        'Password is too short. Must be at least 6 characters.',
      );
    });

    test('10. Preserves custom exception messages', () {
      const ex = AuthException('Rate limit exceeded');
      expect(AuthService.mapAuthErrorMessage(ex), 'Rate limit exceeded');
    });
  });

  group('FakeAuthRepository contract and behavior', () {
    late FakeAuthRepository repository;

    setUp(() {
      repository = FakeAuthRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    test('11. Initial state is unauthenticated', () {
      expect(repository.isAuthenticated, isFalse);
      expect(repository.currentUser, isNull);
      expect(repository.currentSession, isNull);
    });

    test('12. signUp authenticates user and emits event', () async {
      final states = <AuthState>[];
      final subscription = repository.authStateChanges.listen(states.add);

      final user = await repository.signUp(
        email: 'researcher@example.com',
        password: 'password123',
      );

      expect(user, isNotNull);
      expect(user?.email, 'researcher@example.com');
      expect(repository.isAuthenticated, isTrue);
      expect(repository.currentUser?.id, 'test-user-id-123');

      // Wait for stream event
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(states, hasLength(1));
      expect(states.first.event, AuthChangeEvent.signedIn);

      await subscription.cancel();
    });

    test('13. signIn succeeds with valid credentials and fails with invalid credentials', () async {
      await expectLater(
        () => repository.signIn(email: 'user@example.com', password: 'wrong_password'),
        throwsA(
          isA<SupabaseAuthException>().having(
            (e) => e.message,
            'message',
            'Invalid email or password.',
          ),
        ),
      );
      expect(repository.isAuthenticated, isFalse);

      final user = await repository.signIn(
        email: 'user@example.com',
        password: 'correct_password',
      );
      expect(user, isNotNull);
      expect(repository.isAuthenticated, isTrue);
    });

    test('14. signOut clears user and emits signedOut event', () async {
      await repository.signIn(email: 'user@example.com', password: 'pw');
      expect(repository.isAuthenticated, isTrue);

      final states = <AuthState>[];
      final subscription = repository.authStateChanges.listen(states.add);

      await repository.signOut();

      expect(repository.isAuthenticated, isFalse);
      expect(repository.currentUser, isNull);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(states.last.event, AuthChangeEvent.signedOut);

      await subscription.cancel();
    });
  });
}
