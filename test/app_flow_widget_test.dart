import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_track/app.dart';
import 'package:on_track/core/widgets/stat_card.dart';
import 'package:on_track/data/models/enums.dart';
import 'package:on_track/features/tasks/widgets/task_card.dart';

import 'helpers/test_env.dart';

void main() {
  late TestEnv env;

  Future<void> tapPin(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(find.text(d).first);
      await tester.pump();
    }
  }

  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('cold start → pick member → wrong then right PIN → dashboard → Overdue list',
      (tester) async {
    phoneSize(tester);
    env = (await tester.runAsync(TestEnv.create))!;
    addTearDown(() async => tester.runAsync(env.dispose));

    await tester.pumpWidget(env.providers.wrap(const OnTrackApp()));
    await settle(tester, rounds: 25); // splash

    // Signed out → redirected to the user selection screen.
    expect(find.text("Who's working today?"), findsOneWidget);
    expect(find.text('Demo: PIN is 1234'), findsOneWidget);

    await tester.tap(find.text('Brenda'));
    await settle(tester);
    expect(find.text('Enter your 4-digit PIN'), findsOneWidget);

    // Wrong PIN → inline error, field cleared.
    await tapPin(tester, '9999');
    await settle(tester);
    expect(find.textContaining('Incorrect PIN'), findsOneWidget);

    // Right PIN → router guard lets us through to the dashboard.
    await tapPin(tester, '1234');
    await settle(tester, rounds: 20);
    expect(find.textContaining(', Brenda'), findsOneWidget);
    expect(find.text('Needs attention'), findsOneWidget);

    // All four SLA summary cards are present.
    for (final s in SlaState.values) {
      expect(find.widgetWithText(StatCard, s.label), findsOneWidget);
    }

    // Tap Overdue → Tasks tab pre-filtered to Overdue.
    await tester.tap(find.widgetWithText(StatCard, 'Overdue'));
    await settle(tester);
    expect(find.byType(TaskCard), findsNWidgets(2));
    expect(find.text('Accessibility audit'), findsOneWidget);
    expect(find.text('Write regression test plan'), findsOneWidget);
  });

  testWidgets('a saved session skips sign-in and lands on the dashboard', (tester) async {
    phoneSize(tester);
    env = (await tester.runAsync(TestEnv.create))!;
    addTearDown(() async => tester.runAsync(env.dispose));
    await tester.runAsync(() => env.signInAs('Chen'));
    // Simulate a fresh process: same prefs, session not restored yet.
    await tester.runAsync(() => env.providers.session.signOut());
    await tester.runAsync(() => env.prefs.setString('session_user_id', env.member('Chen').id));

    await tester.pumpWidget(env.providers.wrap(const OnTrackApp()));
    await settle(tester, rounds: 25);

    expect(find.textContaining(', Chen'), findsOneWidget);
  });

  testWidgets('dark theme and bottom navigation work', (tester) async {
    phoneSize(tester);
    env = (await tester.runAsync(TestEnv.create))!;
    addTearDown(() async => tester.runAsync(env.dispose));
    await tester.runAsync(() => env.prefs.setString('session_user_id', env.member('Ali').id));
    await tester.runAsync(() => env.providers.settings.setThemeMode(ThemeMode.dark));

    await tester.pumpWidget(env.providers.wrap(const OnTrackApp()));
    await settle(tester, rounds: 25);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);

    for (final tab in ['Tasks', 'Team', 'Profile', 'Home']) {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
      await settle(tester, rounds: 5);
    }
    expect(find.textContaining(', Ali'), findsOneWidget);

    // Statistics and activity screens render with the seeded data.
    await tester.tap(find.byTooltip('Statistics'));
    await settle(tester, rounds: 8);
    expect(find.text('Tasks per SLA state'), findsOneWidget);
    expect(find.text('Upcoming deadlines (next 7 days)'), findsOneWidget);
  });
}
