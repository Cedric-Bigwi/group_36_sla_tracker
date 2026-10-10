import 'package:flutter_test/flutter_test.dart';
import 'package:on_track/data/models/enums.dart';
import 'package:on_track/data/models/subtask.dart';
import 'package:on_track/data/models/task.dart';
import 'package:on_track/domain/sla/sla_engine.dart';

/// Frozen "now" for every test.
final DateTime now = DateTime.utc(2026, 3, 10, 12);

Task makeTask({
  required DateTime start,
  required DateTime due,
  Priority priority = Priority.medium,
  TaskStatus status = TaskStatus.inProgress,
  int progress = 50,
  String? assignee = 'u1',
  DateTime? completedAt,
}) =>
    Task(
      id: 't1',
      projectId: 'p1',
      title: 'Test task',
      category: 'Mobile',
      assigneeId: assignee,
      createdBy: 'u0',
      priority: priority,
      status: status,
      progress: progress,
      startDate: start,
      dueDate: due,
      completedAt: completedAt,
      createdAt: start,
      updatedAt: start,
    );

void main() {
  group('Rule 1: completed', () {
    test('done before the deadline', () {
      final t = makeTask(
        start: now.subtract(const Duration(days: 5)),
        due: now.add(const Duration(days: 2)),
        status: TaskStatus.done,
        completedAt: now.subtract(const Duration(days: 1)),
      );
      final r = evaluate(t, now);
      expect(r.state, SlaState.completed);
      expect(r.completedLate, isFalse);
      expect(r.reason, contains('before the deadline'));
      expect(r.timeRemaining.isNegative, isFalse);
    });

    test('done after the deadline is flagged late', () {
      final t = makeTask(
        start: now.subtract(const Duration(days: 10)),
        due: now.subtract(const Duration(days: 4)),
        status: TaskStatus.done,
        completedAt: now.subtract(const Duration(days: 3)),
      );
      final r = evaluate(t, now);
      expect(r.state, SlaState.completed);
      expect(r.completedLate, isTrue);
      expect(r.reason, 'Completed 1 day after the deadline.');
    });

    test('completed wins even if the due date passed long ago', () {
      final t = makeTask(
        start: now.subtract(const Duration(days: 30)),
        due: now.subtract(const Duration(days: 20)),
        status: TaskStatus.done,
        completedAt: now.subtract(const Duration(days: 21)),
      );
      expect(evaluate(t, now).state, SlaState.completed);
    });

    test('reopened task (completedAt cleared) is evaluated normally', () {
      final t = makeTask(
        start: now.subtract(const Duration(days: 1)),
        due: now.add(const Duration(days: 20)),
        status: TaskStatus.inProgress,
      );
      expect(evaluate(t, now).state, SlaState.onTrack);
    });
  });

  group('Rule 2: overdue', () {
    test('overdue by 1 minute', () {
      final t = makeTask(
        start: now.subtract(const Duration(days: 2)),
        due: now.subtract(const Duration(minutes: 1)),
      );
      final r = evaluate(t, now);
      expect(r.state, SlaState.overdue);
      expect(r.reason, 'Overdue by 1 min.');
      expect(r.timeRemaining, const Duration(minutes: -1));
    });

    test('exactly at the due instant is not yet overdue', () {
      final t = makeTask(
        start: now.subtract(const Duration(days: 2)),
        due: now,
      );
      expect(evaluate(t, now).state, SlaState.atRisk);
    });

    test('overdue by 2 days reads naturally', () {
      final t = makeTask(
        start: now.subtract(const Duration(days: 9)),
        due: now.subtract(const Duration(days: 2)),
      );
      expect(evaluate(t, now).reason, 'Overdue by 2 days.');
    });
  });

  group('Rule 3a: deadline proximity scaled by priority', () {
    // A long window with lots of progress so only rule (a) can fire.
    Task withRemaining(Priority p, Duration remaining) => makeTask(
          start: now.subtract(const Duration(hours: 10)),
          due: now.add(remaining),
          priority: p,
          progress: 90,
        );

    final thresholds = {
      Priority.critical: 72,
      Priority.high: 48,
      Priority.medium: 24,
      Priority.low: 12,
    };

    for (final entry in thresholds.entries) {
      test('${entry.key.label}: exactly ${entry.value} h is still on track', () {
        final r = evaluate(
          withRemaining(entry.key, Duration(hours: entry.value)),
          now,
        );
        expect(r.state, SlaState.onTrack);
      });

      test('${entry.key.label}: 1 minute inside ${entry.value} h is at risk', () {
        final r = evaluate(
          withRemaining(
            entry.key,
            Duration(hours: entry.value) - const Duration(minutes: 1),
          ),
          now,
        );
        expect(r.state, SlaState.atRisk);
        expect(r.reason, contains('flagged within ${entry.value} h'));
      });
    }

    test('reason names the remaining time and the priority', () {
      final r = evaluate(withRemaining(Priority.high, const Duration(hours: 18)), now);
      expect(
        r.reason,
        'Due in 18 h — High priority tasks are flagged within 48 h of the deadline.',
      );
    });
  });

  group('Rule 3b: progress lag', () {
    // 10-day window, 6 days used → elapsed 0.6; lag line is 0.35.
    Task lag(int progress) => makeTask(
          start: now.subtract(const Duration(days: 6)),
          due: now.add(const Duration(days: 4)),
          progress: progress,
        );

    test('just below the line is at risk', () {
      final r = evaluate(lag(34), now);
      expect(r.state, SlaState.atRisk);
      expect(r.reason, '60% of the time has passed but progress is only 34%.');
    });

    test('just above the line is on track', () {
      expect(evaluate(lag(36), now).state, SlaState.onTrack);
    });

    test('is not checked before half the window has passed', () {
      final t = makeTask(
        start: now.subtract(const Duration(days: 4)),
        due: now.add(const Duration(days: 6)), // elapsed 0.4
        progress: 0,
      );
      expect(evaluate(t, now).state, SlaState.onTrack);
    });

    test('uses subtasks for progress when present', () {
      Subtask s(int i, bool done) => Subtask(
            id: 's$i',
            taskId: 't1',
            title: 'sub $i',
            isDone: done,
            position: i,
          );
      final subs = [s(0, true), s(1, true), s(2, true), s(3, false)]; // 75%
      // Stored progress says 0, subtasks say 75 → not behind.
      expect(evaluate(lag(0), now, subtasks: subs).state, SlaState.onTrack);
      expect(evaluate(lag(0), now).state, SlaState.atRisk);
    });
  });

  group('Rule 3c: not started late', () {
    test('todo with 60% of the window gone is at risk', () {
      // progress 40 keeps rule (b) quiet, so (c) fires on its own.
      final t = makeTask(
        start: now.subtract(const Duration(days: 6)),
        due: now.add(const Duration(days: 4)),
        status: TaskStatus.todo,
        progress: 40,
      );
      final r = evaluate(t, now);
      expect(r.state, SlaState.atRisk);
      expect(r.reason, startsWith('Still in To Do'));
    });

    test('same task already in progress is fine', () {
      final t = makeTask(
        start: now.subtract(const Duration(days: 6)),
        due: now.add(const Duration(days: 4)),
        status: TaskStatus.inProgress,
        progress: 40,
      );
      expect(evaluate(t, now).state, SlaState.onTrack);
    });

    test('todo before the 60% mark is fine', () {
      final t = makeTask(
        start: now.subtract(const Duration(days: 5)),
        due: now.add(const Duration(days: 5)), // 0.5
        status: TaskStatus.todo,
        progress: 40,
      );
      expect(evaluate(t, now).state, SlaState.onTrack);
    });
  });

  group('Rule 3d: unassigned near deadline', () {
    test('unassigned at 45% elapsed is at risk', () {
      final t = makeTask(
        start: now.subtract(const Duration(hours: 108)),
        due: now.add(const Duration(hours: 132)), // 240 h window → 0.45
        progress: 45,
        assignee: null,
      );
      final r = evaluate(t, now);
      expect(r.state, SlaState.atRisk);
      expect(r.reason, startsWith('No one is assigned'));
    });

    test('unassigned but early is on track', () {
      final t = makeTask(
        start: now.subtract(const Duration(hours: 72)),
        due: now.add(const Duration(hours: 168)), // 0.3
        progress: 30,
        assignee: null,
      );
      expect(evaluate(t, now).state, SlaState.onTrack);
    });

    test('assigned task at the same point is on track', () {
      final t = makeTask(
        start: now.subtract(const Duration(hours: 108)),
        due: now.add(const Duration(hours: 132)),
        progress: 45,
      );
      expect(evaluate(t, now).state, SlaState.onTrack);
    });
  });

  group('Edge cases', () {
    test('zero-length window counts as fully elapsed', () {
      final due = now.add(const Duration(days: 30));
      final t = makeTask(start: due, due: due, progress: 0);
      final r = evaluate(t, now);
      expect(r.timeElapsedRatio, 1.0);
      expect(r.state, SlaState.atRisk); // rule (b): 100% elapsed, 0% done
    });

    test('before the start date elapsed ratio is 0', () {
      final t = makeTask(
        start: now.add(const Duration(days: 1)),
        due: now.add(const Duration(days: 11)),
        progress: 0,
      );
      final r = evaluate(t, now);
      expect(r.timeElapsedRatio, 0);
      expect(r.state, SlaState.onTrack);
    });

    test('clearly on-track task', () {
      final t = makeTask(
        start: now.subtract(const Duration(days: 1)),
        due: now.add(const Duration(days: 10)),
        progress: 20,
      );
      final r = evaluate(t, now);
      expect(r.state, SlaState.onTrack);
      expect(r.timeRemaining, const Duration(days: 10));
    });

    test('overdue ratio can exceed 1', () {
      final t = makeTask(
        start: now.subtract(const Duration(days: 4)),
        due: now.subtract(const Duration(days: 2)),
      );
      expect(evaluate(t, now).timeElapsedRatio, 2.0);
    });
  });
}
