import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/utils/app_exception.dart';
import '../core/utils/clock.dart';
import '../data/models/enums.dart';
import '../data/models/project.dart';
import '../data/models/subtask.dart';
import '../data/models/task.dart';
import '../data/models/team_member.dart';
import '../data/repositories/project_repository.dart';
import '../data/repositories/task_repository.dart';
import '../domain/permissions.dart';
import '../domain/sla/sla_engine.dart';
import '../domain/sla/sla_result.dart';
import '../domain/stats/task_stats.dart';
import '../domain/task_item.dart';
import 'member_provider.dart';
import 'session_provider.dart';
import 'task_activity.dart';
import 'task_draft.dart';

enum TaskSort {
  dueDate('Due date'),
  priority('Priority'),
  updated('Recently updated'),
  title('Title (A–Z)');

  const TaskSort(this.label);
  final String label;
}

/// Immutable filter state for the task list.
class TaskFilter {
  const TaskFilter({
    this.sla,
    this.assignedToMe = false,
    this.assigneeId,
    this.priority,
    this.category,
    this.status,
    this.query = '',
  });

  final SlaState? sla;
  final bool assignedToMe;
  final String? assigneeId;
  final Priority? priority;
  final String? category;
  final TaskStatus? status;
  final String query;

  bool get isActive =>
      sla != null || assignedToMe || sheetCount > 0 || query.trim().isNotEmpty;

  /// How many filters live in the bottom sheet (shown as a badge).
  int get sheetCount =>
      [assigneeId, priority, category, status].where((e) => e != null).length;

  /// Nullable fields are passed as getters so `copyWith(sla: () => null)` can
  /// clear a value while omitting the argument keeps it.
  TaskFilter copyWith({
    ValueGetter<SlaState?>? sla,
    bool? assignedToMe,
    ValueGetter<String?>? assigneeId,
    ValueGetter<Priority?>? priority,
    ValueGetter<String?>? category,
    ValueGetter<TaskStatus?>? status,
    String? query,
  }) => TaskFilter(
    sla: sla != null ? sla() : this.sla,
    assignedToMe: assignedToMe ?? this.assignedToMe,
    assigneeId: assigneeId != null ? assigneeId() : this.assigneeId,
    priority: priority != null ? priority() : this.priority,
    category: category != null ? category() : this.category,
    status: status != null ? status() : this.status,
    query: query ?? this.query,
  );
}

/// Holds the task list, filter/sort/search state and every task mutation.
///
/// Data flow: UI → this provider → repositories → SQLite. Each mutation checks
/// permissions (never trusting the UI), writes the change + activity entry in
/// one DB transaction, then refreshes the in-memory list.
class TaskProvider extends ChangeNotifier {
  TaskProvider({
    required TaskRepository tasks,
    required ProjectRepository projects,
    required SessionProvider session,
    required MemberProvider members,
    Clock clock = systemClock,
  }) : _tasks = tasks,
       _projects = projects,
       _session = session,
       _members = members,
       _clock = clock,
       _now = clock();

  final TaskRepository _tasks;
  final ProjectRepository _projects;
  final SessionProvider _session;
  final MemberProvider _members;
  final Clock _clock;
  static const _uuid = Uuid();

  // ── UI state ─────────────────────────────────────────────────────────────
  bool isLoading = true;
  String? error;

  /// Bumped whenever task DATA changes (not on filter/sort changes); lets
  /// other widgets know to refresh.
  int revision = 0;

  List<TaskItem> _items = const [];
  List<TaskItem> _visible = const [];
  TaskStats _stats = TaskStats.of(const []);
  Project? _project;
  DateTime _now;

  TaskFilter filter = const TaskFilter();
  TaskSort sort = TaskSort.dueDate;

  /// Instant the SLA states were last evaluated at. UI uses it for relative
  /// text so labels and states always agree.
  DateTime get now => _now;

  /// The live clock (for form validation); unlike [now] it is not frozen at
  /// the last evaluation.
  DateTime get clockNow => _clock();
  List<TaskItem> get items => _items;
  List<TaskItem> get visibleTasks => _visible;
  TaskStats get stats => _stats;
  Map<SlaState, int> get slaCounts => _stats.counts;
  Project? get project => _project;

  TeamMember? get _user => _session.user;

  TaskItem? itemById(String id) {
    for (final i in _items) {
      if (i.task.id == id) return i;
    }
    return null;
  }

  /// Tasks assigned to the signed-in user, soonest due first.
  List<TaskItem> get myItems {
    final id = _user?.id;
    if (id == null) return const [];
    return _items.where((i) => i.task.assigneeId == id).toList()
      ..sort((a, b) => a.task.dueDate.compareTo(b.task.dueDate));
  }

  // ── Loading ──────────────────────────────────────────────────────────────

  /// Loads everything and re-evaluates every SLA at the current time.
  /// [silent] keeps the current data on screen (pull-to-refresh, app resume,
  /// after mutations).
  Future<void> load({bool silent = false}) async {
    if (!silent) {
      isLoading = true;
      error = null;
      notifyListeners();
    }
    try {
      final tasks = await _tasks.getAll();
      final subs = await _tasks.getAllSubtasks();
      _project = await _projects.getDefault();
      _now = _clock();
      _items = [for (final t in tasks) _build(t, subs[t.id] ?? const [])];
      error = null;
    } on AppException catch (e) {
      if (!silent || _items.isEmpty) error = e.message;
    } catch (e, st) {
      debugPrint('Task load failed: $e\n$st');
      if (!silent || _items.isEmpty) error = 'Could not load tasks.';
    }
    isLoading = false;
    revision++;
    _recompute();
    notifyListeners();
  }

  TaskItem _build(Task t, List<Subtask> subs) => TaskItem(
    task: t,
    subtasks: subs,
    sla: evaluate(t, _now, subtasks: subs),
  );

  // ── Filter / sort / search ───────────────────────────────────────────────

  void setQuery(String q) {
    filter = filter.copyWith(query: q);
    _refreshView();
  }

  void setSlaFilter(SlaState? state) {
    filter = filter.copyWith(sla: () => state);
    _refreshView();
  }

  void toggleAssignedToMe() {
    filter = filter.copyWith(assignedToMe: !filter.assignedToMe);
    _refreshView();
  }

  void applySheetFilters({
    String? assigneeId,
    Priority? priority,
    String? category,
    TaskStatus? status,
  }) {
    filter = filter.copyWith(
      assigneeId: () => assigneeId,
      priority: () => priority,
      category: () => category,
      status: () => status,
    );
    _refreshView();
  }

  /// Resets everything and shows only the signed-in user's tasks.
  void showOnlyMine() {
    filter = const TaskFilter(assignedToMe: true);
    _refreshView();
  }

  void clearFilters() {
    filter = const TaskFilter();
    _refreshView();
  }

  void setSort(TaskSort s) {
    sort = s;
    _refreshView();
  }

  void _refreshView() {
    _recompute();
    notifyListeners();
  }

  void _recompute() {
    _stats = TaskStats.of(_items);
    final meId = _user?.id;
    final q = filter.query.trim().toLowerCase();
    bool matches(TaskItem i) {
      final t = i.task;
      if (filter.sla != null && i.sla.state != filter.sla) return false;
      if (filter.assignedToMe && t.assigneeId != meId) return false;
      if (filter.assigneeId != null && t.assigneeId != filter.assigneeId) {
        return false;
      }
      if (filter.priority != null && t.priority != filter.priority) {
        return false;
      }
      if (filter.category != null && t.category != filter.category) {
        return false;
      }
      if (filter.status != null && t.status != filter.status) return false;
      if (q.isNotEmpty) {
        final hay = '${t.title} ${t.description ?? ''} ${t.category}'
            .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }

    _visible = _items.where(matches).toList()..sort(_comparator);
  }

  int Function(TaskItem, TaskItem) get _comparator => switch (sort) {
    // Open work first (soonest due on top), finished work after it, so the
    // default view surfaces what needs doing.
    TaskSort.dueDate => (a, b) {
      final ad = a.task.isDone, bd = b.task.isDone;
      if (ad != bd) return ad ? 1 : -1;
      return a.task.dueDate.compareTo(b.task.dueDate);
    },
    TaskSort.priority => (a, b) {
      final c = b.task.priority.index.compareTo(a.task.priority.index);
      return c != 0 ? c : a.task.dueDate.compareTo(b.task.dueDate);
    },
    TaskSort.updated => (a, b) => b.task.updatedAt.compareTo(a.task.updatedAt),
    TaskSort.title => (a, b) => a.task.title.toLowerCase().compareTo(
      b.task.title.toLowerCase(),
    ),
  };

  // ── Helpers ──────────────────────────────────────────────────────────────

  TeamMember _requireUser() {
    final u = _user;
    if (u == null) throw const AppException('Please sign in first.');
    return u;
  }

  void _require(bool allowed) {
    if (!allowed) throw const AppException(Permissions.denied);
  }

  TaskItem _requireItem(String id) {
    final item = itemById(id);
    if (item == null) throw const AppException('That task no longer exists.');
    return item;
  }

  /// Applies a status change with the rules from the spec:
  ///  * → Done: completedAt = now, progress = 100
  ///  * Done → anything else: completedAt cleared (task is evaluated normally
  ///    again); with subtasks, progress is re-derived from them
  Task _withStatus(Task t, TaskStatus s, DateTime now, List<Subtask> subs) {
    if (s == t.status) return t;
    if (s == TaskStatus.done) {
      return t.copyWith(
        status: s,
        progress: 100,
        completedAt: now,
        updatedAt: now,
      );
    }
    if (t.status == TaskStatus.done) {
      final progress = subs.isEmpty
          ? t.progress
          : (subs.where((x) => x.isDone).length * 100 / subs.length).round();
      return t.copyWith(
        status: s,
        progress: progress,
        clearCompletedAt: true,
        updatedAt: now,
      );
    }
    return t.copyWith(status: s, updatedAt: now);
  }

  /// Persist [updated] + activity, then patch the in-memory list.
  Future<void> _save(Task before, Task updated) async {
    final user = _requireUser();
    final activity = diffActivity(
      before: before,
      after: updated,
      actorId: user.id,
      now: updated.updatedAt,
      nameOf: _members.nameOf,
    );
    await _tasks.update(updated, activity: activity);
    _replace(updated);
  }

  void _replace(Task task) {
    final idx = _items.indexWhere((i) => i.task.id == task.id);
    if (idx < 0) return;
    final copy = [..._items];
    copy[idx] = _build(task, copy[idx].subtasks);
    _items = copy;
    revision++;
    _recompute();
    notifyListeners();
  }

  // ── Create / edit / delete ───────────────────────────────────────────────

  Future<bool> isTitleTaken(String title, {String? excludeId}) async {
    final p = _project ?? await _projects.getDefault();
    if (p == null) return false;
    return _tasks.titleExists(p.id, title, excludeId: excludeId);
  }

  Future<Task> createTask(TaskDraft draft) async {
    final user = _requireUser();
    _require(Permissions.canCreateTask(user));
    _require(Permissions.canAssignTo(user, draft.assigneeId));
    final project = _project ?? await _projects.getDefault();
    if (project == null) throw const AppException('No project exists yet.');

    final now = _clock();
    final done = draft.status == TaskStatus.done;
    final task = Task(
      id: _uuid.v4(),
      projectId: project.id,
      title: draft.title.trim(),
      description: _nullIfBlank(draft.description),
      category: draft.category,
      assigneeId: draft.assigneeId,
      createdBy: user.id,
      priority: draft.priority,
      status: draft.status,
      progress: done ? 100 : draft.progress.clamp(0, 100),
      startDate: draft.startDate,
      dueDate: draft.dueDate,
      completedAt: done ? now : null,
      createdAt: now,
      updatedAt: now,
    );
    await _tasks.insert(
      task,
      activity: [
        makeActivity(
          taskId: task.id,
          actorId: user.id,
          type: ActivityType.created,
          detail: 'Task created',
          now: now,
        ),
      ],
    );
    await load(silent: true);
    return task;
  }

  Future<void> updateTask(String id, TaskDraft draft) async {
    final user = _requireUser();
    final item = _requireItem(id);
    final before = item.task;
    _require(Permissions.canEditTask(user, before));
    if (draft.assigneeId != before.assigneeId) {
      _require(Permissions.canAssignTo(user, draft.assigneeId));
    }
    final now = _clock();
    var updated = before.copyWith(
      title: draft.title.trim(),
      description: draft.description?.trim() ?? '',
      category: draft.category,
      assigneeId: draft.assigneeId,
      clearAssignee: draft.assigneeId == null,
      priority: draft.priority,
      startDate: draft.startDate,
      dueDate: draft.dueDate,
      // With subtasks, progress is derived and the form can't change it.
      progress: item.hasSubtasks
          ? before.progress
          : draft.progress.clamp(0, 100),
      updatedAt: now,
    );
    updated = _withStatus(updated, draft.status, now, item.subtasks);
    await _save(before, updated);
  }

  Future<void> setStatus(String id, TaskStatus status) async {
    final item = _requireItem(id);
    _require(Permissions.canUpdateProgress(_user, item.task));
    final now = _clock();
    await _save(item.task, _withStatus(item.task, status, now, item.subtasks));
  }

  /// Manual progress (only meaningful when the task has no subtasks).
  Future<void> setProgress(String id, int progress) async {
    final item = _requireItem(id);
    _require(Permissions.canUpdateProgress(_user, item.task));
    if (item.hasSubtasks) {
      throw const AppException('Progress is calculated from subtasks.');
    }
    final p = progress.clamp(0, 100);
    if (p == item.task.progress) return;
    await _save(
      item.task,
      item.task.copyWith(progress: p, updatedAt: _clock()),
    );
  }

  /// Optimistic "mark done": the list updates immediately, and is rolled back
  /// if the write fails. Returns the previous task so the UI can offer Undo.
  Future<Task> markDone(String id) async {
    final item = _requireItem(id);
    _require(Permissions.canUpdateProgress(_user, item.task));
    final before = item.task;
    final now = _clock();
    final updated = _withStatus(before, TaskStatus.done, now, item.subtasks);
    _replace(updated); // optimistic
    try {
      await _save(before, updated);
    } catch (e) {
      _replace(before); // rollback
      rethrow;
    }
    return before;
  }

  /// Restores [original] (used by the Undo SnackBar after [markDone]).
  Future<void> restore(Task original) async {
    final item = _requireItem(original.id);
    _require(Permissions.canUpdateProgress(_user, item.task));
    await _save(item.task, original.copyWith(updatedAt: _clock()));
  }

  Future<void> deleteTask(String id) async {
    final user = _requireUser();
    final item = _requireItem(id);
    _require(Permissions.canDeleteTask(user, item.task));
    await _tasks.delete(
      id,
      // taskId must be null: entries pointing at the task cascade-delete with it.
      log: makeActivity(
        actorId: user.id,
        type: ActivityType.deleted,
        detail: 'Deleted "${item.task.title}"',
        now: _clock(),
      ),
    );
    _items = _items.where((i) => i.task.id != id).toList();
    revision++;
    _recompute();
    notifyListeners();
  }

  Future<Task> duplicateTask(String id) async {
    final user = _requireUser();
    final item = _requireItem(id);
    _require(Permissions.canCreateTask(user));
    final src = item.task;
    final now = _clock();
    final window = src.dueDate.difference(src.startDate);
    final keepAssignee = Permissions.canAssignTo(user, src.assigneeId);
    var title = 'Copy of ${src.title}';
    if (title.length > 80) title = title.substring(0, 80);
    final copy = Task(
      id: _uuid.v4(),
      projectId: src.projectId,
      title: title,
      description: src.description,
      category: src.category,
      assigneeId: keepAssignee ? src.assigneeId : null,
      createdBy: user.id,
      priority: src.priority,
      status: TaskStatus.todo,
      progress: 0,
      startDate: now,
      dueDate: now.add(window.inHours < 1 ? const Duration(days: 1) : window),
      createdAt: now,
      updatedAt: now,
    );
    final subs = [
      for (final s in item.subtasks)
        Subtask(
          id: _uuid.v4(),
          taskId: copy.id,
          title: s.title,
          position: s.position,
        ),
    ];
    await _tasks.insert(
      copy,
      subtasks: subs,
      activity: [
        makeActivity(
          taskId: copy.id,
          actorId: user.id,
          type: ActivityType.created,
          detail: 'Duplicated from "${src.title}"',
          now: now,
        ),
      ],
    );
    await load(silent: true);
    return copy;
  }

  /// Auto-saved notes. Patches memory without a full reload so the text field
  /// the user is typing in is never disturbed.
  Future<void> setNotes(String id, String notes) async {
    final user = _requireUser();
    final item = _requireItem(id);
    _require(Permissions.canUpdateProgress(user, item.task));
    if ((item.task.notes ?? '') == notes) return;
    final now = _clock();
    final updated = item.task.copyWith(notes: notes, updatedAt: now);
    await _tasks.update(
      updated,
      activity: [
        makeActivity(
          taskId: id,
          actorId: user.id,
          type: ActivityType.noteAdded,
          detail: 'Notes updated',
          now: now,
        ),
      ],
    );
    _replace(updated);
  }

  // ── Subtasks ─────────────────────────────────────────────────────────────

  Future<void> addSubtask(String taskId, String title) async {
    final item = _requireItem(taskId);
    _require(Permissions.canEditTask(_user, item.task));
    final clean = title.trim();
    if (clean.isEmpty) throw const AppException('Subtask title is required.');
    final position = item.subtasks.isEmpty
        ? 0
        : item.subtasks.map((s) => s.position).reduce((a, b) => a > b ? a : b) +
              1;
    await _tasks.addSubtask(
      Subtask(id: _uuid.v4(), taskId: taskId, title: clean, position: position),
    );
    await load(silent: true);
  }

  Future<void> toggleSubtask(String taskId, Subtask subtask, bool done) async {
    final user = _requireUser();
    final item = _requireItem(taskId);
    _require(Permissions.canUpdateProgress(user, item.task));
    final doneCount =
        item.subtasks.where((s) => s.isDone).length + (done ? 1 : -1);
    final newProgress = (doneCount * 100 / item.subtasks.length).round();
    await _tasks.setSubtaskDone(
      subtask,
      done,
      log: makeActivity(
        taskId: taskId,
        actorId: user.id,
        type: ActivityType.progressChanged,
        detail:
            '${item.task.progress}% → $newProgress% '
            '(${done ? 'completed' : 'reopened'} "${subtask.title}")',
        now: _clock(),
      ),
    );
    await load(silent: true);
  }

  Future<void> deleteSubtask(String taskId, Subtask subtask) async {
    final item = _requireItem(taskId);
    _require(Permissions.canEditTask(_user, item.task));
    await _tasks.deleteSubtask(subtask);
    await load(silent: true);
  }

  Future<void> reorderSubtasks(
    String taskId,
    int oldIndex,
    int newIndex,
  ) async {
    final item = _requireItem(taskId);
    _require(Permissions.canEditTask(_user, item.task));
    final list = [...item.subtasks];
    // ReorderableListView reports newIndex as if the item were still in place.
    if (newIndex > oldIndex) newIndex -= 1;
    list.insert(newIndex, list.removeAt(oldIndex));
    await _tasks.reorderSubtasks([for (final s in list) s.id]);
    await load(silent: true);
  }

  static String? _nullIfBlank(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  /// Preview of the SLA a draft would get, used live in the task form.
  /// Pure and synchronous: it does not touch the database.
  SlaResult preview(TaskDraft d, {List<Subtask> subtasks = const []}) {
    final fake = Task(
      id: 'preview',
      projectId: 'preview',
      title: d.title,
      category: d.category,
      assigneeId: d.assigneeId,
      createdBy: _user?.id ?? '',
      priority: d.priority,
      status: d.status,
      progress: d.progress,
      startDate: d.startDate,
      dueDate: d.dueDate,
      completedAt: d.status == TaskStatus.done ? _clock() : null,
      createdAt: _now,
      updatedAt: _now,
    );
    return evaluate(fake, _clock(), subtasks: subtasks);
  }
}
