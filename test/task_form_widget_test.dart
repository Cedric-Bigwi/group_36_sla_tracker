import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:on_track/core/utils/date_utils.dart';
import 'package:on_track/features/tasks/task_form_screen.dart';

import 'helpers/test_env.dart';

void main() {
  late TestEnv env;

  // Frozen "now" (UTC) so date picking in the test is deterministic.
  final frozen = DateTime.utc(2026, 3, 10, 12);

  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpForm(WidgetTester tester) async {
    phoneSize(tester);
    env = (await tester.runAsync(() => TestEnv.create(clock: () => frozen)))!;
    addTearDown(() async => tester.runAsync(env.dispose));
    await tester.runAsync(() => env.signInAs('Ali'));

    // go_router (with a /tasks fallback) because the form leaves via the router.
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const TaskFormScreen()),
      GoRoute(path: '/tasks', builder: (_, _) => const Scaffold(body: Text('task list'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(env.providers.wrap(MaterialApp.router(routerConfig: router)));
    await settle(tester, rounds: 3);
  }

  testWidgets('submitting an empty form shows validation errors', (tester) async {
    await pumpForm(tester);

    final submit = find.text('Create task');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(find.text('Title is required'), findsOneWidget);
    expect(find.text('Category is required'), findsOneWidget);
    // Nothing was saved.
    expect(env.providers.tasks.items.length, 14);
  });

  testWidgets('title length rules: too short is rejected, valid input clears the error',
      (tester) async {
    await pumpForm(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'ab');
    await tester.pump();
    expect(find.text('Title must be at least 3 characters'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Write docs');
    await tester.pump();
    expect(find.text('Title must be at least 3 characters'), findsNothing);
  });

  testWidgets('due date before start date is rejected', (tester) async {
    await pumpForm(tester);

    // Due = "In 10 h" (10 Mar), then move the start date to 20 Mar via the picker.
    await tester.tap(find.text('In 10 h'));
    await tester.pump();

    // Tap the start field via its current value text (the label ignores taps).
    await tester.tap(find.text(formatDateTime(frozen)));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('20'));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Due date must not be before the start date'), findsOneWidget);
  });

  testWidgets('live SLA preview reacts to the inputs', (tester) async {
    await pumpForm(tester);

    // Default: due in 3 days, medium priority → On Track.
    expect(find.text('This task would be:'), findsOneWidget);
    expect(find.text('On Track'), findsWidgets);

    await tester.tap(find.text('In 10 h'));
    await tester.pump();
    // Medium priority is flagged within 24 h → At Risk.
    expect(find.text('At Risk'), findsWidgets);
    expect(find.textContaining('Due in 10 h'), findsOneWidget);
  });

  testWidgets('a valid form saves the task', (tester) async {
    await pumpForm(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Ship the demo');
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Docs').last);
    await tester.pumpAndSettle();

    final submit = find.text('Create task');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await settle(tester, rounds: 10);

    expect(env.providers.tasks.items.any((i) => i.task.title == 'Ship the demo'), isTrue);
  });
}
