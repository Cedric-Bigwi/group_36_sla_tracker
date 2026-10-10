import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/activity/activity_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/profile/about_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/settings_screen.dart';
import '../../features/statistics/statistics_screen.dart';
import '../../features/tasks/task_details_screen.dart';
import '../../features/tasks/task_form_screen.dart';
import '../../features/tasks/task_list_screen.dart';
import '../../features/team/member_detail_screen.dart';
import '../../features/team/member_form_screen.dart';
import '../../features/team/team_list_screen.dart';
import '../../state/session_provider.dart';
import 'app_shell.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const home = '/home';
  static const tasks = '/tasks';
  static const team = '/team';
  static const profile = '/profile';
  static const statistics = '/statistics';
  static const activity = '/activity';
  static const settings = '/settings';
  static const about = '/about';
  static String task(String id) => '/tasks/$id';
  static String taskEdit(String id) => '/tasks/$id/edit';
  static const taskNew = '/tasks/new';
  static String member(String id) => '/team/$id';
  static String memberEdit(String id) => '/team/$id/edit';
  static const memberNew = '/team/new';
  static const profileEdit = '/profile/edit';
}

/// Routes reachable without being signed in.
const Set<String> _publicRoutes = {Routes.splash, Routes.signIn, Routes.signUp};

GoRouter createRouter(SessionProvider session) {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  // Detail and form screens are pushed on the ROOT navigator so they cover the
  // bottom navigation bar.
  GoRoute full(String path, Widget Function(GoRouterState s) builder) =>
      GoRoute(
        path: path,
        parentNavigatorKey: rootKey,
        builder: (_, state) => builder(state),
      );

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: Routes.splash,
    // Re-run redirect whenever the session changes (sign in / out / restore).
    refreshListenable: session,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      // Until the saved session was read, everyone waits on the splash screen.
      if (!session.isRestored) {
        return loc == Routes.splash ? null : Routes.splash;
      }
      final signedIn = session.isSignedIn;
      // The splash is only a waiting room: once restored, leave it.
      if (loc == Routes.splash) return signedIn ? Routes.home : Routes.signIn;
      if (!signedIn && !_publicRoutes.contains(loc)) return Routes.signIn;
      if (signedIn && _publicRoutes.contains(loc)) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: Routes.signUp,
        builder: (_, _) => const MemberFormScreen(signUp: true),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (_, _) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.tasks,
                builder: (_, _) => const TaskListScreen(),
                routes: [
                  // 'new' must be declared before ':id' so it is not read as an id.
                  full('new', (_) => const TaskFormScreen()),
                  full(
                    ':id',
                    (s) => TaskDetailsScreen(taskId: s.pathParameters['id']!),
                  ),
                  full(
                    ':id/edit',
                    (s) => TaskFormScreen(taskId: s.pathParameters['id']),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.team,
                builder: (_, _) => const TeamListScreen(),
                routes: [
                  full('new', (_) => const MemberFormScreen()),
                  full(
                    ':id',
                    (s) =>
                        MemberDetailScreen(memberId: s.pathParameters['id']!),
                  ),
                  full(
                    ':id/edit',
                    (s) => MemberFormScreen(memberId: s.pathParameters['id']),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (_, _) => const ProfileScreen(),
                routes: [full('edit', (_) => const EditProfileScreen())],
              ),
            ],
          ),
        ],
      ),
      full(Routes.statistics, (_) => const StatisticsScreen()),
      full(Routes.activity, (_) => const ActivityScreen()),
      full(Routes.settings, (_) => const SettingsScreen()),
      full(Routes.about, (_) => const AboutScreen()),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('That page does not exist.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(Routes.home),
                child: const Text('Go home'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
