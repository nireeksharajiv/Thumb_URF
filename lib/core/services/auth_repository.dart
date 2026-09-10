import 'package:supabase_flutter/supabase_flutter.dart';

/// Abstract interface for authentication operations.
///
/// Provides a clean boundary decoupling authentication consumers
/// from direct Supabase SDK dependencies, enabling easy unit testing and mock injection.
abstract interface class AuthRepository {
  /// The currently authenticated Supabase [User], or `null` if unauthenticated.
  User? get currentUser;

  /// The current active Supabase [Session], or `null` if no valid session.
  Session? get currentSession;

  /// Stream of authentication state changes (signed in, signed out, token refreshed).
  Stream<AuthState> get authStateChanges;

  /// Whether a user is currently signed in.
  bool get isAuthenticated;

  /// Signs up a new user using [email] and [password].
  Future<User?> signUp({required String email, required String password});

  /// Signs in an existing user using [email] and [password].
  Future<User?> signIn({required String email, required String password});

  /// Signs out the currently authenticated user.
  Future<void> signOut();
}
