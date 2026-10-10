import 'package:flutter_test/flutter_test.dart';
import 'package:on_track/core/utils/app_exception.dart';
import 'package:on_track/data/models/enums.dart';
import 'package:on_track/state/session_provider.dart';
import 'package:on_track/state/task_draft.dart';
import 'package:on_track/state/task_provider.dart';

import 'helpers/test_env.dart';

void main() {
  late TestEnv env;

  setUp(() async => env = await TestEnv.create());
  tearDown(() => env.dispose());

  TaskDraft draft({
    String title = 'Fresh task',
    Priority priority = Priority.medium,
    Duration due = const Duration(days: 5),
    String? assigneeId,
  }) {
    final now = DateTime.now().toUtc();
    return TaskDraft(
      title: title,
      category: 'Mobile',
      assigneeId: assigneeId,
      priority: priority,
      status: TaskStatus.todo,
      startDate: now,
      dueDate: now.add(due),
      progress: 0,
    );
  }

  test('seed shows a mix of all four SLA states', () {
    final counts = env.providers.tasks.slaCounts;
    for (final s in SlaState.values) {
      expect(counts[s], greaterThan(0), reason: '${s.label} should appear in the demo');
    }
  });

  group('permissions are enforced in the provider, not just the UI', () {
    test('a member cannot delete a task they did not create', () async {
      await env.signInAs('Brenda');
      final tasks = env.providers.tasks;
      final target = tasks.items.first.id;
      await expectLater(tasks.deleteTask(target), throwsA(isA<AppException>()));
      expect(tasks.itemById(target), isNotNull);
    });

    test('a manager can delete any task and it is logged', () async {
      await env.signInAs('Ali');
      final tasks = env.providers.tasks;
      final target = tasks.items.first;
      await tasks.deleteTask(target.id);
      expect(tasks.itemById(target.id), isNull);
      await env.providers.activity.load();
      expect(
        env.providers.activity.all.first.entry.type,
        ActivityType.deleted,
      );
    });

    test('a member can delete their own task', () async {
      await env.signInAs('Brenda');
      final tasks = env.providers.tasks;
      final created = await tasks.createTask(draft(assigneeId: env.member('Brenda').id));
      await tasks.deleteTask(created.id);
      expect(tasks.itemById(created.id), isNull);
    });

    test('a member cannot edit an unrelated task', () async {
      await env.signInAs('Brenda');
      final tasks = env.providers.tasks;
      final chens = tasks.items.firstWhere(
        (i) => i.task.assigneeId == env.member('Chen').id && !i.task.isDone,
      );
      await expectLater(
        tasks.setStatus(chens.id, TaskStatus.inReview),
        throwsA(isA<AppException>()),
      );
    });

    test('a member cannot assign a task to someone else, a manager can', () async {
      await env.signInAs('Brenda');
      await expectLater(
        env.providers.tasks.createTask(draft(assigneeId: env.member('Chen').id)),
        throwsA(isA<AppException>()),
      );
      await env.signInAs('Ali');
      final t = await env.providers.tasks.createTask(draft(assigneeId: env.member('Chen').id));
      expect(t.assigneeId, env.member('Chen').id);
    });

    test('only managers can create managers or remove members', () async {
      await env.signInAs('Brenda');
      await expectLater(
        env.providers.members.create(
          name: 'Eve',
          email: 'eve@x.dev',
          jobTitle: 'Dev',
          role: MemberRole.manager,
          pin: '1234',
        ),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        env.providers.members.remove(env.member('Chen')),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('SLA behaviour through the provider (demo script)', () {
    test('a High task due in 10 h is At Risk (rule a) and shows the reason', () async {
      await env.signInAs('Ali');
      final t = await env.providers.tasks.createTask(
        draft(title: 'Hotfix', priority: Priority.high, due: const Duration(hours: 10)),
      );
      final item = env.providers.tasks.itemById(t.id)!;
      expect(item.sla.state, SlaState.atRisk);
      expect(item.sla.reason, contains('High priority'));
    });

    test('raising progress flips a lagging task from At Risk to On Track (rule b)', () async {
      await env.signInAs('Ali');
      final tasks = env.providers.tasks;
      final lagging = tasks.items.firstWhere((i) => i.task.title == 'Write API contract for events');
      // Its due date is ~30 h away, but with 40% progress the lag rule fires.
      expect(lagging.sla.state, SlaState.atRisk);
      // Make the deadline-proximity rule irrelevant by giving it more time.
      await tasks.updateTask(
        lagging.id,
        TaskDraft.fromTask(lagging.task).copyWithDue(DateTime.now().toUtc().add(const Duration(days: 3))),
      );
      expect(tasks.itemById(lagging.id)!.sla.state, SlaState.atRisk); // still behind
      await tasks.setProgress(lagging.id, 90);
      expect(tasks.itemById(lagging.id)!.sla.state, SlaState.onTrack);
    });

    test('marking done completes, reopening clears completedAt', () async {
      await env.signInAs('Ali');
      final tasks = env.providers.tasks;
      final open = tasks.items.firstWhere((i) => i.sla.state == SlaState.onTrack && !i.hasSubtasks);

      final before = await tasks.markDone(open.id);
      var item = tasks.itemById(open.id)!;
      expect(item.sla.state, SlaState.completed);
      expect(item.task.progress, 100);
      expect(item.task.completedAt, isNotNull);

      await tasks.setStatus(open.id, TaskStatus.inProgress);
      item = tasks.itemById(open.id)!;
      expect(item.task.completedAt, isNull);
      expect(item.sla.state, isNot(SlaState.completed));

      // Undo (restore) puts the original task back exactly.
      await tasks.restore(before);
      expect(tasks.itemById(open.id)!.task.status, before.status);
    });

    test('subtasks drive progress; manual progress is rejected', () async {
      await env.signInAs('Ali');
      final tasks = env.providers.tasks;
      final t = tasks.items.firstWhere((i) => i.task.title == 'Release checklist');
      expect(t.subtasks.length, 4);
      expect(t.task.progress, 25);
      await expectLater(tasks.setProgress(t.id, 80), throwsA(isA<AppException>()));
      await tasks.toggleSubtask(t.id, t.subtasks[1], true);
      expect(tasks.itemById(t.id)!.task.progress, 50);
    });
  });

  group('filtering, sorting, searching', () {
    test('SLA filter, assigned-to-me and search combine', () async {
      await env.signInAs('Chen');
      final tasks = env.providers.tasks..setSlaFilter(SlaState.atRisk);
      expect(tasks.visibleTasks.every((i) => i.sla.state == SlaState.atRisk), isTrue);

      tasks.toggleAssignedToMe();
      expect(
        tasks.visibleTasks.every((i) => i.task.assigneeId == env.member('Chen').id),
        isTrue,
      );

      tasks.clearFilters();
      tasks.setQuery('ACCESSIBILITY');
      expect(tasks.visibleTasks.map((i) => i.task.title), ['Accessibility audit']);
      tasks.setQuery('qa'); // matches category
      expect(tasks.visibleTasks.length, 2);
    });

    test('default sort puts open work first by due date', () {
      final tasks = env.providers.tasks;
      final list = tasks.visibleTasks;
      final firstDone = list.indexWhere((i) => i.task.isDone);
      expect(list.skip(firstDone).every((i) => i.task.isDone), isTrue);
      final open = list.take(firstDone).toList();
      for (var i = 1; i < open.length; i++) {
        expect(open[i - 1].task.dueDate.isAfter(open[i].task.dueDate), isFalse);
      }
    });

    test('priority sort is critical first', () {
      final tasks = env.providers.tasks..setSort(TaskSort.priority);
      expect(tasks.visibleTasks.first.task.priority, Priority.critical);
    });
  });

  group('session', () {
    test('wrong PIN five times locks sign-in for 30 s', () async {
      final session = env.providers.session;
      final brenda = env.member('Brenda');
      for (var i = 0; i < 4; i++) {
        expect(await session.signIn(brenda, '0000'), SignInResult.wrongPin);
      }
      expect(await session.signIn(brenda, '0000'), SignInResult.locked);
      expect(session.isLocked, isTrue);
      // Even the right PIN is refused while locked.
      expect(await session.signIn(brenda, '1234'), SignInResult.locked);
      expect(session.isSignedIn, isFalse);
    });

    test('correct PIN signs in and persists the session id', () async {
      final session = env.providers.session;
      expect(await session.signIn(env.member('Dina'), '1234'), SignInResult.success);
      expect(env.prefs.getString(SessionProvider.sessionKey), env.member('Dina').id);
      await session.signOut();
      expect(env.prefs.getString(SessionProvider.sessionKey), isNull);
    });

    test('a stale saved session id falls back to signed-out', () async {
      await env.prefs.setString(SessionProvider.sessionKey, 'ghost-id');
      await env.providers.session.restore();
      expect(env.providers.session.isRestored, isTrue);
      expect(env.providers.session.isSignedIn, isFalse);
      expect(env.prefs.getString(SessionProvider.sessionKey), isNull);
    });
  });

  test('removing a member unassigns their tasks', () async {
    await env.signInAs('Ali');
    final chen = env.member('Chen');
    await env.providers.members.remove(chen);
    expect(env.providers.members.byId(chen.id), isNull);
    expect(env.providers.tasks.items.any((i) => i.task.assigneeId == chen.id), isFalse);
  });
}

extension on TaskDraft {
  TaskDraft copyWithDue(DateTime due) => TaskDraft(
        title: title,
        description: description,
        category: category,
        assigneeId: assigneeId,
        priority: priority,
        status: status,
        startDate: startDate,
        dueDate: due,
        progress: progress,
      );
}
