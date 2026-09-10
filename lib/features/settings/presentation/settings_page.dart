import 'package:flutter/material.dart';

import '../../../core/services/auth_repository.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/app_section_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    this.authRepository,
    this.onSignOut,
  });

  final AuthRepository? authRepository;
  final VoidCallback? onSignOut;

  AuthRepository get _auth => authRepository ?? AuthService();

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),

            // Account section
            AppSectionCard(
              child: ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(user != null ? 'Account' : 'Account (Demo Mode)'),
                subtitle: Text(
                  user?.email ?? 'Offline session — not signed in to Supabase cloud.',
                ),
                trailing: OutlinedButton(
                  key: const Key('settings_sign_out_button'),
                  onPressed: onSignOut,
                  child: Text(user != null ? 'Sign Out' : 'Sign In'),
                ),
              ),
            ),
            const SizedBox(height: 12),

            const AppSectionCard(
              child: ListTile(
                leading: Icon(Icons.science_outlined),
                title: Text('Demo Mode'),
                subtitle: Text('Simulated research data is active.'),
              ),
            ),
            const SizedBox(height: 12),
            const AppSectionCard(
              child: ListTile(
                leading: Icon(Icons.tune_outlined),
                title: Text('Monitoring preferences'),
                subtitle: Text('Preferences will be available in a later step.'),
              ),
            ),
            const SizedBox(height: 12),
            const AppSectionCard(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('About this project'),
                subtitle: Text('Engineering research monitoring application.'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
