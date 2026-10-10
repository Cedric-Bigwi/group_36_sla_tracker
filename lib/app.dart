import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'state/session_provider.dart';
import 'state/settings_provider.dart';
import 'state/task_provider.dart';

class OnTrackApp extends StatefulWidget {
  const OnTrackApp({super.key});

  @override
  State<OnTrackApp> createState() => _OnTrackAppState();
}

class _OnTrackAppState extends State<OnTrackApp> {
  late final GoRouter _router;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _router = createRouter(context.read<SessionProvider>());
    // SLA state depends on the clock, so when the app returns to the foreground
    // (maybe hours later) reload and re-evaluate every task.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        final tasks = context.read<TaskProvider>();
        if (context.read<SessionProvider>().isSignedIn) {
          tasks.load(silent: true);
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<SettingsProvider, ThemeMode>(
      (s) => s.themeMode,
    );
    return MaterialApp.router(
      title: 'On Track',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
