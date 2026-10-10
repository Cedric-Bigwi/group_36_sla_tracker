import '../data/models/subtask.dart';
import '../data/models/task.dart';
import 'sla/sla_result.dart';

class TaskItem {
  const TaskItem({
    required this.task,
    required this.subtasks,
    required this.sla,
  });

  final Task task;
  final List<Subtask> subtasks;
  final SlaResult sla;

  String get id => task.id;

  bool get hasSubtasks => subtasks.isNotEmpty;
}
