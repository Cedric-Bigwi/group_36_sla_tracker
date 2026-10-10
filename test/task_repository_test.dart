import 'package:flutter_test/flutter_test.dart';
import 'package:on_track/core/utils/app_exception.dart';
import 'package:on_track/data/db/app_database.dart';
import 'package:on_track/data/models/activity_entry.dart';
import 'package:on_track/data/models/enums.dart';
import 'package:on_track/data/models/subtask.dart';
import 'package:on_track/data/models/task.dart';
import 'package:on_track/data/repositories/activity_repository.dart';
import 'package:on_track/data/repositories/member_repository.dart';
import 'package:on_track/data/repositories/project_repository.dart';
import 'package:on_track/data/repositories/task_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  final now = DateTime.utc(2026, 3, 10, 12);

  late AppDatabase appDb;
  late TaskRepository tasks;
  late MemberRepository members;
  late ActivityRepository activity;
  late String projectId;
  late String managerId;
  late String memberId;

  Task make(String id, {String? assignee, String title = 'Task'}) => Task(
        id: id,
        projectId: projectId,
        title: title,
        category: 'Mobile',
        assigneeId: assignee,
        createdBy: managerId,
        priority: Priority.medium,
        status: TaskStatus.todo,
        progress: 0,
        startDate: now,
        dueDate: now.add(const Duration(days: 3)),
        createdAt: now,
        updatedAt: now,
      );

  ActivityEntry log(String id, String? taskId, ActivityType type) => ActivityEntry(
        id: id,
        taskId: taskId,
        actorId: managerId,
        type: type,
        detail: 'x',
        createdAt: now,
      );

  setUp(() async {
    // Fresh in-memory database per test; seeded so members/project exist.
    appDb = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
      clock: () => now,
    );
    tasks = TaskRepository(appDb.db, clock: () => now);
    members = MemberRepository(appDb.db);
    activity = ActivityRepository(appDb.db);
    projectId = (await ProjectRepository(appDb.db).getDefault())!.id;
    final all = await members.getAll();
    managerId = all.firstWhere((m) => m.isManager).id;
    memberId = all.firstWhere((m) => !m.isManager).id;
    // Start from an empty task table so counts are exact.
    await appDb.db.delete('activity');
    await appDb.db.delete('subtasks');
    await appDb.db.delete('tasks');
  });

  tearDown(() => appDb.close());

  test('seed creates a project, 5 members and ~12+ tasks on first launch', () async {
    // In-memory databases are shared per path, so close the setUp one first.
    await appDb.close();
    final fresh = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
      clock: () => now,
    );
    expect((await MemberRepository(fresh.db).getAll()).length, 5);
    expect((await TaskRepository(fresh.db).getAll()).length, greaterThanOrEqualTo(12));
    await fresh.close();
  });

  test('insert then read back equal task', () async {
    final t = make('t1', assignee: memberId);
    await tasks.insert(t, activity: [log('a1', 't1', ActivityType.created)]);
    expect(await tasks.getById('t1'), t);
    expect((await activity.forTask('t1')).length, 1);
  });

  test('update persists changes and writes activity atomically', () async {
    await tasks.insert(make('t1'), activity: []);
    final updated = make('t1').copyWith(
      title: 'Renamed',
      status: TaskStatus.inProgress,
      progress: 40,
    );
    await tasks.update(updated, activity: [log('a1', 't1', ActivityType.edited)]);
    final back = await tasks.getById('t1');
    expect(back!.title, 'Renamed');
    expect(back.progress, 40);
    expect((await activity.forTask('t1')).single.entry.type, ActivityType.edited);
  });

  test('a failing activity insert rolls the task update back', () async {
    await tasks.insert(make('t1'), activity: []);
    final bad = ActivityEntry(
      id: 'bad',
      actorId: 'no-such-member', // violates the foreign key
      type: ActivityType.edited,
      createdAt: now,
    );
    await expectLater(
      tasks.update(make('t1').copyWith(title: 'Changed'), activity: [bad]),
      throwsA(isA<AppException>()),
    );
    expect((await tasks.getById('t1'))!.title, 'Task');
  });

  test('delete cascades to subtasks and task activity', () async {
    await tasks.insert(
      make('t1'),
      subtasks: const [Subtask(id: 's1', taskId: 't1', title: 'a', position: 0)],
      activity: [log('a1', 't1', ActivityType.created)],
    );
    await tasks.delete('t1', log: log('a2', null, ActivityType.deleted));

    expect(await tasks.getById('t1'), isNull);
    expect(await tasks.getSubtasks('t1'), isEmpty);
    final all = await activity.list();
    // The task-bound entry cascaded away; the "deleted" entry survives.
    expect(all.map((e) => e.entry.id), ['a2']);
  });

  test('query by assignee', () async {
    await tasks.insert(make('t1', assignee: memberId), activity: []);
    await tasks.insert(make('t2', assignee: memberId, title: 'Two'), activity: []);
    await tasks.insert(make('t3', assignee: managerId, title: 'Three'), activity: []);
    await tasks.insert(make('t4', title: 'Four'), activity: []);

    expect((await tasks.getByAssignee(memberId)).map((t) => t.id), unorderedEquals(['t1', 't2']));
    expect((await tasks.getByAssignee(managerId)).length, 1);
  });

  test('removing a member unassigns their tasks and keeps history', () async {
    await tasks.insert(make('t1', assignee: memberId), activity: []);
    await members.delete(memberId, reassignHistoryTo: managerId);
    expect((await tasks.getById('t1'))!.assigneeId, isNull);
    expect(await members.getById(memberId), isNull);
  });

  test('progress CHECK constraint rejects values over 100', () async {
    await expectLater(
      tasks.insert(make('t1').copyWith(progress: 101), activity: []),
      throwsA(isA<AppException>()),
    );
  });

  test('subtask changes derive task progress', () async {
    await tasks.insert(make('t1'), activity: []);
    for (var i = 0; i < 4; i++) {
      await tasks.addSubtask(Subtask(id: 's$i', taskId: 't1', title: 'S$i', position: i));
    }
    var subs = await tasks.getSubtasks('t1');
    await tasks.setSubtaskDone(subs[0], true);
    expect((await tasks.getById('t1'))!.progress, 25);
    await tasks.setSubtaskDone(subs[1], true);
    expect((await tasks.getById('t1'))!.progress, 50);
    subs = await tasks.getSubtasks('t1');
    await tasks.deleteSubtask(subs[3]); // 2 of 3 done
    expect((await tasks.getById('t1'))!.progress, 67);
  });

  test('title duplicate check is case-insensitive and can exclude itself', () async {
    await tasks.insert(make('t1', title: 'Login Screen'), activity: []);
    expect(await tasks.titleExists(projectId, 'login screen'), isTrue);
    expect(await tasks.titleExists(projectId, 'login screen', excludeId: 't1'), isFalse);
    expect(await tasks.titleExists(projectId, 'other'), isFalse);
  });

  test('reset demo data restores the seed', () async {
    await appDb.resetDemoData();
    expect((await members.getAll()).length, 5);
    expect((await tasks.getAll()).length, greaterThanOrEqualTo(12));
  });
}
