import 'enums.dart';

DateTime _fromMillis(int ms) =>
    DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

class Task {
  const Task({
    required this.id,
    required this.projectId,
    required this.title,
    this.description,
    required this.category,
    this.assigneeId,
    required this.createdBy,
    required this.priority,
    required this.status,
    required this.progress,
    required this.startDate,
    required this.dueDate,
    this.completedAt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String projectId;
  final String title;
  final String? description;
  final String category;
  final String? assigneeId;
  final String createdBy;
  final Priority priority;
  final TaskStatus status;

  /// 0..100. When the task has subtasks this is derived from them.
  final int progress;

  /// When work is expected to begin. Together with [dueDate] it defines the
  /// SLA window used by the engine.
  final DateTime startDate;
  final DateTime dueDate;

  /// Set when status becomes done; cleared when the task is reopened.
  final DateTime? completedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDone => status == TaskStatus.done;

  Map<String, Object?> toMap() => {
    'id': id,
    'project_id': projectId,
    'title': title,
    'description': description,
    'category': category,
    'assignee_id': assigneeId,
    'created_by': createdBy,
    'priority': priority.name,
    'status': status.name,
    'progress': progress,
    'start_date': startDate.millisecondsSinceEpoch,
    'due_date': dueDate.millisecondsSinceEpoch,
    'completed_at': completedAt?.millisecondsSinceEpoch,
    'notes': notes,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  factory Task.fromMap(Map<String, Object?> map) => Task(
    id: map['id']! as String,
    projectId: map['project_id']! as String,
    title: map['title']! as String,
    description: map['description'] as String?,
    category: map['category']! as String,
    assigneeId: map['assignee_id'] as String?,
    createdBy: map['created_by']! as String,
    priority: Priority.parse(map['priority'] as String?),
    status: TaskStatus.parse(map['status'] as String?),
    progress: map['progress']! as int,
    startDate: _fromMillis(map['start_date']! as int),
    dueDate: _fromMillis(map['due_date']! as int),
    completedAt: map['completed_at'] == null
        ? null
        : _fromMillis(map['completed_at']! as int),
    notes: map['notes'] as String?,
    createdAt: _fromMillis(map['created_at']! as int),
    updatedAt: _fromMillis(map['updated_at']! as int),
  );

  /// Nullable fields that must be *cleared* (not just left unchanged) use the
  /// explicit `clear...` flags because `null` already means "keep".
  Task copyWith({
    String? projectId,
    String? title,
    String? description,
    String? category,
    String? assigneeId,
    bool clearAssignee = false,
    String? createdBy,
    Priority? priority,
    TaskStatus? status,
    int? progress,
    DateTime? startDate,
    DateTime? dueDate,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? notes,
    DateTime? updatedAt,
  }) => Task(
    id: id,
    projectId: projectId ?? this.projectId,
    title: title ?? this.title,
    description: description ?? this.description,
    category: category ?? this.category,
    assigneeId: clearAssignee ? null : (assigneeId ?? this.assigneeId),
    createdBy: createdBy ?? this.createdBy,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    startDate: startDate ?? this.startDate,
    dueDate: dueDate ?? this.dueDate,
    completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    notes: notes ?? this.notes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task &&
          id == other.id &&
          projectId == other.projectId &&
          title == other.title &&
          description == other.description &&
          category == other.category &&
          assigneeId == other.assigneeId &&
          createdBy == other.createdBy &&
          priority == other.priority &&
          status == other.status &&
          progress == other.progress &&
          startDate == other.startDate &&
          dueDate == other.dueDate &&
          completedAt == other.completedAt &&
          notes == other.notes &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    title,
    description,
    category,
    assigneeId,
    createdBy,
    priority,
    status,
    progress,
    startDate,
    dueDate,
    completedAt,
    notes,
    createdAt,
    updatedAt,
  );
}
