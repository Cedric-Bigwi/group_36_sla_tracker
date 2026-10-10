import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_exception.dart';
import '../models/activity_entry.dart';

class ActivityRepository {
  ActivityRepository(this._db);

  final Database _db;

  /// Insert helper that works inside or outside a transaction. Other
  /// repositories call this with their open `Transaction` so a task change and
  /// its activity row are written atomically.
  static Future<void> insertIn(
    DatabaseExecutor executor,
    ActivityEntry entry,
  ) => executor.insert('activity', entry.toMap());

  static const String _joined = '''
    SELECT a.*, m.name AS actor_name, m.avatar_color AS actor_color,
           t.title AS task_title
    FROM activity a
    JOIN members m ON m.id = a.actor_id
    LEFT JOIN tasks t ON t.id = a.task_id
  ''';

  ActivityView _view(Map<String, Object?> row) => ActivityView(
    entry: ActivityEntry.fromMap(row),
    actorName: row['actor_name']! as String,
    actorColor: row['actor_color']! as int,
    taskTitle: row['task_title'] as String?,
  );

  /// Newest first. Optionally limited to one actor and/or a row count.
  Future<List<ActivityView>> list({String? actorId, int? limit}) =>
      guardDb(() async {
        final rows = await _db.rawQuery(
          '$_joined ${actorId != null ? 'WHERE a.actor_id = ?' : ''} '
          'ORDER BY a.created_at DESC ${limit != null ? 'LIMIT $limit' : ''}',
          [?actorId],
        );
        return rows.map(_view).toList();
      }, what: 'load activity');

  Future<List<ActivityView>> forTask(String taskId) => guardDb(() async {
    final rows = await _db.rawQuery(
      '$_joined WHERE a.task_id = ? ORDER BY a.created_at DESC',
      [taskId],
    );
    return rows.map(_view).toList();
  }, what: 'load task history');
}
