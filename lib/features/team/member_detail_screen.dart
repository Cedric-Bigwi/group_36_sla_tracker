import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/avatar_circle.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/stat_card.dart';
import '../../data/models/enums.dart';
import '../../domain/permissions.dart';
import '../../domain/stats/task_stats.dart';
import '../../state/member_provider.dart';
import '../../state/session_provider.dart';
import '../../state/task_provider.dart';
import '../tasks/widgets/task_card.dart';

class MemberDetailScreen extends StatelessWidget {
  const MemberDetailScreen({super.key, required this.memberId});

  final String memberId;

  Future<void> _remove(BuildContext context) async {
    final members = context.read<MemberProvider>();
    final member = members.byId(memberId);
    if (member == null) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Remove ${member.name}?',
      message: 'Their tasks will become unassigned. This cannot be undone.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final done = await runAction(
      context,
      () => members.remove(member),
      success: '${member.name} removed',
    );
    if (done && context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final members = context.watch<MemberProvider>();
    final tasks = context.watch<TaskProvider>();
    final me = context.watch<SessionProvider>().user;
    final member = members.byId(memberId);
    final theme = Theme.of(context);

    if (member == null) {
      return Scaffold(
        appBar: AppBar(),
        body: members.isLoading
            ? const LoadingState()
            : const EmptyState(
                icon: Icons.person_off_outlined,
                title: 'Member not found',
                message: 'They may have been removed from the team.',
              ),
      );
    }

    final mine =
        tasks.items.where((i) => i.task.assigneeId == member.id).toList()
          ..sort(compareUrgency);
    final stats = memberStats(tasks.items, member.id);
    final canManage = Permissions.canManageMembers(me);
    final canEdit = Permissions.canEditMember(me, member);
    final rate = stats.onTimeRate;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team member'),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'Edit member',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(Routes.memberEdit(member.id)),
            ),
          if (canManage && me!.id != member.id)
            IconButton(
              tooltip: 'Remove member',
              icon: const Icon(Icons.person_remove_outlined),
              onPressed: () => _remove(context),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  AvatarCircle.member(member, size: 72),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.name, style: theme.textTheme.titleLarge),
                        Text(
                          member.jobTitle,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            RoleBadge(role: member.role),
                            Text(
                              member.email,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: 'Open',
                        value: '${stats.open}',
                        icon: Icons.assignment_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStat(
                        label: 'Overdue',
                        value: '${stats.overdue}',
                        icon: AppColors.slaIcon(SlaState.overdue),
                        color: stats.overdue > 0
                            ? AppColors.sla(
                                SlaState.overdue,
                                theme.brightness,
                              ).fg
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStat(
                        label: 'On-time rate',
                        value: rate == null ? '—' : '${(rate * 100).round()}%',
                        icon: Icons.verified_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              if (mine.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: EmptyState(
                    icon: Icons.assignment_turned_in_outlined,
                    title: 'No assigned tasks',
                    message: 'Tasks assigned to this person will appear here.',
                  ),
                ),
              // Tasks grouped by SLA state, most urgent group first.
              for (final state in const [
                SlaState.overdue,
                SlaState.atRisk,
                SlaState.onTrack,
                SlaState.completed,
              ])
                if (mine.any((i) => i.sla.state == state)) ...[
                  SectionHeader(
                    title:
                        '${state.label} (${mine.where((i) => i.sla.state == state).length})',
                  ),
                  for (final item in mine.where(
                    (i) => i.sla.state == state,
                  )) ...[
                    TaskCard(
                      item: item,
                      now: tasks.now,
                      assignee: member,
                      hero: false,
                      onTap: () => context.push(Routes.task(item.id)),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color ?? theme.colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(color: color),
            ),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
