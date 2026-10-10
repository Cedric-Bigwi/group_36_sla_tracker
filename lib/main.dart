import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/utils/clock.dart';
import 'data/db/app_database.dart';
import 'data/repositories/activity_repository.dart';
import 'data/repositories/member_repository.dart';
import 'data/repositories/project_repository.dart';
import 'data/repositories/task_repository.dart';
import 'state/activity_provider.dart';
import 'state/member_provider.dart';
import 'state/session_provider.dart';
import 'state/settings_provider.dart';
import 'state/task_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error logging: framework errors and uncaught async/platform errors.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    return true;
  };

  // Open storage before the first frame: SQLite for relational data (created
  // and seeded on first launch) and SharedPreferences for session + theme.
  final prefs = await SharedPreferences.getInstance();
  final db = await AppDatabase.open();

  runApp(AppProviders.create(prefs: prefs, db: db).wrap(const OnTrackApp()));
}

/// Wires repositories → providers once. Tests build the same graph on top of
/// an in-memory database (optionally with a frozen [clock]).
class AppProviders {
  AppProviders._({
    required this.session,
    required this.members,
    required this.tasks,
    required this.activity,
    required this.settings,
  });

  factory AppProviders.create({
    required SharedPreferences prefs,
    required AppDatabase db,
    Clock clock = systemClock,
  }) {
    final memberRepo = MemberRepository(db.db);
    final taskRepo = TaskRepository(db.db, clock: clock);
    final projectRepo = ProjectRepository(db.db);
    final activityRepo = ActivityRepository(db.db);

    final session = SessionProvider(prefs, memberRepo, clock: clock);
    final members = MemberProvider(memberRepo, session, clock: clock);
    final tasks = TaskProvider(
      tasks: taskRepo,
      projects: projectRepo,
      session: session,
      members: members,
      clock: clock,
    );
    final activity = ActivityProvider(activityRepo, tasks);
    final settings = SettingsProvider(prefs, db);

    members.onTasksAffected = () => tasks.load(silent: true);
    settings.onDataReset = () async {
      await session.signOut();
      await members.load();
      await tasks.load();
      await activity.load();
    };

    return AppProviders._(
      session: session,
      members: members,
      tasks: tasks,
      activity: activity,
      settings: settings,
    );
  }

  final SessionProvider session;
  final MemberProvider members;
  final TaskProvider tasks;
  final ActivityProvider activity;
  final SettingsProvider settings;

  Widget wrap(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider<SessionProvider>.value(value: session),
      ChangeNotifierProvider<MemberProvider>.value(value: members),
      ChangeNotifierProvider<TaskProvider>.value(value: tasks),
      ChangeNotifierProvider<ActivityProvider>.value(value: activity),
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
    ],
    child: child,
  );
}
