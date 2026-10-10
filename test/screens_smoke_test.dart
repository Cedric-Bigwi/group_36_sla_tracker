import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:on_track/app.dart';
import 'package:on_track/data/models/enums.dart';
import 'package:on_track/domain/task_item.dart';
import 'package:on_track/features/tasks/task_details_screen.dart';
import 'package:on_track/features/tasks/widgets/task_card.dart';

import 'helpers/test_env.dart';

/// Visits every screen on a small phone (360 dp) at 1.3x text scale, in light
/// and dark, as a manager and as a plain member. Flutter fails a test on any
/// layout overflow or build exception, so this guards the responsive and
/// accessibility requirements.
void main() {
  /// Collects framework errors (overflow etc.) with the offending source line
  /// instead of stopping at the first one.
  final captured = <String>[];
  late void Function(FlutterErrorDetails)? originalOnError;
  String where = '';

  void startCapture() {
    captured.clear();
    originalOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      final text = d.toDiagnosticsNode().toStringDeep();
      final src = RegExp(r'lib/[\w/]+\.dart:\d+').allMatches(text).map((m) => m.group(0)).toSet();
      final first = d.exception.toString().split('\n').first;
      captured.add('[$where] $first ${src.join(', ')}');
    };
  }

  void stopCapture() {
    FlutterError.onError = originalOnError;
    expect(captured.toSet().toList(), isEmpty);
  }

  Future<TestEnv> boot(
    WidgetTester tester, {
    required String user,
    required ThemeMode theme,
    Size size = const Size(360, 740),
    double textScale = 1.3,
    bool capture = false,
  }) async {
    where = 'boot';
    if (capture) startCapture();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final env = (await tester.runAsync(TestEnv.create))!;
    addTearDown(() async => tester.runAsync(env.dispose));
    await tester.runAsync(() => env.prefs.setString('session_user_id', env.member(user).id));
    await tester.runAsync(() => env.providers.settings.setThemeMode(theme));
    await tester.pumpWidget(env.providers.wrap(const OnTrackApp()));
    await settle(tester, rounds: 25);
    return env;
  }

  Future<void> go(WidgetTester tester, String location) async {
    where = location;
    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).go(location);
    await settle(tester, rounds: 8);
  }

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    for (final user in ['Ali', 'Brenda']) {
      testWidgets('every screen renders: $user, ${theme.name}, 360dp, text x1.3', (tester) async {
        final env = await boot(tester, user: user, theme: theme, capture: true);
        final tasks = env.providers.tasks.items;
        TaskItem pick(bool Function(TaskItem) f) => tasks.firstWhere(f);
        final overdue = pick((i) => i.sla.state == SlaState.overdue);
        final done = pick((i) => i.sla.state == SlaState.completed);
        final withSubs = pick((i) => i.hasSubtasks);
        final unassigned = pick((i) => i.task.assigneeId == null);

        final routes = [
          '/home',
          '/tasks',
          '/team',
          '/profile',
          '/profile/edit',
          '/settings',
          '/about',
          '/statistics',
          '/activity',
          '/tasks/new',
          '/tasks/${overdue.id}',
          '/tasks/${done.id}',
          '/tasks/${withSubs.id}',
          '/tasks/${unassigned.id}',
          '/tasks/${overdue.id}/edit',
          '/tasks/${withSubs.id}/edit',
          '/team/${env.member('Chen').id}',
          '/team/${env.member('Ali').id}/edit',
          '/team/new',
          '/tasks/does-not-exist',
          '/team/does-not-exist',
        ];
        for (final r in routes) {
          await go(tester, r);
        }
        // Unknown ids show friendly empty states instead of crashing.
        await go(tester, '/tasks/does-not-exist');
        expect(find.text('Task not found'), findsOneWidget);
        stopCapture();
      });
    }
  }

  testWidgets('sign-in and sign-up screens render at 360dp x1.3', (tester) async {
    final env = await boot(tester, user: 'Ali', theme: ThemeMode.light);
    await tester.runAsync(env.providers.session.signOut);
    await settle(tester, rounds: 5);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Sign in with email'));
    await tester.tap(find.text('Sign in with email'));
    await settle(tester, rounds: 5);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Choose from the team instead'));
    await tester.tap(find.text('Choose from the team instead'));
    await settle(tester, rounds: 5);
    await tester.tap(find.text('Chen'));
    await settle(tester, rounds: 5);
    expect(find.text('Enter your 4-digit PIN'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await go(tester, '/sign-up');
    expect(find.text('Create account'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unauthenticated users cannot reach protected routes', (tester) async {
    final env = await boot(tester, user: 'Ali', theme: ThemeMode.light);
    await tester.runAsync(env.providers.session.signOut);
    await settle(tester, rounds: 5);
    for (final r in ['/home', '/tasks', '/tasks/new', '/team', '/statistics']) {
      await go(tester, r);
      expect(find.text("Who's working today?"), findsOneWidget, reason: '$r should redirect');
    }
  });

  group('task list gestures', () {
    testWidgets('swipe right marks done with Undo; Undo restores it', (tester) async {
      final env = await boot(tester, user: 'Ali', theme: ThemeMode.light, textScale: 1.0);
      await go(tester, '/tasks');
      // First card = most urgent open task (default sort).
      final target = env.providers.tasks.visibleTasks.first;
      expect(target.sla.state, isNot(SlaState.completed));

      await tester.drag(find.byType(TaskCard).first, const Offset(500, 0));
      await settle(tester, rounds: 10);

      expect(env.providers.tasks.itemById(target.id)!.sla.state, SlaState.completed);
      expect(find.text('Undo'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester, rounds: 10);
      expect(env.providers.tasks.itemById(target.id)!.task.status, target.task.status);
      expect(env.providers.tasks.itemById(target.id)!.task.completedAt, isNull);
    });

    testWidgets('swipe left as a member on someone else\'s task is blocked', (tester) async {
      final env = await boot(tester, user: 'Brenda', theme: ThemeMode.light, textScale: 1.0);
      final before = env.providers.tasks.items.length;
      await go(tester, '/tasks');

      final card = find.byType(TaskCard).first;
      await tester.drag(card, const Offset(-500, 0));
      await settle(tester, rounds: 10);

      expect(find.textContaining("can't delete"), findsOneWidget);
      expect(find.text('Delete task?'), findsNothing); // no confirm dialog either
      expect(env.providers.tasks.items.length, before);
    });

    testWidgets('swipe left as manager asks to confirm, then deletes', (tester) async {
      final env = await boot(tester, user: 'Ali', theme: ThemeMode.light, textScale: 1.0);
      final before = env.providers.tasks.items.length;
      await go(tester, '/tasks');

      await tester.drag(find.byType(TaskCard).first, const Offset(-500, 0));
      await settle(tester, rounds: 8);
      expect(find.text('Delete task?'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
      await settle(tester, rounds: 10);
      expect(env.providers.tasks.items.length, before - 1);
    });

    testWidgets('search is debounced and empty results offer Clear filters', (tester) async {
      final env = await boot(tester, user: 'Ali', theme: ThemeMode.light, textScale: 1.0);
      await go(tester, '/tasks');

      await tester.enterText(find.byType(SearchBar), 'zzzz-nothing');
      await tester.pump(const Duration(milliseconds: 100));
      expect(env.providers.tasks.filter.query, isEmpty, reason: 'still inside the 300 ms debounce');
      await settle(tester, rounds: 5);
      expect(env.providers.tasks.filter.query, 'zzzz-nothing');
      expect(find.text('No tasks match your filters'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await settle(tester, rounds: 5);
      expect(find.byType(TaskCard), findsWidgets);
    });
  });

  testWidgets('open a task (Hero), edit it from the menu, save, see the change logged',
      (tester) async {
    final env = await boot(tester, user: 'Ali', theme: ThemeMode.light, textScale: 1.0);
    await go(tester, '/tasks');
    final target = env.providers.tasks.visibleTasks.first;

    await tester.tap(find.byType(TaskCard).first);
    await settle(tester, rounds: 10);
    expect(find.text('Task details'), findsOneWidget);
    expect(find.text(target.task.title), findsWidgets);
    // The SLA panel explains the state in words.
    expect(find.text(target.sla.reason), findsOneWidget);

    await tester.tap(find.byTooltip('Task actions'));
    await settle(tester, rounds: 3);
    await tester.tap(find.text('Edit'));
    await settle(tester, rounds: 8);
    expect(find.text('Edit task'), findsOneWidget);
    // Pre-filled with the current values.
    expect(find.widgetWithText(TextFormField, target.task.title), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Renamed by test');
    final save = find.text('Save changes');
    // The form is a lazy list: scroll until the button is built.
    await tester.scrollUntilVisible(save, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(save);
    await settle(tester, rounds: 12);

    expect(env.providers.tasks.itemById(target.id)!.task.title, 'Renamed by test');
    expect(find.text('Task details'), findsOneWidget, reason: 'popped back to the details page');
    final log = env.providers.activity.all.first.entry;
    expect(log.type, ActivityType.edited);
    expect(log.detail, contains('Renamed by test'));
  });

  testWidgets('tablet layout shows list and details side by side', (tester) async {
    final env = await boot(
      tester,
      user: 'Ali',
      theme: ThemeMode.light,
      size: const Size(1100, 800),
      textScale: 1.0,
    );
    await go(tester, '/tasks');
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Select a task'), findsOneWidget);

    await tester.tap(find.byType(TaskCard).first);
    await settle(tester, rounds: 8);
    expect(find.byType(TaskDetailsScreen), findsOneWidget);
    expect(find.text('Select a task'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(env.providers.tasks.items, isNotEmpty);
  });
}
