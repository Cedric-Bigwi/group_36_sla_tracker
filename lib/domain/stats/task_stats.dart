import '../../data/models/enums.dart';
import '../task_item.dart';

/// Aggregates over a list of [TaskItem]s. Pure Dart so it is unit-testable and
/// shared by the Dashboard, Statistics and Team screens.
class TaskStats {
  TaskStats._({
    required this.total,
    required this.counts,
    required this.completedOnTime,
    required this.completedLate,
    required this.averageDaysEarly,
  });

  factory TaskStats.of(Iterable<TaskItem> items) {
    final counts = {for (final s in SlaState.values) s: 0};
    var onTime = 0;
    var late = 0;
    var daysSum = 0.0;
    var total = 0;
    for (final i in items) {
      total++;
      counts[i.sla.state] = counts[i.sla.state]! + 1;
      if (i.sla.state == SlaState.completed) {
        if (i.sla.completedLate) {
          late++;
        } else {
          onTime++;
        }
        // timeRemaining is positive when finished early, negative when late.
        daysSum += i.sla.timeRemaining.inMinutes / (60 * 24);
      }
    }
    final completed = onTime + late;
    return TaskStats._(
      total: total,
      counts: counts,
      completedOnTime: onTime,
      completedLate: late,
      averageDaysEarly: completed == 0 ? null : daysSum / completed,
    );
  }

  final int total;
  final Map<SlaState, int> counts;
  final int completedOnTime;
  final int completedLate;

  /// Average of (due − completed) in days; positive = early, negative = late.
  final double? averageDaysEarly;

  int get completed => counts[SlaState.completed]!;
  int get open => total - completed;

  /// Completed / total (0..1).
  double get completionRate => total == 0 ? 0 : completed / total;

  /// "SLA compliance": completed on time / completed. Null when nothing is
  /// completed yet.
  double? get onTimeRate => completed == 0 ? null : completedOnTime / completed;
}

/// Overdue first (longest overdue first), then least time remaining.
int compareUrgency(TaskItem a, TaskItem b) {
  final ao = a.sla.state == SlaState.overdue;
  final bo = b.sla.state == SlaState.overdue;
  if (ao != bo) return ao ? -1 : 1;
  return a.sla.timeRemaining.compareTo(b.sla.timeRemaining);
}

/// Up to [limit] overdue/at-risk tasks, most urgent first.
List<TaskItem> needsAttention(Iterable<TaskItem> items, {int limit = 5}) {
  final list =
      items
          .where(
            (i) =>
                i.sla.state == SlaState.overdue ||
                i.sla.state == SlaState.atRisk,
          )
          .toList()
        ..sort(compareUrgency);
  return list.take(limit).toList();
}

/// Open tasks due within [days] days of [now] (not overdue), soonest first.
List<TaskItem> upcomingDeadlines(
  Iterable<TaskItem> items,
  DateTime now, {
  int days = 7,
}) {
  final end = now.add(Duration(days: days));
  return items
      .where(
        (i) =>
            i.task.status != TaskStatus.done &&
            !i.task.dueDate.isBefore(now) &&
            !i.task.dueDate.isAfter(end),
      )
      .toList()
    ..sort((a, b) => a.task.dueDate.compareTo(b.task.dueDate));
}

/// Workload numbers for one member.
class MemberStats {
  const MemberStats({
    required this.open,
    required this.overdue,
    required this.atRisk,
    required this.completed,
    required this.completedOnTime,
  });

  final int open;
  final int overdue;
  final int atRisk;
  final int completed;
  final int completedOnTime;

  double? get onTimeRate => completed == 0 ? null : completedOnTime / completed;
}

MemberStats memberStats(Iterable<TaskItem> items, String memberId) {
  var open = 0, overdue = 0, atRisk = 0, completed = 0, onTime = 0;
  for (final i in items) {
    if (i.task.assigneeId != memberId) continue;
    switch (i.sla.state) {
      case SlaState.completed:
        completed++;
        if (!i.sla.completedLate) onTime++;
      case SlaState.overdue:
        open++;
        overdue++;
      case SlaState.atRisk:
        open++;
        atRisk++;
      case SlaState.onTrack:
        open++;
    }
  }
  return MemberStats(
    open: open,
    overdue: overdue,
    atRisk: atRisk,
    completed: completed,
    completedOnTime: onTime,
  );
}
