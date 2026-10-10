import '../data/models/enums.dart';
import '../data/models/task.dart';

/// Values collected by the create/edit form. Keeps the form independent from
/// persistence details (ids, timestamps, created_by).
class TaskDraft {
  const TaskDraft({
    required this.title,
    this.description,
    required this.category,
    this.assigneeId,
    required this.priority,
    required this.status,
    required this.startDate,
    required this.dueDate,
    required this.progress,
  });

  factory TaskDraft.fromTask(Task t) => TaskDraft(
    title: t.title,
    description: t.description,
    category: t.category,
    assigneeId: t.assigneeId,
    priority: t.priority,
    status: t.status,
    startDate: t.startDate,
    dueDate: t.dueDate,
    progress: t.progress,
  );

  final String title;
  final String? description;
  final String category;
  final String? assigneeId;
  final Priority priority;
  final TaskStatus status;
  final DateTime startDate;
  final DateTime dueDate;
  final int progress;
}
