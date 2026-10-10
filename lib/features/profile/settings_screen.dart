import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../state/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _reset(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final router = GoRouter.of(context);
    final ok = await showConfirmDialog(
      context,
      title: 'Reset demo data?',
      message:
          'All tasks, members and activity are replaced with the original '
          'demo data, and you will be signed out.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final done = await runAction(context, settings.resetDemoData);
    if (done) router.go(Routes.signIn);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Appearance', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Dark'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('System'),
                  ),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (s) => settings.setThemeMode(s.first),
              ),
              const SizedBox(height: 32),
              Text('Demo data', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Restore the original sample project, team and tasks. Task dates are '
                'regenerated relative to today.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _reset(context),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset demo data'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
