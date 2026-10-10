import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/avatar_circle.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/states.dart';
import '../../data/models/enums.dart';
import '../../domain/permissions.dart';
import '../../domain/stats/task_stats.dart';
import '../../state/member_provider.dart';
import '../../state/session_provider.dart';
import '../../state/task_provider.dart';

class TeamListScreen extends StatelessWidget {
  const TeamListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final members = context.watch<MemberProvider>();
    final tasks = context.watch<TaskProvider>();
    final me = context.watch<SessionProvider>().user;
    final canManage = Permissions.canManageMembers(me);
    final theme = Theme.of(context);

    Widget body;
    if (members.isLoading && members.members.isEmpty) {
      body = const LoadingState();
    } else if (members.error != null && members.members.isEmpty) {
      body = ErrorState(message: members.error!, onRetry: members.load);
    } else if (members.members.isEmpty) {
      body = const EmptyState(
        icon: Icons.groups_outlined,
        title: 'No team members',
        message: 'Add the first member to start assigning tasks.',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () async {
          await members.load(silent: true);
          await tasks.load(silent: true);
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: members.members.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final m = members.members[i];
                final s = memberStats(tasks.items, m.id);
                final err = AppColors.sla(SlaState.overdue, theme.brightness);
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.push(Routes.member(m.id)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          AvatarCircle.member(m, size: 52),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      m.id == me?.id
                                          ? '${m.name} (you)'
                                          : m.name,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    RoleBadge(role: m.role),
                                  ],
                                ),
                                Text(
                                  m.jobTitle,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    _Pill(
                                      icon: Icons.assignment_outlined,
                                      text: '${s.open} open',
                                      fg: theme.colorScheme.onSurfaceVariant,
                                      bg: theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                                    ),
                                    if (s.overdue > 0)
                                      _Pill(
                                        icon: AppColors.slaIcon(
                                          SlaState.overdue,
                                        ),
                                        text: '${s.overdue} overdue',
                                        fg: err.fg,
                                        bg: err.bg,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
      // Only managers see the add button (and the provider re-checks).
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'fab-team',
              onPressed: () => context.push(Routes.memberNew),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add member'),
            )
          : null,
      body: body,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.text,
    required this.fg,
    required this.bg,
  });

  final IconData icon;
  final String text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}
