import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/states.dart';
import '../../data/models/activity_entry.dart';
import '../../state/activity_provider.dart';
import '../../state/member_provider.dart';
import '../../state/task_provider.dart';
import 'activity_tile.dart';

/// Full chronological log grouped by day, filterable by member.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<ActivityProvider>();
    final members = context.watch<MemberProvider>();
    final now = context.watch<TaskProvider>().now;
    final theme = Theme.of(context);

    // Flatten into [header, entry, entry, header, ...] for a lazy list.
    final rows = <Object>[];
    DateTime? lastDay;
    for (final a in activity.filtered) {
      final day = dateOnly(a.entry.createdAt);
      if (lastDay != day) {
        rows.add(dayLabel(a.entry.createdAt, now));
        lastDay = day;
      }
      rows.add(a);
    }

    Widget body;
    if (activity.isLoading && activity.all.isEmpty) {
      body = const LoadingState();
    } else if (activity.error != null && activity.all.isEmpty) {
      body = ErrorState(message: activity.error!, onRetry: activity.load);
    } else if (rows.isEmpty) {
      body = const EmptyState(
        icon: Icons.history,
        title: 'No activity',
        message: 'Changes to tasks will be logged here.',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => activity.load(silent: true),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final row = rows[i];
                if (row is String) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 4),
                    child: Semantics(
                      header: true,
                      child: Text(row, style: theme.textTheme.titleSmall),
                    ),
                  );
                }
                final view = row as ActivityView;
                return ActivityTile(
                  view: view,
                  now: now,
                  onTap: view.entry.taskId == null
                      ? null
                      : () => context.push(Routes.task(view.entry.taskId!)),
                );
              },
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Everyone'),
                    selected: activity.actorFilter == null,
                    onSelected: (_) => activity.setActorFilter(null),
                  ),
                ),
                for (final m in members.members)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(m.firstName),
                      selected: activity.actorFilter == m.id,
                      onSelected: (_) => activity.setActorFilter(
                        activity.actorFilter == m.id ? null : m.id,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
