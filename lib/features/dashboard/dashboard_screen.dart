import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/stat_card.dart';
import '../../data/models/enums.dart';
import '../../domain/stats/task_stats.dart';
import '../../state/activity_provider.dart';
import '../../state/session_provider.dart';
import '../../state/task_provider.dart';
import '../activity/activity_tile.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  /// Opens the Tasks tab pre-filtered to [state].
  void _openFiltered(BuildContext context, SlaState state) {
    final tasks = context.read<TaskProvider>();
    tasks.clearFilters();
    tasks.setSlaFilter(state);
    context.go(Routes.tasks);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskProvider>();
    final user = context.watch<SessionProvider>().user;
    final activity = context.watch<ActivityProvider>();
    final theme = Theme.of(context);

    Widget body;
    if (tasks.isLoading && tasks.items.isEmpty) {
      body = const LoadingState();
    } else if (tasks.error != null && tasks.items.isEmpty) {
      body = ErrorState(message: tasks.error!, onRetry: tasks.load);
    } else {
      final stats = tasks.stats;
      final attention = needsAttention(tasks.items);
      final mine = tasks.myItems
          .where((i) => i.task.status != TaskStatus.done)
          .toList();

      body = RefreshIndicator(
        // Pull to refresh re-evaluates every SLA against the current time.
        onRefresh: () => tasks.load(silent: true),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                // ── Greeting ──
                Text(
                  '${greetingFor(tasks.now)}, ${user?.firstName ?? 'there'}',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  formatLongDate(tasks.now),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Project health ──
                _HealthCard(
                  projectName: tasks.project?.name ?? 'Project',
                  stats: stats,
                ),
                const SizedBox(height: 12),

                // ── SLA summary cards (tap = filtered list) ──
                for (final row in const [
                  [SlaState.onTrack, SlaState.atRisk],
                  [SlaState.overdue, SlaState.completed],
                ]) ...[
                  // IntrinsicHeight: equal-height cards inside a scrolling list.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final s in row) ...[
                          Expanded(
                            child: StatCard(
                              state: s,
                              value: stats.counts[s] ?? 0,
                              onTap: () => _openFiltered(context, s),
                            ),
                          ),
                          if (s != row.last) const SizedBox(width: 12),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Needs attention ──
                const SectionHeader(title: 'Needs attention'),
                if (attention.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.celebration_outlined),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Nothing is overdue or at risk. Nice work!',
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < attention.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            onTap: () =>
                                context.push(Routes.task(attention[i].id)),
                            title: Text(
                              attention[i].task.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              attention[i].sla.reason,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: SlaChip(state: attention[i].sla.state),
                          ),
                        ],
                      ],
                    ),
                  ),

                // ── My tasks ──
                const SectionHeader(title: 'My tasks'),
                Card(
                  child: ListTile(
                    onTap: () {
                      tasks.showOnlyMine();
                      context.go(Routes.tasks);
                    },
                    leading: const Icon(Icons.person_outline),
                    title: Text(
                      mine.isEmpty
                          ? 'You have no open tasks'
                          : '${mine.length} open ${mine.length == 1 ? 'task' : 'tasks'}',
                    ),
                    subtitle: mine.isEmpty
                        ? null
                        : Text(
                            'Next due: ${mine.first.task.title} · '
                            '${relativeDue(mine.first.task.dueDate, tasks.now)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),

                // ── Donut chart ──
                const SectionHeader(title: 'SLA distribution'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SlaDonut(counts: stats.counts, total: stats.total),
                  ),
                ),

                // ── Recent activity ──
                SectionHeader(
                  title: 'Recent activity',
                  actionLabel: 'See all',
                  onAction: () => context.push(Routes.activity),
                ),
                if (activity.recent.isEmpty)
                  Text('No activity yet.', style: theme.textTheme.bodySmall)
                else
                  for (final a in activity.recent)
                    ActivityTile(
                      view: a,
                      now: tasks.now,
                      onTap: a.entry.taskId == null
                          ? null
                          : () => context.push(Routes.task(a.entry.taskId!)),
                    ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Statistics',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => context.push(Routes.statistics),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-home',
        onPressed: () => context.push(Routes.taskNew),
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
      body: body,
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.projectName, required this.stats});

  final String projectName;
  final TaskStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completion = (stats.completionRate * 100).round();
    final onTime = stats.onTimeRate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(projectName, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Overall completion',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                AnimatedCount(
                  value: completion,
                  suffix: '%',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(end: stats.completionRate),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 10,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${stats.completed} of ${stats.total} tasks completed',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    onTime == null
                        ? 'SLA compliance: no completed tasks yet'
                        : 'SLA compliance: ${(onTime * 100).round()}% '
                              '(${stats.completedOnTime} of ${stats.completed} completed on time)',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Donut chart + legend for the SLA distribution.
class SlaDonut extends StatelessWidget {
  const SlaDonut({super.key, required this.counts, required this.total});

  final Map<SlaState, int> counts;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (total == 0) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('No tasks to chart yet.')),
      );
    }
    final sections = [
      for (final s in SlaState.values)
        if ((counts[s] ?? 0) > 0)
          PieChartSectionData(
            value: counts[s]!.toDouble(),
            color: AppColors.sla(s, theme.brightness).fg,
            radius: 28,
            showTitle: false,
          ),
    ];
    return Semantics(
      label:
          'SLA distribution: ${[for (final s in SlaState.values) '${counts[s] ?? 0} ${s.label}'].join(', ')}',
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 56,
                    sectionsSpace: 3,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$total', style: theme.textTheme.headlineMedium),
                    Text('tasks', style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final s in SlaState.values)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppColors.slaIcon(s),
                      size: 16,
                      color: AppColors.sla(s, theme.brightness).fg,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${s.label}: ${counts[s] ?? 0}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
