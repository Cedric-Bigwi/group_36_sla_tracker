import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/avatar_circle.dart';
import '../../../core/widgets/chips.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/team_member.dart';
import '../../../domain/task_item.dart';

/// Hero tag shared by the card's SLA chip and the details header.
String slaHeroTag(String taskId) => 'sla-chip-$taskId';

/// One task in a list: title, category, assignee, relative due date, priority,
/// SLA chip and a thin progress bar.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.item,
    required this.now,
    required this.assignee,
    required this.onTap,
    this.selected = false,
    this.hero = true,
  });

  final TaskItem item;
  final DateTime now;
  final TeamMember? assignee;
  final VoidCallback onTap;
  final bool selected;

  /// Disabled when the details pane is shown next to the list (two identical
  /// Hero tags on one screen would throw).
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = item.task;
    final sla = AppColors.sla(item.sla.state, theme.brightness);
    final chip = SlaChip(state: item.sla.state);
    final dueText = task.isDone
        ? 'Done ${formatShortDate(task.completedAt ?? task.updatedAt)}'
        : relativeDue(task.dueDate, now);
    final dueColor = item.sla.state == SlaState.overdue
        ? sla.fg
        : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      container: true,
      label:
          '${task.title}. ${item.sla.state.label}. ${task.priority.label} priority. '
          'Due ${formatDate(task.dueDate)}, $dueText. ${task.progress} percent complete.',
      child: Card(
        color: selected ? theme.colorScheme.secondaryContainer : null,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    hero
                        ? Hero(
                            tag: slaHeroTag(task.id),
                            child: Material(
                              type: MaterialType.transparency,
                              child: chip,
                            ),
                          )
                        : chip,
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      task.category,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    PriorityBadge(priority: task.priority),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 14, color: dueColor),
                        const SizedBox(width: 4),
                        Text(
                          dueText,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: dueColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    assignee == null
                        ? const AvatarCircle.unassigned(size: 28)
                        : AvatarCircle.member(assignee!, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        assignee?.name ?? 'Unassigned',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      '${task.progress}%',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: task.progress / 100),
                    duration: const Duration(milliseconds: 400),
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 4,
                      color: sla.fg,
                      backgroundColor: sla.bg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
