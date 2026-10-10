import 'package:uuid/uuid.dart';

import '../core/utils/date_utils.dart';
import '../data/models/activity_entry.dart';
import '../data/models/enums.dart';
import '../data/models/task.dart';

const _uuid = Uuid();

ActivityEntry makeActivity({
  String? taskId,
  required String actorId,
  required ActivityType type,
  String? detail,
  required DateTime now,
}) => ActivityEntry(
  id: _uuid.v4(),
  taskId: taskId,
  actorId: actorId,
  type: type,
  detail: detail,
  createdAt: now,
);

/// Compares two versions of a task and returns one human-readable activity
/// entry per kind of change (e.g. "Due date 10 Dec, 09:00 → 14 Dec, 09:00").
///
/// [nameOf] resolves a member id to a display name.
List<ActivityEntry> diffActivity({
  required Task before,
  required Task after,
  required String actorId,
  required DateTime now,
  required String Function(String? memberId) nameOf,
}) {
  final out = <ActivityEntry>[];
  void add(ActivityType type, String detail) => out.add(
    makeActivity(
      taskId: after.id,
      actorId: actorId,
      type: type,
      detail: detail,
      now: now,
    ),
  );

  if (before.status != after.status) {
    add(
      ActivityType.statusChanged,
      '${before.status.label} → ${after.status.label}',
    );
  }
  if (before.assigneeId != after.assigneeId) {
    add(
      ActivityType.reassigned,
      '${nameOf(before.assigneeId)} → ${nameOf(after.assigneeId)}',
    );
  }
  if (before.dueDate != after.dueDate) {
    add(
      ActivityType.dueChanged,
      'Due date ${formatDateTime(before.dueDate)} → ${formatDateTime(after.dueDate)}',
    );
  }
  if (before.progress != after.progress) {
    add(
      ActivityType.progressChanged,
      '${before.progress}% → ${after.progress}%',
    );
  }

  final edits = <String>[];
  if (before.title != after.title) {
    edits.add('Title "${before.title}" → "${after.title}"');
  }
  if (before.category != after.category) {
    edits.add('Category ${before.category} → ${after.category}');
  }
  if (before.priority != after.priority) {
    edits.add('Priority ${before.priority.label} → ${after.priority.label}');
  }
  if (before.startDate != after.startDate) {
    edits.add(
      'Start ${formatDateTime(before.startDate)} → ${formatDateTime(after.startDate)}',
    );
  }
  if ((before.description ?? '') != (after.description ?? '')) {
    edits.add('Description updated');
  }
  if (edits.isNotEmpty) add(ActivityType.edited, edits.join('; '));
  return out;
}
