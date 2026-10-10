import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_exception.dart';
import '../../core/utils/clock.dart';
import '../models/activity_entry.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import 'activity_repository.dart';

/// All task + subtask persistence. Every write that also logs activity runs in
/// ONE transaction, so the log can never disagree with the data.
class TaskRepository {
  TaskRepository(this._db, {Clock clock = systemClock}) : _clock = clock;

  final Database _db;
  final Clock _clock;

  // ── Reads ────────────────────────────────────────────────────────────────

  Future<List<Task>> getAll() => guardDb(() async {
    final rows = await _db.query('tasks', orderBy: 'due_date');
    return rows.map(Task.fromMap).toList();
  }, what: 'load tasks');

  Future<Task?> getById(String id) => guardDb(() async {
    final rows = await _db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Task.fromMap(rows.first);
  }, what: 'load the task');

  Future<List<Task>> getByAssignee(String memberId) => guardDb(() async {
    final rows = await _db.query(
      'tasks',
      where: 'assignee_id = ?',
      whereArgs: [memberId],
      orderBy: 'due_date',
    );
    return rows.map(Task.fromMap).toList();
  }, what: 'load tasks');

  /// All subtasks grouped by task id, loaded once for the whole list.
  Future<Map<String, List<Subtask>>> getAllSubtasks() => guardDb(() async {
    final rows = await _db.query('subtasks', orderBy: 'position');
    final map = <String, List<Subtask>>{};
    for (final row in rows) {
      final s = Subtask.fromMap(row);
      (map[s.taskId] ??= []).add(s);
    }
    return map;
  }, what: 'load subtasks');

  Future<List<Subtask>> getSubtasks(String taskId) => guardDb(() async {
    final rows = await _db.query(
      'subtasks',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'position',
    );
    return rows.map(Subtask.fromMap).toList();
  }, what: 'load subtasks');

  /// Case-insensitive duplicate check within a project (used as a warning).
  Future<bool> titleExists(
    String projectId,
    String title, {
    String? excludeId,
  }) => guardDb(() async {
    final rows = await _db.query(
      'tasks',
      columns: ['id'],
      where:
          'project_id = ? AND LOWER(title) = ?'
          '${excludeId != null ? ' AND id != ?' : ''}',
      whereArgs: [projectId, title.trim().toLowerCase(), ?excludeId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }, what: 'check the title');

  // ── Writes ───────────────────────────────────────────────────────────────

  Future<void> insert(
    Task task, {
    List<Subtask> subtasks = const [],
    required List<ActivityEntry> activity,
  }) => guardDb(() async {
    await _db.transaction((txn) async {
      await txn.insert('tasks', task.toMap());
      for (final s in subtasks) {
        await txn.insert('subtasks', s.toMap());
      }
      for (final a in activity) {
        await ActivityRepository.insertIn(txn, a);
      }
    });
  }, what: 'create the task');

  Future<void> update(Task task, {List<ActivityEntry> activity = const []}) =>
      guardDb(() async {
        await _db.transaction((txn) async {
          final n = await txn.update(
            'tasks',
            task.toMap(),
            where: 'id = ?',
            whereArgs: [task.id],
          );
          if (n == 0) throw const AppException('That task no longer exists.');
          for (final a in activity) {
            await ActivityRepository.insertIn(txn, a);
          }
        });
      }, what: 'save the task');

  /// Deletes the task (its subtasks and activity cascade). The "deleted" log
  /// entry must have `taskId == null`, otherwise it would cascade away too.
  Future<void> delete(String id, {required ActivityEntry log}) =>
      guardDb(() async {
        await _db.transaction((txn) async {
          await txn.delete('tasks', where: 'id = ?', whereArgs: [id]);
          await ActivityRepository.insertIn(txn, log);
        });
      }, what: 'delete the task');

  // ── Subtasks ─────────────────────────────────────────────────────────────

  Future<void> addSubtask(Subtask subtask) => guardDb(() async {
    await _db.transaction((txn) async {
      await txn.insert('subtasks', subtask.toMap());
      await _syncProgress(txn, subtask.taskId);
    });
  }, what: 'add the subtask');

  Future<void> setSubtaskDone(
    Subtask subtask,
    bool done, {
    ActivityEntry? log,
  }) => guardDb(() async {
    await _db.transaction((txn) async {
      await txn.update(
        'subtasks',
        {'is_done': done ? 1 : 0},
        where: 'id = ?',
        whereArgs: [subtask.id],
      );
      await _syncProgress(txn, subtask.taskId);
      if (log != null) await ActivityRepository.insertIn(txn, log);
    });
  }, what: 'update the subtask');

  Future<void> deleteSubtask(Subtask subtask) => guardDb(() async {
    await _db.transaction((txn) async {
      await txn.delete('subtasks', where: 'id = ?', whereArgs: [subtask.id]);
      await _syncProgress(txn, subtask.taskId);
    });
  }, what: 'delete the subtask');

  /// Persists a new order (index in [orderedIds] becomes the position).
  Future<void> reorderSubtasks(List<String> orderedIds) => guardDb(() async {
    await _db.transaction((txn) async {
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update(
          'subtasks',
          {'position': i},
          where: 'id = ?',
          whereArgs: [orderedIds[i]],
        );
      }
    });
  }, what: 'reorder subtasks');

  /// Keeps `tasks.progress` equal to doneSubtasks / totalSubtasks * 100.
  /// With no subtasks the manual progress value is left alone.
  Future<void> _syncProgress(Transaction txn, String taskId) async {
    final rows = await txn.rawQuery(
      'SELECT COUNT(*) AS total, COALESCE(SUM(is_done), 0) AS done '
      'FROM subtasks WHERE task_id = ?',
      [taskId],
    );
    final total = (rows.first['total'] as int?) ?? 0;
    if (total == 0) return;
    final done = (rows.first['done'] as int?) ?? 0;
    await txn.update(
      'tasks',
      {
        'progress': (done * 100 / total).round(),
        'updated_at': _clock().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }
}
