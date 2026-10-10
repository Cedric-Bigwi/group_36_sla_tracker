// PURE DART: no Flutter imports. "now" is always a parameter so tests can
// freeze time.
import '../../core/utils/date_utils.dart' show humanizeDuration;
import '../../data/models/enums.dart';
import '../../data/models/subtask.dart';
import '../../data/models/task.dart';
import 'sla_result.dart';

/// Every tunable number of the SLA rules lives here, so the group can change
/// and explain them in one place. The About screen renders its text from these
/// same constants, so documentation can never drift from the logic.
abstract final class SlaConfig {
  /// Rule 3a: a task is At Risk when less than this much time remains.
  /// More important work gets an earlier warning.
  static const Map<Priority, Duration> riskWindow = {
    Priority.critical: Duration(hours: 72),
    Priority.high: Duration(hours: 48),
    Priority.medium: Duration(hours: 24),
    Priority.low: Duration(hours: 12),
  };

  /// Rule 3b (progress lag): only checked once this share of the window passed…
  static const double lagMinElapsed = 0.5;

  /// …and fires when progress is more than this far behind a steady pace.
  static const double lagTolerance = 0.25;

  /// Rule 3c: a task still in To Do after this share of the window is at risk.
  static const double notStartedElapsed = 0.6;

  /// Rule 3d: an unassigned task after this share of the window is at risk.
  static const double unassignedElapsed = 0.4;
}

/// Evaluates [task] at instant [now].
///
/// Rules, first match wins:
///  1. Completed  – status is done
///  2. Overdue    – not done and now is after the due date
///  3. At Risk    – (a) deadline proximity scaled by priority,
///                  (b) progress lag, (c) not started late,
///                  (d) unassigned near deadline
///  4. On Track   – everything else
SlaResult evaluate(
  Task task,
  DateTime now, {
  List<Subtask> subtasks = const [],
}) {
  final window = task.dueDate.difference(task.startDate);

  // Elapsed share of the SLA window. A zero-length window counts as fully
  // elapsed (T == 0 → 1). Negative windows are blocked by validation; if one
  // slips in we treat it the same way instead of dividing by a negative.
  final double rawElapsed = window.inMicroseconds <= 0
      ? 1.0
      : now.difference(task.startDate).inMicroseconds / window.inMicroseconds;
  final double ratio = rawElapsed < 0 ? 0.0 : rawElapsed;
  final double elapsed = ratio.clamp(0.0, 1.0);

  // Progress as a 0..1 fraction. With subtasks it is derived from them.
  final double progress = subtasks.isEmpty
      ? task.progress.clamp(0, 100) / 100
      : subtasks.where((s) => s.isDone).length / subtasks.length;

  // ── Rule 1: Completed ────────────────────────────────────────────────────
  if (task.status == TaskStatus.done) {
    final doneAt = task.completedAt ?? now;
    final late = doneAt.isAfter(task.dueDate);
    final gap = doneAt.difference(task.dueDate);
    final String reason;
    if (late) {
      reason = 'Completed ${humanizeDuration(gap)} after the deadline.';
    } else if (gap.inMinutes.abs() < 1) {
      reason = 'Completed right on the deadline.';
    } else {
      reason = 'Completed ${humanizeDuration(gap)} before the deadline.';
    }
    return SlaResult(
      state: SlaState.completed,
      reason: reason,
      timeRemaining: task.dueDate.difference(doneAt),
      timeElapsedRatio: ratio,
      completedLate: late,
    );
  }

  final remaining = task.dueDate.difference(now);

  // ── Rule 2: Overdue ──────────────────────────────────────────────────────
  if (now.isAfter(task.dueDate)) {
    return SlaResult(
      state: SlaState.overdue,
      reason: 'Overdue by ${humanizeDuration(remaining)}.',
      timeRemaining: remaining,
      timeElapsedRatio: ratio,
    );
  }

  SlaResult atRisk(String reason) => SlaResult(
    state: SlaState.atRisk,
    reason: reason,
    timeRemaining: remaining,
    timeElapsedRatio: ratio,
  );

  // ── Rule 3: At Risk ──────────────────────────────────────────────────────
  // (a) Deadline proximity, scaled by priority (strictly below the threshold,
  //     so exactly 48 h left on a High task is still On Track).
  final threshold = SlaConfig.riskWindow[task.priority]!;
  if (remaining < threshold) {
    return atRisk(
      'Due in ${humanizeDuration(remaining)} — ${task.priority.label} priority '
      'tasks are flagged within ${threshold.inHours} h of the deadline.',
    );
  }

  // (b) Progress lag: over half the time is gone and work is >25 points
  //     behind a steady pace.
  if (elapsed >= SlaConfig.lagMinElapsed &&
      progress < elapsed - SlaConfig.lagTolerance) {
    return atRisk(
      '${_pct(elapsed)}% of the time has passed but progress is only '
      '${_pct(progress)}%.',
    );
  }

  // (c) Not started, and most of the window is gone.
  if (task.status == TaskStatus.todo &&
      elapsed >= SlaConfig.notStartedElapsed) {
    return atRisk(
      'Still in To Do with ${_pct(elapsed)}% of the time already used.',
    );
  }

  // (d) Nobody owns it and the clock is running.
  if (task.assigneeId == null && elapsed >= SlaConfig.unassignedElapsed) {
    return atRisk(
      'No one is assigned and ${_pct(elapsed)}% of the time has passed.',
    );
  }

  // ── Rule 4: On Track ─────────────────────────────────────────────────────
  return SlaResult(
    state: SlaState.onTrack,
    reason:
        'On schedule — ${_pct(elapsed)}% of the time used, '
        '${_pct(progress)}% complete.',
    timeRemaining: remaining,
    timeElapsedRatio: ratio,
  );
}

int _pct(double v) => (v * 100).round();
