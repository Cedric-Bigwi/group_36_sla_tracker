import 'package:flutter/material.dart';

import '../../data/models/enums.dart';
import '../theme/app_colors.dart';

/// SLA state chip. Color is never the only signal: it always has an icon and
/// text. Colors animate when the state changes (e.g. At Risk → On Track).
class SlaChip extends StatelessWidget {
  const SlaChip({super.key, required this.state, this.large = false});

  final SlaState state;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.sla(state, Theme.of(context).brightness);
    final style = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: c.fg, fontSize: large ? 14 : null);
    return Semantics(
      label: 'SLA status: ${state.label}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          horizontal: large ? 12 : 8,
          vertical: large ? 6 : 4,
        ),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppColors.slaIcon(state), size: large ? 18 : 14, color: c.fg),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                state.label,
                style: style,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Workflow status (what the user sets). Deliberately neutral so it is not
/// confused with the colored SLA chip.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final TaskStatus status;

  static IconData iconFor(TaskStatus s) => switch (s) {
    TaskStatus.todo => Icons.radio_button_unchecked,
    TaskStatus.inProgress => Icons.timelapse,
    TaskStatus.inReview => Icons.rate_review_outlined,
    TaskStatus.done => Icons.check_circle,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Status: ${status.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconFor(status), size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                status.label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({
    super.key,
    required this.priority,
    this.showLabel = true,
  });

  final Priority priority;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.priority(priority, Theme.of(context).brightness);
    return Semantics(
      label: '${priority.label} priority',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppColors.priorityIcon(priority), size: 18, color: color),
          if (showLabel) ...[
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                priority.label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small badge for a member's role.
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});

  final MemberRole role;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isManager = role == MemberRole.manager;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isManager
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isManager
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
