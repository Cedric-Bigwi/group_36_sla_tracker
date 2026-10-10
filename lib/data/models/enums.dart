/// Domain enums. All of these are pure Dart (no Flutter imports) so the SLA
/// engine and tests can use them freely.
library;

/// Workflow state that a USER sets. It is stored in the database.
///
/// Do not confuse it with [SlaState], which is derived from status + dates +
/// progress and is therefore NEVER stored (it would go stale as time passes).
enum TaskStatus {
  todo('To Do'),
  inProgress('In Progress'),
  inReview('In Review'),
  done('Done');

  const TaskStatus(this.label);
  final String label;

  static TaskStatus parse(String? value) => TaskStatus.values.firstWhere(
    (e) => e.name == value,
    orElse: () => TaskStatus.todo,
  );
}

enum Priority {
  low('Low'),
  medium('Medium'),
  high('High'),
  critical('Critical');

  const Priority(this.label);
  final String label;

  static Priority parse(String? value) => Priority.values.firstWhere(
    (e) => e.name == value,
    orElse: () => Priority.medium,
  );
}

/// COMPUTED by the SLA engine on every read. Never persisted.
enum SlaState {
  onTrack('On Track'),
  atRisk('At Risk'),
  overdue('Overdue'),
  completed('Completed');

  const SlaState(this.label);
  final String label;
}

enum MemberRole {
  manager('Manager'),
  member('Member');

  const MemberRole(this.label);
  final String label;

  static MemberRole parse(String? value) => MemberRole.values.firstWhere(
    (e) => e.name == value,
    orElse: () => MemberRole.member,
  );
}

/// Kinds of entries in the activity log. [dbValue] is the snake_case string
/// stored in the `activity.type` column.
enum ActivityType {
  created('created', 'created'),
  statusChanged('status_changed', 'changed status of'),
  reassigned('reassigned', 'reassigned'),
  dueChanged('due_changed', 'changed the due date of'),
  progressChanged('progress_changed', 'updated progress of'),
  edited('edited', 'edited'),
  deleted('deleted', 'deleted'),
  noteAdded('note_added', 'updated notes on');

  const ActivityType(this.dbValue, this.verb);
  final String dbValue;

  /// Used to build a sentence: "actor verb task".
  final String verb;

  static ActivityType parse(String? value) => ActivityType.values.firstWhere(
    (e) => e.dbValue == value,
    orElse: () => ActivityType.edited,
  );
}

/// Fixed list of task categories offered in the form and filters.
const List<String> kTaskCategories = [
  'UI/UX',
  'Mobile',
  'Backend',
  'QA',
  'Docs',
  'DevOps',
  'Other',
];
