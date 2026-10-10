import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/states.dart';
import '../../data/models/enums.dart';
import '../../data/models/task.dart';
import '../../domain/permissions.dart';
import '../../domain/task_item.dart';
import '../../state/member_provider.dart';
import '../../state/session_provider.dart';
import '../../state/task_provider.dart';
import 'task_details_screen.dart';
import 'widgets/task_card.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  /// Selected task in the two-column (wide) layout.
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    // Keep the box in sync if a filter was pre-applied (e.g. from Dashboard).
    _searchCtrl.text = context.read<TaskProvider>().filter.query;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    // Debounce 300 ms so we don't re-filter on every keystroke.
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) context.read<TaskProvider>().setQuery(text);
    });
  }

  void _open(TaskItem item, bool wide) {
    if (wide) {
      setState(() => _selectedId = item.id);
    } else {
      context.push(Routes.task(item.id));
    }
  }

  Future<bool> _confirmDismiss(DismissDirection dir, TaskItem item) async {
    final provider = context.read<TaskProvider>();
    final user = context.read<SessionProvider>().user;
    final messenger = ScaffoldMessenger.of(context);

    if (dir == DismissDirection.startToEnd) {
      // Swipe right → mark done.
      if (item.task.isDone) {
        showSnack(context, 'Already done');
        return false;
      }
      if (!Permissions.canUpdateProgress(user, item.task)) {
        showSnack(context, Permissions.denied);
        return false;
      }
      Task? before;
      final ok = await runAction(context, () async {
        // Optimistic: the card flips to Completed immediately, and rolls back
        // inside the provider if the write fails.
        before = await provider.markDone(item.id);
      });
      if (ok && before != null) {
        final original = before!;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('"${item.task.title}" marked done'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => provider.restore(original).catchError((_) {}),
              ),
            ),
          );
      }
      return false; // the card stays in the list; it just changes state
    }

    // Swipe left → delete (permission-checked, with confirmation).
    if (!Permissions.canDeleteTask(user, item.task)) {
      showSnack(context, "You can't delete tasks created by someone else.");
      return false;
    }
    final ok = await showConfirmDialog(
      context,
      title: 'Delete task?',
      message: '"${item.task.title}" and its subtasks will be removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return false;
    await runAction(
      context,
      () => provider.deleteTask(item.id),
      success: 'Task deleted',
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final members = context.watch<MemberProvider>();
    final wide = MediaQuery.sizeOf(context).width >= kWideBreakpoint;
    final filter = provider.filter;

    final list = _buildBody(context, provider, members, wide);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          PopupMenuButton<TaskSort>(
            tooltip: 'Sort tasks',
            icon: const Icon(Icons.sort),
            initialValue: provider.sort,
            onSelected: provider.setSort,
            itemBuilder: (_) => [
              for (final s in TaskSort.values)
                CheckedPopupMenuItem(
                  value: s,
                  checked: s == provider.sort,
                  child: Text(s.label),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Filters',
            onPressed: () => _showFilterSheet(context),
            icon: Badge(
              isLabelVisible: filter.sheetCount > 0,
              label: Text('${filter.sheetCount}'),
              child: const Icon(Icons.filter_list),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-tasks',
        onPressed: () => context.push(Routes.taskNew),
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
      body: wide
          ? Row(
              children: [
                SizedBox(width: 420, child: list),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _selectedId == null
                      ? const EmptyState(
                          icon: Icons.touch_app_outlined,
                          title: 'Select a task',
                          message:
                              'Pick a task on the left to see its details.',
                        )
                      : TaskDetailsScreen(
                          key: ValueKey(_selectedId),
                          taskId: _selectedId!,
                          embedded: true,
                          onClosed: () => setState(() => _selectedId = null),
                        ),
                ),
              ],
            )
          : list,
    );
  }

  Widget _buildBody(
    BuildContext context,
    TaskProvider provider,
    MemberProvider members,
    bool wide,
  ) {
    final filter = provider.filter;
    final theme = Theme.of(context);

    Widget content;
    if (provider.isLoading && provider.items.isEmpty) {
      content = const LoadingState();
    } else if (provider.error != null && provider.items.isEmpty) {
      content = ErrorState(message: provider.error!, onRetry: provider.load);
    } else if (provider.items.isEmpty) {
      content = EmptyState(
        icon: Icons.assignment_outlined,
        title: 'No tasks yet',
        message: 'Create the first task to start tracking your project.',
        actionLabel: 'Create task',
        onAction: () => context.push(Routes.taskNew),
      );
    } else if (provider.visibleTasks.isEmpty) {
      content = EmptyState(
        icon: Icons.search_off,
        title: 'No tasks match your filters',
        message: 'Try a different search or clear the filters.',
        actionLabel: 'Clear filters',
        onAction: () {
          _searchCtrl.clear();
          provider.clearFilters();
        },
      );
    } else {
      final tasks = provider.visibleTasks;
      content = RefreshIndicator(
        // Pull to refresh re-evaluates every SLA against the current time.
        onRefresh: () => provider.load(silent: true),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          itemCount: tasks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final item = tasks[i];
            return Dismissible(
              key: ValueKey(item.id),
              confirmDismiss: (dir) => _confirmDismiss(dir, item),
              background: _swipeBg(
                color: AppColors.sla(SlaState.onTrack, theme.brightness).bg,
                fg: AppColors.sla(SlaState.onTrack, theme.brightness).fg,
                icon: Icons.check,
                label: 'Mark done',
                alignment: Alignment.centerLeft,
              ),
              secondaryBackground: _swipeBg(
                color: AppColors.sla(SlaState.overdue, theme.brightness).bg,
                fg: AppColors.sla(SlaState.overdue, theme.brightness).fg,
                icon: Icons.delete_outline,
                label: 'Delete',
                alignment: Alignment.centerRight,
              ),
              child: TaskCard(
                item: item,
                now: provider.now,
                assignee: members.byId(item.task.assigneeId),
                selected: wide && _selectedId == item.id,
                hero: !wide,
                onTap: () => _open(item, wide),
              ),
            );
          },
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SearchBar(
            controller: _searchCtrl,
            hintText: 'Search title, description, category',
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll(0),
            onChanged: _onSearchChanged,
            trailing: [
              if (_searchCtrl.text.isNotEmpty)
                IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchCtrl.clear();
                    provider.setQuery('');
                    setState(() {});
                  },
                ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _chip(
                label: 'All',
                selected: filter.sla == null,
                onSelected: () => provider.setSlaFilter(null),
              ),
              for (final s in SlaState.values)
                _chip(
                  label: '${s.label} (${provider.slaCounts[s] ?? 0})',
                  icon: AppColors.slaIcon(s),
                  selected: filter.sla == s,
                  onSelected: () =>
                      provider.setSlaFilter(filter.sla == s ? null : s),
                ),
              _chip(
                label: 'Assigned to me',
                icon: Icons.person_outline,
                selected: filter.assignedToMe,
                onSelected: provider.toggleAssignedToMe,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: content),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    IconData? icon,
  }) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(label),
      avatar: icon == null ? null : Icon(icon, size: 18),
      selected: selected,
      showCheckmark: icon == null,
      onSelected: (_) => onSelected(),
    ),
  );

  Widget _swipeBg({
    required Color color,
    required Color fg,
    required IconData icon,
    required String label,
    required Alignment alignment,
  }) => Container(
    alignment: alignment,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(Spacing.cardRadius),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: fg),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: fg, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Future<void> _showFilterSheet(BuildContext context) async {
    final provider = context.read<TaskProvider>();
    final members = context.read<MemberProvider>().members;
    var assignee = provider.filter.assigneeId;
    var priority = provider.filter.priority;
    var category = provider.filter.category;
    var status = provider.filter.status;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Filter tasks', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: assignee,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Assignee'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Anyone')),
                    for (final m in members)
                      DropdownMenuItem(value: m.id, child: Text(m.name)),
                  ],
                  onChanged: (v) => setSheet(() => assignee = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Priority?>(
                  initialValue: priority,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Any priority'),
                    ),
                    for (final p in Priority.values)
                      DropdownMenuItem(value: p, child: Text(p.label)),
                  ],
                  onChanged: (v) => setSheet(() => priority = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Any category'),
                    ),
                    for (final c in kTaskCategories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setSheet(() => category = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TaskStatus?>(
                  initialValue: status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Any status'),
                    ),
                    for (final s in TaskStatus.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (v) => setSheet(() => status = v),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setSheet(() {
                          assignee = null;
                          priority = null;
                          category = null;
                          status = null;
                        }),
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          provider.applySheetFilters(
                            assigneeId: assignee,
                            priority: priority,
                            category: category,
                            status: status,
                          );
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
