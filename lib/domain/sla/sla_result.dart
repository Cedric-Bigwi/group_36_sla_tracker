import '../../data/models/enums.dart';

class SlaResult {
  const SlaResult({
    required this.state,
    required this.reason,
    required this.timeRemaining,
    required this.timeElapsedRatio,
    this.completedLate = false,
  });

  final SlaState state;

  /// Plain-English explanation shown in the UI.
  final String reason;

  /// Due date minus "now" (or minus the completion time for completed tasks).
  /// Negative when overdue / completed late.
  final Duration timeRemaining;

  /// Share of the start→due window already used. 0 before the start, can be
  /// above 1 once overdue.
  final double timeElapsedRatio;

  /// Only meaningful when [state] is [SlaState.completed].
  final bool completedLate;

  @override
  String toString() => 'SlaResult($state, "$reason")';
}
