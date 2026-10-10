import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_track/data/db/app_database.dart';
import 'package:on_track/data/models/enums.dart';
import 'package:on_track/data/repositories/member_repository.dart';
import 'package:on_track/data/repositories/task_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Demo step 8: "kill the app, reopen, everything is still there".
/// Uses a real database FILE and closes/reopens it like an app restart.
void main() {
  sqfliteFfiInit();
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('on_track_test');
    path = p.join(dir.path, 'on_track.db');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<AppDatabase> open() => AppDatabase.open(path: path, factory: databaseFactoryFfi);

  test('changes survive closing and reopening; seed is not re-applied', () async {
    var db = await open();
    var repo = TaskRepository(db.db);
    final seeded = await repo.getAll();
    final target = seeded.firstWhere((t) => !t.isDone);
    await repo.update(target.copyWith(status: TaskStatus.inReview, progress: 77));
    await db.close();

    db = await open(); // "restart"
    repo = TaskRepository(db.db);
    final after = await repo.getAll();
    expect(after.length, seeded.length, reason: 'seed must run only on first launch');
    final back = after.firstWhere((t) => t.id == target.id);
    expect(back.status, TaskStatus.inReview);
    expect(back.progress, 77);
    expect((await MemberRepository(db.db).getAll()).length, 5);
    await db.close();
  });

  test('foreign keys are enforced on every connection', () async {
    final db = await open();
    final rows = await db.db.rawQuery('PRAGMA foreign_keys');
    expect(rows.first.values.first, 1);
    await db.close();
  });
}
