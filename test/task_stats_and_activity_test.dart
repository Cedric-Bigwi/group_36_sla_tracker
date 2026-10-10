import 'package:flutter_test/flutter_test.dart';
import 'package:on_track/data/models/enums.dart';
import 'package:on_track/data/models/task.dart';
import 'package:on_track/domain/sla/sla_engine.dart';
import 'package:on_track/domain/stats/task_stats.dart';
import 'package:on_track/domain/task_item.dart';
import 'package:on_track/state/task_activity.dart';

final now = DateTime.utc(2026, 3, 10, 12);

Task task(
  String id, {
  required Duration start,
  required Duration due,
  TaskStatus status = TaskStatus.inProgress,
  Duration? doneAt,
  int progress = 50,
  String? assignee = 'a',
  Priority priority = Priority.medium,
}) =>
    Task(
      id: id,
      projectId: 'p',
      title: 'Task $id',
      category: 'QA',
      assigneeId: assignee,
      createdBy: 'm',
      priority: priority,
      status: status,
      progress: progress,
      startDate: now.add(start),
      dueDate: now.add(due),
      completedAt: doneAt == null ? null : now.add(doneAt),
      createdAt: now,
      updatedAt: now,
    );

TaskItem item(Task t) => TaskItem(task: t, subtasks: const [], sla: evaluate(t, now));

void main() {
  group('TaskStats', () {
    final items = [
      item(task('early', start: const Duration(days: -10), due: const Duration(days: -5),
          status: TaskStatus.done, doneAt: const Duration(days: -7))), // 2 days early
      item(task('late', start: const Duration(days: -10), due: const Duration(days: -5),
          status: TaskStatus.done, doneAt: const Duration(days: -4))), // 1 day late
      item(task('over', start: const Duration(days: -10), due: const Duration(days: -1))),
      item(task('ok', start: const Duration(days: -1), due: const Duration(days: 20), progress: 10)),
    ];

    test('counts, completion rate and compliance', () {
      final s = TaskStats.of(items);
      expect(s.total, 4);
      expect(s.counts[SlaState.completed], 2);
      expect(s.counts[SlaState.overdue], 1);
      expect(s.counts[SlaState.onTrack], 1);
      expect(s.completionRate, 0.5);
      expect(s.completedOnTime, 1);
      expect(s.completedLate, 1);
      expect(s.onTimeRate, 0.5);
      // (+2 days and -1 day) / 2
      expect(s.averageDaysEarly, closeTo(0.5, 1e-9));
    });

    test('empty list has no rates instead of dividing by zero', () {
      final s = TaskStats.of(const []);
      expect(s.completionRate, 0);
      expect(s.onTimeRate, isNull);
      expect(s.averageDaysEarly, isNull);
    });

    test('needs-attention: overdue first, then least time remaining, max 5', () {
      final risky = [
        item(task('r1', start: const Duration(days: -5), due: const Duration(hours: 20))),
        item(task('r2', start: const Duration(days: -5), due: const Duration(hours: 5))),
        item(task('o1', start: const Duration(days: -9), due: const Duration(days: -1))),
        item(task('o2', start: const Duration(days: -9), due: const Duration(days: -3))),
        item(task('fine', start: const Duration(days: -1), due: const Duration(days: 30), progress: 10)),
        item(task('r3', start: const Duration(days: -5), due: const Duration(hours: 10))),
        item(task('r4', start: const Duration(days: -5), due: const Duration(hours: 12))),
      ];
      final list = needsAttention(risky);
      expect(list.length, 5);
      expect(list.map((i) => i.id).toList(), ['o2', 'o1', 'r2', 'r3', 'r4']);
    });

    test('upcoming deadlines: open, within 7 days, soonest first', () {
      final list = upcomingDeadlines([
        item(task('a', start: const Duration(days: -1), due: const Duration(days: 6))),
        item(task('b', start: const Duration(days: -1), due: const Duration(days: 2))),
        item(task('c', start: const Duration(days: -1), due: const Duration(days: 9))),
        item(task('d', start: const Duration(days: -9), due: const Duration(days: -1))),
        item(task('e', start: const Duration(days: -3), due: const Duration(days: 1),
            status: TaskStatus.done, doneAt: const Duration(hours: -1))),
      ], now);
      expect(list.map((i) => i.id), ['b', 'a']);
    });

    test('per-member stats', () {
      final s = memberStats(items, 'a');
      expect(s.completed, 2);
      expect(s.open, 2);
      expect(s.overdue, 1);
      expect(s.onTimeRate, 0.5);
    });
  });

  group('diffActivity', () {
    final before = task('x', start: const Duration(days: -1), due: const Duration(days: 3));
    String name(String? id) => id == null ? 'Unassigned' : 'User $id';

    List<String> details(Task after) => diffActivity(
          before: before,
          after: after,
          actorId: 'u',
          now: now,
          nameOf: name,
        ).map((e) => '${e.type.dbValue}: ${e.detail}').toList();

    test('nothing changed → no entries', () {
      expect(details(before), isEmpty);
    });

    test('logs status, assignee, due date and progress separately', () {
      final after = before.copyWith(
        status: TaskStatus.inReview,
        assigneeId: 'b',
        dueDate: before.dueDate.add(const Duration(days: 4)),
        progress: 80,
      );
      final d = details(after);
      expect(d, contains('status_changed: In Progress → In Review'));
      expect(d, contains('reassigned: User a → User b'));
      expect(d, contains('progress_changed: 50% → 80%'));
      expect(d.where((e) => e.startsWith('due_changed: Due date ')).single, contains('→'));
    });

    test('unassigning is described in words', () {
      final d = details(before.copyWith(clearAssignee: true));
      expect(d, ['reassigned: User a → Unassigned']);
    });

    test('field edits are grouped in one entry', () {
      final d = details(before.copyWith(title: 'New', priority: Priority.critical, category: 'Docs'));
      expect(d.length, 1);
      expect(d.single, allOf(startsWith('edited:'), contains('Title'), contains('Priority'), contains('Category')));
    });
  });
}
