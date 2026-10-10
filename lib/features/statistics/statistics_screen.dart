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
import '../../state/member_provider.dart';
import '../../state/task_provider.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskProvider>();
    final members = context.watch<MemberProvider>();
    final theme = Theme.of(context);
    final stats = tasks.stats;
    final upcoming = upcomingDeadlines(tasks.items, tasks.now);

    Widget body;
    if (tasks.isLoading && tasks.items.isEmpty) {
      body = const LoadingState();
    } else if (tasks.error != null && tasks.items.isEmpty) {
      body = ErrorState(message: tasks.error!, onRetry: tasks.load);
    } else if (tasks.items.isEmpty) {
      body = const EmptyState(
        icon: Icons.bar_chart,
        title: 'No data yet',
        message: 'Statistics appear once the team has some tasks.',
      );
    } else {
      final rate = stats.onTimeRate;
      final avg = stats.averageDaysEarly;
      body = RefreshIndicator(
        onRefresh: () => tasks.load(silent: true),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _Metric(
                          icon: Icons.verified_outlined,
                          label: 'On-time completion',
                          value: rate == null
                              ? '—'
                              : '${(rate * 100).round()}%',
                          detail:
                              '${stats.completedOnTime} on time · ${stats.completedLate} late',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Metric(
                          icon: Icons.timer_outlined,
                          label: 'Average finish',
                          value: avg == null
                              ? '—'
                              : '${avg.abs().toStringAsFixed(1)} d ${avg >= 0 ? 'early' : 'late'}',
                          detail: 'versus the due date',
                        ),
                      ),
                    ],
                  ),
                ),
                const SectionHeader(title: 'Tasks per SLA state'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 24, 16, 12),
                    child: SizedBox(
                      height: 220,
                      child: _StateBars(counts: stats.counts),
                    ),
                  ),
                ),
                const SectionHeader(title: 'Workload per member'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 24, 16, 12),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 240,
                          child: _MemberBars(
                            names: [
                              for (final m in members.members) m.firstName,
                            ],
                            stats: [
                              for (final m in members.members)
                                memberStats(tasks.items, m.id),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const _Legend(),
                      ],
                    ),
                  ),
                ),
                const SectionHeader(title: 'Upcoming deadlines (next 7 days)'),
                if (upcoming.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No open tasks are due in the next 7 days.'),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < upcoming.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            onTap: () =>
                                context.push(Routes.task(upcoming[i].id)),
                            title: Text(
                              upcoming[i].task.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${formatDateTime(upcoming[i].task.dueDate)} · '
                              '${relativeDue(upcoming[i].task.dueDate, tasks.now)}',
                            ),
                            trailing: SlaChip(state: upcoming[i].sla.state),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Statistics', style: theme.textTheme.titleLarge),
      ),
      body: body,
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.headlineSmall),
            Text(label, style: theme.textTheme.labelLarge),
            Text(detail, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

FlTitlesData _titles(Widget Function(double, TitleMeta) bottom) => FlTitlesData(
  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  leftTitles: const AxisTitles(
    sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 1),
  ),
  bottomTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 32,
      getTitlesWidget: bottom,
    ),
  ),
);

class _StateBars extends StatelessWidget {
  const _StateBars({required this.counts});

  final Map<SlaState, int> counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxY = counts.values.fold<int>(1, (a, b) => a > b ? a : b).toDouble();
    return Semantics(
      label:
          'Bar chart of tasks per SLA state: ${[for (final s in SlaState.values) '${counts[s]} ${s.label}'].join(', ')}',
      child: BarChart(
        BarChartData(
          maxY: maxY + 1,
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: _titles((value, meta) {
            final s = SlaState.values[value.toInt()];
            return SideTitleWidget(
              meta: meta,
              child: Icon(
                AppColors.slaIcon(s),
                size: 18,
                color: AppColors.sla(s, theme.brightness).fg,
              ),
            );
          }),
          barGroups: [
            for (final s in SlaState.values)
              BarChartGroupData(
                x: s.index,
                barRods: [
                  BarChartRodData(
                    toY: (counts[s] ?? 0).toDouble(),
                    width: 28,
                    color: AppColors.sla(s, theme.brightness).fg,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
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

/// Grouped bars per member: open (not overdue) / overdue / completed.
class _MemberBars extends StatelessWidget {
  const _MemberBars({required this.names, required this.stats});

  final List<String> names;
  final List<MemberStats> stats;

  static Color openColor(Brightness b) => AppColors.sla(SlaState.onTrack, b).fg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    var maxY = 1;
    for (final s in stats) {
      for (final v in [s.open - s.overdue, s.overdue, s.completed]) {
        if (v > maxY) maxY = v;
      }
    }
    BarChartRodData rod(int v, Color c) => BarChartRodData(
      toY: v.toDouble(),
      width: 10,
      color: c,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
    );
    return Semantics(
      label:
          'Grouped bar chart of open, overdue and completed tasks per member',
      child: BarChart(
        BarChartData(
          maxY: maxY + 1,
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: _titles((value, meta) {
            final i = value.toInt();
            return SideTitleWidget(
              meta: meta,
              child: Text(
                i < names.length ? names[i] : '',
                style: theme.textTheme.labelSmall,
              ),
            );
          }),
          barGroups: [
            for (var i = 0; i < stats.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 2,
                barRods: [
                  rod(stats[i].open - stats[i].overdue, openColor(b)),
                  rod(stats[i].overdue, AppColors.sla(SlaState.overdue, b).fg),
                  rod(
                    stats[i].completed,
                    AppColors.sla(SlaState.completed, b).fg,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    Widget item(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        item(_MemberBars.openColor(b), 'Open'),
        item(AppColors.sla(SlaState.overdue, b).fg, 'Overdue'),
        item(AppColors.sla(SlaState.completed, b).fg, 'Completed'),
      ],
    );
  }
}
