import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/avatar_circle.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/stat_card.dart';
import '../../data/models/activity_entry.dart';
import '../../data/models/enums.dart';
import '../../domain/permissions.dart';
import '../../domain/task_item.dart';
import '../../state/activity_provider.dart';
import '../../state/member_provider.dart';
import '../../state/session_provider.dart';
import '../../state/task_provider.dart';
import '../activity/activity_tile.dart';
import 'widgets/sla_panel.dart';
import 'widgets/task_card.dart';

/// Full task view. Used as a pushed page on phones and embedded in the right
/// pane of the two-column layout on tablets ([embedded]).
class TaskDetailsScreen extends StatefulWidget {
  const TaskDetailsScreen({
    super.key,
    required this.taskId,
    this.embedded = false,
    this.onClosed,
  });

  final String taskId;
  final bool embedded;

  /// Called after the task was deleted while embedded.
  final VoidCallback? onClosed;

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  final _notesCtrl = TextEditingController();
  final _subCtrl = TextEditingController();
  Timer? _notesTimer;
  String _notesStatus = '';
  bool _notesInit = false;
  double? _progressDraft;

  List<ActivityView> _history = const [];
  int _historyRev = -1;
  TaskProvider? _provider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<TaskProvider>();
  }

  @override
  void dispose() {
    // Don't lose notes typed less than a debounce interval before leaving.
    if (_notesTimer?.isActive ?? false) {
      _notesTimer!.cancel();
      _provider?.setNotes(widget.taskId, _notesCtrl.text).catchError((_) {});
    }
    _notesCtrl.dispose();
    _subCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    try {
      final h = await context.read<ActivityProvider>().forTask(widget.taskId);
      if (mounted) setState(() => _history = h);
    } catch (_) {
      // History is optional; ignore failures here.
    }
  }

  void _onNotesChanged(String text) {
    setState(() => _notesStatus = 'Saving…');
    _notesTimer?.cancel();
    _notesTimer = Timer(const Duration(milliseconds: 800), () async {
      final ok = await runAction(
        context,
        () => context.read<TaskProvider>().setNotes(widget.taskId, text),
      );
      if (mounted) setState(() => _notesStatus = ok ? 'Saved' : 'Not saved');
    });
  }

  void _close() {
    if (widget.embedded) {
      widget.onClosed?.call();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.tasks);
    }
  }

  Future<void> _delete(TaskItem item) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete task?',
      message: '"${item.task.title}" and its subtasks will be removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final tasks = context.read<TaskProvider>();
    final done = await runAction(
      context,
      () => tasks.deleteTask(item.id),
      success: 'Task deleted',
    );
    if (done && mounted) _close();
  }

  Future<void> _duplicate(TaskItem item) async {
    final tasks = context.read<TaskProvider>();
    final router = GoRouter.of(context);
    var copyId = '';
    final ok = await runAction(context, () async {
      copyId = (await tasks.duplicateTask(item.id)).id;
    }, success: 'Task duplicated');
    if (ok && !widget.embedded) router.pushReplacement(Routes.task(copyId));
  }

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskProvider>();
    final members = context.watch<MemberProvider>();
    final user = context.watch<SessionProvider>().user;
    final item = tasks.itemById(widget.taskId);

    if (item == null) {
      return Scaffold(
        appBar: AppBar(automaticallyImplyLeading: !widget.embedded),
        body: tasks.isLoading
            ? const LoadingState()
            : EmptyState(
                icon: Icons.search_off,
                title: 'Task not found',
                message: 'It may have been deleted.',
                actionLabel: widget.embedded ? null : 'Back to tasks',
                onAction: () => context.go(Routes.tasks),
              ),
      );
    }

    final task = item.task;
    if (!_notesInit) {
      _notesInit = true;
      _notesCtrl.text = task.notes ?? '';
    }
    if (_historyRev != tasks.revision) {
      _historyRev = tasks.revision;
      _fetchHistory();
    }

    final canEdit = Permissions.canEditTask(user, task);
    final canUpdate = Permissions.canUpdateProgress(user, task);
    final canDelete = Permissions.canDeleteTask(user, task);
    final assignee = members.byId(task.assigneeId);
    final theme = Theme.of(context);
    final progressValue = _progressDraft ?? task.progress.toDouble();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Text(
          widget.embedded ? task.title : 'Task details',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Task actions',
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  context.push(Routes.taskEdit(task.id));
                case 'duplicate':
                  _duplicate(item);
                case 'delete':
                  _delete(item);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                enabled: canEdit,
                child: const ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'duplicate',
                enabled: Permissions.canCreateTask(user),
                child: const ListTile(
                  leading: Icon(Icons.copy_outlined),
                  title: Text('Duplicate'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                // Disabled (not hidden) so members see why they can't delete.
                enabled: canDelete,
                child: ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: canDelete ? theme.colorScheme.error : null,
                  ),
                  title: Text(canDelete ? 'Delete' : "Delete (not your task)"),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Header ──
              Text(task.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.embedded)
                    SlaChip(state: item.sla.state, large: true)
                  else
                    Hero(
                      tag: slaHeroTag(task.id),
                      child: Material(
                        type: MaterialType.transparency,
                        child: SlaChip(state: item.sla.state, large: true),
                      ),
                    ),
                  Chip(
                    label: Text(task.category),
                    visualDensity: VisualDensity.compact,
                  ),
                  StatusChip(status: task.status),
                ],
              ),
              if (task.description != null && task.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(task.description!, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 16),

              // ── SLA panel ──
              SlaPanel(
                result: item.sla,
                start: task.startDate,
                due: task.dueDate,
                now: tasks.now,
              ),
              const SizedBox(height: 16),

              // ── Fields ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: assignee == null
                            ? const AvatarCircle.unassigned()
                            : AvatarCircle.member(assignee),
                        title: Text(
                          assignee?.name ??
                              (task.assigneeId == null
                                  ? 'Unassigned'
                                  : 'Former member'),
                        ),
                        subtitle: Text(assignee?.jobTitle ?? 'Assignee'),
                        trailing: assignee == null
                            ? null
                            : const Icon(Icons.chevron_right),
                        onTap: assignee == null
                            ? null
                            : () => context.push(Routes.member(assignee.id)),
                      ),
                      const Divider(),
                      _fieldRow(
                        'Priority',
                        PriorityBadge(priority: task.priority),
                      ),
                      _fieldRow('Start', Text(formatDateTime(task.startDate))),
                      _fieldRow('Due', Text(formatDateTime(task.dueDate))),
                      _fieldRow(
                        'Created by',
                        Text(members.nameOf(task.createdBy)),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<TaskStatus>(
                        initialValue: task.status,
                        key: ValueKey('status-${task.status.name}'),
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: [
                          for (final s in TaskStatus.values)
                            DropdownMenuItem(value: s, child: Text(s.label)),
                        ],
                        onChanged: canUpdate
                            ? (s) {
                                if (s != null && s != task.status) {
                                  runAction(
                                    context,
                                    () => tasks.setStatus(task.id, s),
                                  );
                                }
                              }
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text('Progress', style: theme.textTheme.labelLarge),
                          const Spacer(),
                          AnimatedCount(
                            value: progressValue.round(),
                            suffix: '%',
                            style: theme.textTheme.labelLarge,
                          ),
                        ],
                      ),
                      if (item.hasSubtasks) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: task.progress / 100,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Calculated from subtasks '
                          '(${item.subtasks.where((s) => s.isDone).length} of ${item.subtasks.length} done)',
                          style: theme.textTheme.bodySmall,
                        ),
                      ] else
                        Slider(
                          value: progressValue,
                          min: 0,
                          max: 100,
                          divisions: 20,
                          label: '${progressValue.round()}%',
                          semanticFormatterCallback: (v) =>
                              '${v.round()} percent',
                          onChanged: canUpdate
                              ? (v) => setState(() => _progressDraft = v)
                              : null,
                          onChangeEnd: canUpdate
                              ? (v) async {
                                  await runAction(
                                    context,
                                    () => tasks.setProgress(task.id, v.round()),
                                  );
                                  if (mounted) {
                                    setState(() => _progressDraft = null);
                                  }
                                }
                              : null,
                        ),
                      if (!canUpdate)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Only the creator, the assignee or a manager can change this task.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Subtasks ──
              const SectionHeader(title: 'Subtasks'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      if (item.subtasks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'No subtasks. Add some to calculate progress automatically.',
                            style: theme.textTheme.bodySmall,
                          ),
                        )
                      else
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: item.subtasks.length,
                          onReorder: (o, n) {
                            if (!canEdit) return;
                            runAction(
                              context,
                              () => tasks.reorderSubtasks(task.id, o, n),
                            );
                          },
                          itemBuilder: (ctx, i) {
                            final s = item.subtasks[i];
                            return ListTile(
                              key: ValueKey(s.id),
                              contentPadding: const EdgeInsets.only(left: 4),
                              leading: Checkbox(
                                value: s.isDone,
                                onChanged: canUpdate
                                    ? (v) => runAction(
                                        context,
                                        () => tasks.toggleSubtask(
                                          task.id,
                                          s,
                                          v ?? false,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Text(
                                s.title,
                                style: s.isDone
                                    ? TextStyle(
                                        decoration: TextDecoration.lineThrough,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      )
                                    : null,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Delete subtask ${s.title}',
                                    icon: const Icon(Icons.close),
                                    onPressed: canEdit
                                        ? () => runAction(
                                            context,
                                            () =>
                                                tasks.deleteSubtask(task.id, s),
                                          )
                                        : null,
                                  ),
                                  ReorderableDragStartListener(
                                    index: i,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Icon(
                                        Icons.drag_handle,
                                        semanticLabel: 'Reorder ${s.title}',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      if (canEdit)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _subCtrl,
                                  textInputAction: TextInputAction.done,
                                  decoration: const InputDecoration(
                                    hintText: 'Add a subtask',
                                    isDense: true,
                                  ),
                                  onSubmitted: (_) => _addSubtask(task.id),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                tooltip: 'Add subtask',
                                onPressed: () => _addSubtask(task.id),
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Notes ──
              const SectionHeader(title: 'Notes'),
              TextField(
                controller: _notesCtrl,
                enabled: canUpdate,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: 'Add notes… they save automatically',
                  helperText: _notesStatus.isEmpty ? null : _notesStatus,
                ),
                onChanged: _onNotesChanged,
              ),

              // ── History ──
              const SectionHeader(title: 'Activity'),
              if (_history.isEmpty)
                Text('No activity yet.', style: theme.textTheme.bodySmall)
              else
                for (final h in _history)
                  ActivityTile(view: h, now: tasks.now, showTask: false),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addSubtask(String taskId) async {
    final text = _subCtrl.text;
    if (text.trim().isEmpty) return;
    final ok = await runAction(
      context,
      () => context.read<TaskProvider>().addSubtask(taskId, text),
    );
    if (ok) _subCtrl.clear();
  }

  Widget _fieldRow(String label, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Align(alignment: Alignment.centerLeft, child: value),
        ),
      ],
    ),
  );
}
