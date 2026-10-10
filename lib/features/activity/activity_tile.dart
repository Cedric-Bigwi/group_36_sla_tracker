import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';
import '../../core/widgets/avatar_circle.dart';
import '../../data/models/activity_entry.dart';
import '../../data/models/enums.dart';

/// One line of the activity log: "Ali changed status of 'Task'" + detail + time.
class ActivityTile extends StatelessWidget {
  const ActivityTile({
    super.key,
    required this.view,
    required this.now,
    this.showTask = true,
    this.onTap,
  });

  final ActivityView view;
  final DateTime now;

  /// Hide the task name inside a task's own history.
  final bool showTask;
  final VoidCallback? onTap;

  static IconData iconFor(ActivityType t) => switch (t) {
    ActivityType.created => Icons.add_circle_outline,
    ActivityType.statusChanged => Icons.swap_horiz,
    ActivityType.reassigned => Icons.person_add_alt,
    ActivityType.dueChanged => Icons.event,
    ActivityType.progressChanged => Icons.trending_up,
    ActivityType.edited => Icons.edit_outlined,
    ActivityType.deleted => Icons.delete_outline,
    ActivityType.noteAdded => Icons.sticky_note_2_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = view.entry;
    final firstName = view.actorName.split(' ').first;
    // Deleted tasks no longer exist to join against; the detail names them.
    final target = e.type == ActivityType.deleted
        ? ' a task'
        : (showTask && view.taskTitle != null ? ' "${view.taskTitle}"' : '');
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          AvatarCircle(
            initials: view.actorName.isEmpty
                ? '?'
                : view.actorName.trim()[0].toUpperCase(),
            color: view.actorColor,
            size: 40,
            semanticLabel: view.actorName,
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconFor(e.type),
                size: 14,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      title: Text(
        '$firstName ${e.type.verb}$target',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          if (e.detail != null && e.detail!.isNotEmpty) e.detail!,
          timeAgo(e.createdAt, now),
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
