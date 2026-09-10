import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_exceptions.dart';
import 'auth_repository.dart';
import 'supabase_service.dart';

/// Authentication service wrapping Supabase GoTrue authentication.
///
/// Handles email/password authentication without persisting or managing credentials
/// directly. If Supabase is uninitialized, operations throw [SupabaseConfigException].
class AuthService implements AuthRepository {
  AuthService({SupabaseClient? client}) : _customClient = client;

  final SupabaseClient? _customClient;

  SupabaseClient? get _client =>
      _customClient ?? SupabaseService.instance.clientOrNull;

  @override
  User? get currentUser => _client?.auth.currentUser;

  @override
  Session? get currentSession => _client?.auth.currentSession;

  @override
  Stream<AuthState> get authStateChanges =>
      _client?.auth.onAuthStateChange ?? const Stream.empty();

  @override
  bool get isAuthenticated => currentUser != null;

  @override
  Future<User?> signUp({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw const SupabaseAuthException('Email and password cannot be empty.');
    }

    final client = _requireClient();

    try {
      final response = await client.auth.signUp(
        email: cleanEmail,
        password: password,
      );
      return response.user;
    } on AuthException catch (e) {
      throw SupabaseAuthException(
        mapAuthErrorMessage(e),
        technicalDetails: e.message,
      );
    } catch (e) {
      throw SupabaseAuthException(
        'Registration failed. Please check your network connection.',
        technicalDetails: e.toString(),
      );
    }
  }

  @override
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw const SupabaseAuthException('Email and password cannot be empty.');
    }

    final client = _requireClient();

    try {
      final response = await client.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );
      return response.user;
    } on AuthException catch (e) {
      throw SupabaseAuthException(
        mapAuthErrorMessage(e),
        technicalDetails: e.message,
      );
    } catch (e) {
      throw SupabaseAuthException(
        'Sign in failed. Please check your network connection.',
        technicalDetails: e.toString(),
      );
    }
  }

  @override
  Future<void> signOut() async {
    final client = _client;
    if (client == null) return;

    try {
      await client.auth.signOut();
    } on AuthException catch (e) {
      throw SupabaseAuthException(
        'Sign out failed. Please try again.',
        technicalDetails: e.message,
      );
    } catch (e) {
      throw SupabaseAuthException(
        'Sign out failed.',
        technicalDetails: e.toString(),
      );
    }
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const SupabaseConfigException(
        'Supabase authentication is unavailable because Supabase is not configured.',
      );
    }
    return client;
  }

  /// Maps Supabase [AuthException] to user-friendly message strings.
  static String mapAuthErrorMessage(AuthException exception) {
    final message = exception.message.toLowerCase();
    if (message.contains('invalid login credentials') ||
        message.contains('invalid email or password')) {
      return 'Invalid email or password.';
    }
    if (message.contains('user already registered') ||
        message.contains('already exists')) {
      return 'An account with this email address already exists.';
    }
    if (message.contains('password should be at least')) {
      return 'Password is too short. Must be at least 6 characters.';
    }
    return exception.message;
  }
}
