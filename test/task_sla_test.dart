import 'package:flutter_test/flutter_test.dart';
import 'package:group_36_sla_tracker/models/task.dart';

Task make(DateTime deadline,
        {TaskStatus status = TaskStatus.todo,
        Priority priority = Priority.medium}) =>
    Task(id: '1', title: 'T', team: 'Team Alpha',
        deadline: deadline, status: status, priority: priority);

void main() {
  // A fixed "now" so the results never depend on when the tests run.
  final now = DateTime(2026, 10, 12, 12);

  test('done task is Completed even when past deadline', () {
    final t = make(now.subtract(const Duration(days: 1)),
        status: TaskStatus.done);
    expect(t.slaAt(now), Sla.completed);
  });

  test('past deadline is Overdue', () {
    expect(make(now.subtract(const Duration(hours: 1))).slaAt(now),
        Sla.overdue);
  });

  test('24h left is At Risk', () {
    expect(make(now.add(const Duration(hours: 24))).slaAt(now), Sla.atRisk);
  });

  test('5 days left is On Track', () {
    expect(make(now.add(const Duration(days: 5))).slaAt(now), Sla.onTrack);
  });

  test('60h left: medium is On Track, high is At Risk', () {
    final d = now.add(const Duration(hours: 60));
    expect(make(d).slaAt(now), Sla.onTrack);
    expect(make(d, priority: Priority.high).slaAt(now), Sla.atRisk);
  });

  test('boundary: exactly 48h is At Risk, 48h30m is On Track', () {
    expect(make(now.add(const Duration(hours: 48))).slaAt(now), Sla.atRisk);
    expect(make(now.add(const Duration(hours: 48, minutes: 30))).slaAt(now),
        Sla.onTrack);
  });

  test('boundary for high priority is 72h', () {
    const p = Priority.high;
    expect(make(now.add(const Duration(hours: 72)), priority: p).slaAt(now),
        Sla.atRisk);
    expect(
        make(now.add(const Duration(hours: 72, minutes: 30)), priority: p)
            .slaAt(now),
        Sla.onTrack);
  });

  test('fromJson falls back for missing or invalid optional fields', () {
    final t = Task.fromJson({
      'id': '9',
      'deadline': now.toIso8601String(),
      'status': 99,
    });
    expect(t.title, 'Untitled');
    expect(t.description, '');
    expect(t.status, TaskStatus.todo);
    expect(t.priority, Priority.medium);
  });

  test('JSON round trip keeps the task', () {
    final t = make(now.add(const Duration(days: 5)), priority: Priority.high);
    final back = Task.fromJson(t.toJson());
    expect(back.title, t.title);
    expect(back.deadline, t.deadline);
    expect(back.priority, Priority.high);
  });
}