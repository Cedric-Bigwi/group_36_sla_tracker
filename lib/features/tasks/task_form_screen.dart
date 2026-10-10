import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/avatar_circle.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/states.dart';
import '../../data/models/enums.dart';
import '../../data/models/team_member.dart';
import '../../domain/permissions.dart';
import '../../domain/sla/sla_result.dart';
import '../../state/member_provider.dart';
import '../../state/session_provider.dart';
import '../../state/task_draft.dart';
import '../../state/task_provider.dart';

/// Create (no [taskId]) or edit (with [taskId]) a task.
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key, this.taskId});

  final String? taskId;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _startKey = GlobalKey<FormFieldState<DateTime>>();
  final _dueKey = GlobalKey<FormFieldState<DateTime>>();
  final _title = TextEditingController();
  final _description = TextEditingController();

  String? _category;
  String? _assigneeId;
  Priority _priority = Priority.medium;
  TaskStatus _status = TaskStatus.todo;
  DateTime? _start;
  DateTime? _due;
  double _progress = 0;

  bool _initialised = false;
  bool _dirty = false;
  bool _saving = false;
  bool _duplicateTitle = false;
  Timer? _titleDebounce;

  // Original values, to know if the due date changed on edit.
  DateTime? _originalDue;

  bool get _isEdit => widget.taskId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    final tasks = context.read<TaskProvider>();
    if (_isEdit) {
      final item = tasks.itemById(widget.taskId!);
      if (item != null) {
        final t = item.task;
        _title.text = t.title;
        _description.text = t.description ?? '';
        _category = t.category;
        _assigneeId = t.assigneeId;
        _priority = t.priority;
        _status = t.status;
        _start = t.startDate;
        _due = t.dueDate;
        _originalDue = t.dueDate;
        _progress = t.progress.toDouble();
      }
    } else {
      // Defaults from the spec: priority Medium, status To Do, start = now.
      final now = _truncate(tasks.clockNow);
      _start = now;
      _due = now.add(const Duration(days: 3));
    }
  }

  @override
  void dispose() {
    _titleDebounce?.cancel();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  static DateTime _truncate(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day, d.hour, d.minute);

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _onTitleChanged(String value) {
    _markDirty();
    _titleDebounce?.cancel();
    _titleDebounce = Timer(const Duration(milliseconds: 400), () async {
      final tasks = context.read<TaskProvider>();
      if (value.trim().length < 3) {
        if (_duplicateTitle && mounted) setState(() => _duplicateTitle = false);
        return;
      }
      final taken = await tasks.isTitleTaken(value, excludeId: widget.taskId);
      if (mounted) setState(() => _duplicateTitle = taken);
    });
  }

  Future<DateTime?> _pickDateTime(DateTime? current) async {
    final base = (current ?? DateTime.now().toUtc()).toLocal();
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(base.year - 2),
      lastDate: DateTime(base.year + 5),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ).toUtc();
  }

  TaskDraft? _draft() {
    if (_start == null || _due == null) return null;
    return TaskDraft(
      title: _title.text,
      description: _description.text,
      category: _category ?? 'Other',
      assigneeId: _assigneeId,
      priority: _priority,
      status: _status,
      startDate: _start!,
      dueDate: _due!,
      progress: _progress.round(),
    );
  }

  Future<void> _save() async {
    final tasks = context.read<TaskProvider>();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final draft = _draft();
    if (draft == null) return;

    // Editing a task into the past is allowed, but only after a warning.
    if (_isEdit && _due != _originalDue && _due!.isBefore(tasks.clockNow)) {
      final ok = await showConfirmDialog(
        context,
        title: 'Due date is in the past',
        message:
            'This task will be shown as Overdue straight away. Save anyway?',
        confirmLabel: 'Save anyway',
      );
      if (!ok || !mounted) return;
    }

    setState(() => _saving = true);
    final ok = await runAction(
      context,
      () => _isEdit
          ? tasks.updateTask(widget.taskId!, draft)
          : tasks.createTask(draft),
      success: _isEdit ? 'Task updated' : 'Task created',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) _leave();
  }

  /// Pop back, or fall back to the task list when opened via a deep link.
  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.tasks);
    }
  }

  Future<void> _confirmDiscard() async {
    final discard = await showConfirmDialog(
      context,
      title: 'Discard changes?',
      message: 'Your unsaved changes will be lost.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      destructive: true,
    );
    if (discard && mounted) _leave();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskProvider>();
    final members = context.watch<MemberProvider>();
    final user = context.watch<SessionProvider>().user;
    final item = _isEdit ? tasks.itemById(widget.taskId!) : null;

    if (_isEdit && item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.search_off,
          title: 'Task not found',
          message: 'It may have been deleted.',
        ),
      );
    }
    if (_isEdit && !Permissions.canEditTask(user, item!.task)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit task')),
        body: const EmptyState(
          icon: Icons.lock_outline,
          title: 'No permission',
          message:
              'Only the creator, the assignee or a manager can edit this task.',
        ),
      );
    }

    final hasSubtasks = item?.hasSubtasks ?? false;
    final theme = Theme.of(context);
    final now = tasks.clockNow;

    // Managers can assign anyone; members only themselves (or leave it).
    final assignable = <TeamMember>[
      for (final m in members.members)
        if (user?.isManager == true || m.id == user?.id || m.id == _assigneeId)
          m,
    ];

    final draft = _draft();
    final preview = draft == null
        ? null
        : tasks.preview(draft, subtasks: item?.subtasks ?? const []);

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_isEdit ? 'Edit task' : 'New task')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Form(
                key: _formKey,
                onChanged: _markDirty,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextFormField(
                      controller: _title,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        helper: _duplicateTitle
                            ? Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 16,
                                    color: AppColors.sla(
                                      SlaState.atRisk,
                                      theme.brightness,
                                    ).fg,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Another task already uses this title',
                                      style: TextStyle(
                                        color: AppColors.sla(
                                          SlaState.atRisk,
                                          theme.brightness,
                                        ).fg,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                      validator: Validators.title,
                      onChanged: _onTitleChanged,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _description,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      maxLines: 4,
                      maxLength: Validators.descriptionMax, // shows the counter
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        alignLabelWithHint: true,
                      ),
                      validator: Validators.description,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        for (final c in kTaskCategories)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      validator: (v) =>
                          v == null ? 'Category is required' : null,
                      onChanged: (v) => setState(() {
                        _category = v;
                        _dirty = true;
                      }),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      initialValue: _assigneeId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Assignee (optional)',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Unassigned'),
                        ),
                        for (final m in assignable)
                          DropdownMenuItem<String?>(
                            value: m.id,
                            child: Row(
                              children: [
                                AvatarCircle.member(m, size: 24),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${m.name} · ${m.jobTitle}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        _assigneeId = v;
                        _dirty = true;
                      }),
                    ),
                    if (user != null && !user.isManager)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          'Members can only assign tasks to themselves.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text('Priority', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in Priority.values)
                          ChoiceChip(
                            avatar: Icon(
                              AppColors.priorityIcon(p),
                              size: 18,
                              color: AppColors.priority(p, theme.brightness),
                            ),
                            label: Text(p.label),
                            selected: _priority == p,
                            onSelected: (_) => setState(() {
                              _priority = p;
                              _dirty = true;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<TaskStatus>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: [
                        for (final s in TaskStatus.values)
                          DropdownMenuItem(value: s, child: Text(s.label)),
                      ],
                      onChanged: (v) => setState(() {
                        _status = v ?? _status;
                        _dirty = true;
                      }),
                    ),
                    const SizedBox(height: 16),
                    _DateTimeField(
                      fieldKey: _startKey,
                      label: 'Start date',
                      value: _start,
                      pick: _pickDateTime,
                      validator: (v) => Validators.startDate(v),
                      onChanged: (v) {
                        setState(() {
                          _start = v;
                          _dirty = true;
                        });
                        // Moving the start may make the due date invalid.
                        _dueKey.currentState?.validate();
                      },
                    ),
                    const SizedBox(height: 16),
                    _DateTimeField(
                      fieldKey: _dueKey,
                      label: 'Due date',
                      value: _due,
                      pick: _pickDateTime,
                      validator: (v) => Validators.dueDate(
                        start: _start,
                        due: v,
                        now: now,
                        isNew: !_isEdit,
                      ),
                      onChanged: (v) => setState(() {
                        _due = v;
                        _dirty = true;
                      }),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final q in const [
                          ('In 10 h', Duration(hours: 10)),
                          ('Tomorrow', Duration(days: 1)),
                          ('In 3 days', Duration(days: 3)),
                          ('Next week', Duration(days: 7)),
                        ])
                          ActionChip(
                            label: Text(q.$1),
                            onPressed: () {
                              final due = _truncate(now.add(q.$2));
                              _dueKey.currentState?.didChange(due);
                              setState(() {
                                _due = due;
                                _dirty = true;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('Progress', style: theme.textTheme.labelLarge),
                        const Spacer(),
                        Text(
                          '${hasSubtasks ? item!.task.progress : _progress.round()}%',
                        ),
                      ],
                    ),
                    Slider(
                      value: hasSubtasks
                          ? item!.task.progress.toDouble()
                          : _progress,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: '${_progress.round()}%',
                      // Disabled when subtasks exist: progress comes from them.
                      onChanged: hasSubtasks
                          ? null
                          : (v) => setState(() {
                              _progress = v;
                              _dirty = true;
                            }),
                    ),
                    if (hasSubtasks)
                      Text(
                        'Progress is calculated from this task\'s subtasks.',
                        style: theme.textTheme.bodySmall,
                      ),
                    const SizedBox(height: 16),
                    if (preview != null)
                      _PreviewCard(result: preview, now: now),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(_isEdit ? 'Save changes' : 'Create task'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Live "what SLA would this get?" card.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.result, required this.now});

  final SlaResult result;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final state = result.state;
    final reason = result.reason;
    final c = AppColors.sla(state, Theme.of(context).brightness);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text('This task would be:', style: TextStyle(color: c.fg)),
                SlaChip(state: state),
              ],
            ),
            const SizedBox(height: 6),
            Text(reason, style: TextStyle(color: c.fg)),
          ],
        ),
      ),
    );
  }
}

/// Tap to pick a date then a time; participates in Form validation.
class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.pick,
    required this.validator,
    required this.onChanged,
  });

  final GlobalKey<FormFieldState<DateTime>> fieldKey;
  final String label;
  final DateTime? value;
  final Future<DateTime?> Function(DateTime? current) pick;
  final String? Function(DateTime?) validator;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return FormField<DateTime>(
      key: fieldKey,
      initialValue: value,
      validator: validator,
      builder: (state) {
        final shown = state.value;
        return Semantics(
          button: true,
          label: '$label: ${shown == null ? 'not set' : formatDateTime(shown)}',
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final picked = await pick(shown);
              if (picked != null) {
                state.didChange(picked);
                onChanged(picked);
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                errorText: state.errorText,
                suffixIcon: const Icon(Icons.calendar_today_outlined),
              ),
              child: Text(
                shown == null ? 'Select date and time' : formatDateTime(shown),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        );
      },
    );
  }
}
