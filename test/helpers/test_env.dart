import 'package:flutter_test/flutter_test.dart';
import 'package:on_track/core/utils/clock.dart';
import 'package:on_track/data/db/app_database.dart';
import 'package:on_track/data/models/team_member.dart';
import 'package:on_track/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A complete app graph (in-memory seeded SQLite + mocked SharedPreferences +
/// all providers), optionally with a frozen clock.
class TestEnv {
  TestEnv._(this.db, this.providers, this.prefs);

  final AppDatabase db;
  final AppProviders providers;
  final SharedPreferences prefs;

  static Future<TestEnv> create({Clock clock = systemClock}) async {
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
      clock: clock,
    );
    final providers = AppProviders.create(prefs: prefs, db: db, clock: clock);
    await providers.members.load();
    await providers.tasks.load();
    await providers.activity.load();
    return TestEnv._(db, providers, prefs);
  }

  TeamMember member(String firstName) =>
      providers.members.members.firstWhere((m) => m.firstName == firstName);

  /// Signs in without the PIN screen.
  Future<void> signInAs(String firstName) =>
      providers.session.startSession(member(firstName));

  Future<void> dispose() => db.close();
}

/// Lets real async work (SQLite runs in an isolate) and fake-async timers/animations
/// both make progress.
Future<void> settle(WidgetTester tester, {int rounds = 15}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}
