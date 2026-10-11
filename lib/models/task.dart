import 'package:flutter/material.dart';

enum Priority { low, medium, high }
enum TaskStatus { todo, inProgress, done }
enum Sla { onTrack, atRisk, overdue, completed }

extension SlaStyle on Sla {
  String get label => ['On Track', 'At Risk', 'Overdue', 'Completed'][index];
  Color get color => const [
        Color(0xFF16A34A), Color(0xFFF59E0B), Color(0xFFDC2626), Color(0xFF6366F1)
      ][index];
  IconData get icon => const [
        Icons.check_circle_outline, Icons.warning_amber_rounded,
        Icons.error_outline, Icons.verified
      ][index];
}

extension TaskStatusLabel on TaskStatus {
  String get label => ['To do', 'In progress', 'Done'][index];
}

String fmt(DateTime d) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(d.day)}/${p(d.month)}/${d.year}  ${p(d.hour)}:${p(d.minute)}';
}

class Task {
  String id, title, description, team;
  String? assignee; // username; null = open pool (anyone on the team can claim)
  Priority priority;
  TaskStatus status;
  DateTime deadline;

  Task({
    required this.id, required this.title, this.description = '',
    required this.team, this.assignee, this.priority = Priority.medium,
    this.status = TaskStatus.todo, required this.deadline,
  });

  /// Hours before the deadline when a task becomes At Risk.
  static const int atRiskHours = 48;
  static const int atRiskHoursHigh = 72; // High priority gets an earlier warning

  /// SLA RULES:
  /// 1. Done -> Completed
  /// 2. Deadline passed -> Overdue
  /// 3. 48h or less left (72h if High priority) -> At Risk
  /// 4. Otherwise -> On Track
  Sla get sla => slaAt(DateTime.now());

  /// Same rules as [sla], checked against [now] so they can be unit-tested.
  Sla slaAt(DateTime now) {
    if (status == TaskStatus.done) return Sla.completed;
    final left = deadline.difference(now);
    if (left.isNegative) return Sla.overdue;
    final limit = priority == Priority.high ? atRiskHoursHigh : atRiskHours;
    return left <= Duration(hours: limit) ? Sla.atRisk : Sla.onTrack;
  }

  Color get priorityColor =>
      [Colors.blueGrey, Colors.orange, Colors.red][priority.index];

  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'description': description,
        'assignee': assignee, 'team': team, 'priority': priority.index,
        'status': status.index, 'deadline': deadline.toIso8601String(),
      };

  /// Reads a saved task. Missing or invalid optional fields fall back to
  /// defaults; id and deadline are required, so a task without them throws.
  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'], title: j['title'] ?? 'Untitled', description: j['description'] ?? '',
        assignee: j['assignee'], team: j['team'] ?? '',
        priority: _pick(Priority.values, j['priority'], Priority.medium),
        status: _pick(TaskStatus.values, j['status'], TaskStatus.todo),
        deadline: DateTime.parse(j['deadline']),
      );

  /// values[i] when i is a valid index, otherwise [fallback].
  static T _pick<T>(List<T> values, dynamic i, T fallback) =>
      i is int && i >= 0 && i < values.length ? values[i] : fallback;
}