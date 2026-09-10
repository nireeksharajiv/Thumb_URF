import 'package:flutter/material.dart';

class MorePage extends StatelessWidget {
  const MorePage({required this.onSectionSelected, super.key});

  final ValueChanged<int> onSectionSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('More', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        _MoreItem(
          icon: Icons.timer_outlined,
          title: 'Sessions',
          onTap: () => onSectionSelected(0),
        ),
        _MoreItem(
          icon: Icons.insights_outlined,
          title: 'Analytics',
          onTap: () => onSectionSelected(1),
        ),
        _MoreItem(
          icon: Icons.lightbulb_outline,
          title: 'Recommendations',
          onTap: () => onSectionSelected(2),
        ),
        _MoreItem(
          icon: Icons.settings_outlined,
          title: 'Settings',
          onTap: () => onSectionSelected(3),
        ),
      ],
    ),
  );
}

class _MoreItem extends StatelessWidget {
  const _MoreItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
