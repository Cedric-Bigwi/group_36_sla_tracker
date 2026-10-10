import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/activity_provider.dart';
import '../../state/member_provider.dart';
import '../../state/session_provider.dart';
import '../../state/task_provider.dart';

/// First screen: loads data, restores the saved session, then the router's
/// redirect sends the user to Home or Sign In.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final members = context.read<MemberProvider>();
    final tasks = context.read<TaskProvider>();
    final activity = context.read<ActivityProvider>();
    final session = context.read<SessionProvider>();
    await Future.wait([
      members.load(),
      tasks.load(),
      activity.load(),
      // Keep the brand visible for a moment so the screen never just flashes.
      Future<void>.delayed(const Duration(milliseconds: 700)),
    ]);
    await session.restore(); // triggers the router redirect
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.onPrimary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.track_changes,
                size: 56,
                color: scheme.onPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'On Track',
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(color: scheme.onPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Projects and SLAs, in one place',
              style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: scheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
