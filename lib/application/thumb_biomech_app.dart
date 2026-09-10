import 'package:flutter/material.dart';

import '../core/services/auth_repository.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/auth_gate.dart';

class ThumbBiomechApp extends StatelessWidget {
  const ThumbBiomechApp({
    super.key,
    this.authRepository,
    this.initialDemoMode,
  });

  final AuthRepository? authRepository;
  final bool? initialDemoMode;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ThumbBiomech Monitor Glove',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: AuthGate(
      authRepository: authRepository,
      initialDemoMode: initialDemoMode,
    ),
  );
}
