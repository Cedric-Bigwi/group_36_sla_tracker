import 'enums.dart';

class ActivityEntry {
  const ActivityEntry({
    required this.id,
    this.taskId,
    required this.actorId,
    required this.type,
    this.detail,
    required this.createdAt,
  });

  final String id;

  /// Null for entries that outlive their task (e.g. "deleted").
  /// Entries with a task id are removed by ON DELETE CASCADE with the task.
  final String? taskId;
  final String actorId;
  final ActivityType type;

  /// Human readable, e.g. "To Do → In Progress".
  final String? detail;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'task_id': taskId,
    'actor_id': actorId,
    'type': type.dbValue,
    'detail': detail,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory ActivityEntry.fromMap(Map<String, Object?> map) => ActivityEntry(
    id: map['id']! as String,
    taskId: map['task_id'] as String?,
    actorId: map['actor_id']! as String,
    type: ActivityType.parse(map['type'] as String?),
    detail: map['detail'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      map['created_at']! as int,
      isUtc: true,
    ),
  );

  ActivityEntry copyWith({String? detail, DateTime? createdAt}) =>
      ActivityEntry(
        id: id,
        taskId: taskId,
        actorId: actorId,
        type: type,
        detail: detail ?? this.detail,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityEntry &&
          id == other.id &&
          taskId == other.taskId &&
          actorId == other.actorId &&
          type == other.type &&
          detail == other.detail &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, taskId, actorId, type, detail, createdAt);
}

/// An [ActivityEntry] joined with display names, so the UI does not need
/// extra lookups. Produced by the repository with a SQL JOIN.
class ActivityView {
  const ActivityView({
    required this.entry,
    required this.actorName,
    required this.actorColor,
    this.taskTitle,
  });

  final ActivityEntry entry;
  final String actorName;
  final int actorColor;
  final String? taskTitle;
}
