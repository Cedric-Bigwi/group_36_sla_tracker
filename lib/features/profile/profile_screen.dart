import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/avatar_circle.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../domain/stats/task_stats.dart';
import '../../state/session_provider.dart';
import '../../state/task_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final session = context.read<SessionProvider>();
    final ok = await showConfirmDialog(
      context,
      title: 'Sign out?',
      message: 'You will need your PIN to sign back in.',
      confirmLabel: 'Sign out',
    );
    if (!ok || !context.mounted) return;
    await session.signOut(); // clears the saved session key
    if (context.mounted) context.go(Routes.signIn);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionProvider>().user;
    final tasks = context.watch<TaskProvider>();
    final theme = Theme.of(context);
    if (user == null) return const Scaffold();
    final stats = memberStats(tasks.items, user.id);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      AvatarCircle.member(user, size: 72),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name, style: theme.textTheme.titleLarge),
                            Text(user.jobTitle),
                            Text(user.email, style: theme.textTheme.bodySmall),
                            const SizedBox(height: 8),
                            RoleBadge(role: user.role),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    // Expanded so labels can wrap at large text scales.
                    children: [
                      _Number(label: 'Open', value: '${stats.open}'),
                      _Number(label: 'Overdue', value: '${stats.overdue}'),
                      _Number(label: 'Completed', value: '${stats.completed}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    _tile(
                      context,
                      Icons.edit_outlined,
                      'Edit profile',
                      () => context.push(Routes.profileEdit),
                    ),
                    const Divider(height: 1),
                    _tile(
                      context,
                      Icons.bar_chart,
                      'Statistics',
                      () => context.push(Routes.statistics),
                    ),
                    const Divider(height: 1),
                    _tile(
                      context,
                      Icons.history,
                      'Activity feed',
                      () => context.push(Routes.activity),
                    ),
                    const Divider(height: 1),
                    _tile(
                      context,
                      Icons.settings_outlined,
                      'Settings',
                      () => context.push(Routes.settings),
                    ),
                    const Divider(height: 1),
                    _tile(
                      context,
                      Icons.info_outline,
                      'About & SLA rules',
                      () => context.push(Routes.about),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class _Number extends StatelessWidget {
  const _Number({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value, style: theme.textTheme.headlineSmall),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
