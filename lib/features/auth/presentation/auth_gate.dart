import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../application/app_navigation_shell.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import 'login_page.dart';

/// Top-level authentication router.
///
/// Directs users to [AppNavigationShell] when authenticated or in Demo Mode,
/// or to [LoginPage] when unauthenticated. Listens to [AuthRepository.authStateChanges]
/// to update UI reactively on sign-in or sign-out.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.authRepository,
    this.initialDemoMode,
  });

  final AuthRepository? authRepository;
  final bool? initialDemoMode;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;
  late final AuthRepository _auth;
  late bool _isDemoMode;

  @override
  void initState() {
    super.initState();
    _auth = widget.authRepository ?? AuthService();

    if (widget.initialDemoMode != null) {
      _isDemoMode = widget.initialDemoMode!;
    } else if (widget.authRepository != null) {
      _isDemoMode = false;
    } else {
      _isDemoMode = !SupabaseService.instance.isInitialized;
    }

    _authSubscription = _auth.authStateChanges.listen((data) {
      if (mounted) {
        setState(() {
          if (data.event == AuthChangeEvent.signedIn) {
            _isDemoMode = false;
          } else if (data.event == AuthChangeEvent.signedOut) {
            _isDemoMode = false;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleSignOut() async {
    await _auth.signOut();
    if (mounted) {
      setState(() => _isDemoMode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = _auth.currentUser != null;

    if (isAuthenticated || _isDemoMode) {
      return AppNavigationShell(
        authRepository: _auth,
        onSignOut: _handleSignOut,
      );
    }

    return LoginPage(
      authRepository: _auth,
      onLoginSuccess: () {
        if (mounted) {
          setState(() => _isDemoMode = false);
        }
      },
      onDemoMode: () {
        if (mounted) {
          setState(() => _isDemoMode = true);
        }
      },
    );
  }
}
