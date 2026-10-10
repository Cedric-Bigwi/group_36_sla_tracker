class Subtask {
  const Subtask({
    required this.id,
    required this.taskId,
    required this.title,
    this.isDone = false,
    required this.position,
  });

  final String id;
  final String taskId;
  final String title;
  final bool isDone;
  final int position;

  Map<String, Object?> toMap() => {
    'id': id,
    'task_id': taskId,
    'title': title,
    'is_done': isDone ? 1 : 0,
    'position': position,
  };

  factory Subtask.fromMap(Map<String, Object?> map) => Subtask(
    id: map['id']! as String,
    taskId: map['task_id']! as String,
    title: map['title']! as String,
    isDone: (map['is_done']! as int) == 1,
    position: map['position']! as int,
  );

  Subtask copyWith({String? title, bool? isDone, int? position}) => Subtask(
    id: id,
    taskId: taskId,
    title: title ?? this.title,
    isDone: isDone ?? this.isDone,
    position: position ?? this.position,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Subtask &&
          id == other.id &&
          taskId == other.taskId &&
          title == other.title &&
          isDone == other.isDone &&
          position == other.position;

  @override
  int get hashCode => Object.hash(id, taskId, title, isDone, position);
}
