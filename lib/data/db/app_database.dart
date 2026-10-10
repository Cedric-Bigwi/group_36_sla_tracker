import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/utils/clock.dart';
import 'seed_data.dart';

/// Owns the SQLite connection: schema, migrations and demo seed.
///
/// Why SQLite and not SharedPreferences? Our data is relational (task →
/// assignee, task → project, activity → task/user) and we need filtering,
/// sorting, counting and joins. SQL does that natively; with key-value
/// storage we would serialize whole lists to JSON and rewrite them on every
/// change.
class AppDatabase {
  AppDatabase._(this.db, this._clock);

  final Database db;
  final Clock _clock;

  static const int schemaVersion = 1;
  static const String fileName = 'on_track.db';

  /// Opens (and on first launch creates + seeds) the database.
  ///
  /// [factory] and [path] are injectable so tests can use an in-memory
  /// `sqflite_common_ffi` database.
  static Future<AppDatabase> open({
    String? path,
    DatabaseFactory? factory,
    Clock clock = systemClock,
    bool seed = true,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final resolved =
        path ?? p.join(await dbFactory.getDatabasesPath(), fileName);
    final db = await dbFactory.openDatabase(
      resolved,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          // SQLite ignores foreign keys unless this is switched on per connection.
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _createSchema(db);
          if (seed) await DemoSeed.insert(db, clock());
        },
        onUpgrade: _onUpgrade,
      ),
    );
    return AppDatabase._(db, clock);
  }

  static Future<void> _createSchema(Database db) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE members (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        job_title TEXT NOT NULL,
        role TEXT NOT NULL,
        pin_hash TEXT NOT NULL,
        avatar_color INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        start_date INTEGER NOT NULL,
        end_date INTEGER
      )''');
    batch.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        assignee_id TEXT REFERENCES members(id) ON DELETE SET NULL,
        created_by TEXT NOT NULL REFERENCES members(id),
        priority TEXT NOT NULL,
        status TEXT NOT NULL,
        progress INTEGER NOT NULL DEFAULT 0 CHECK (progress BETWEEN 0 AND 100),
        start_date INTEGER NOT NULL,
        due_date INTEGER NOT NULL,
        completed_at INTEGER,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE subtasks (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        is_done INTEGER NOT NULL DEFAULT 0,
        position INTEGER NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE activity (
        id TEXT PRIMARY KEY,
        task_id TEXT REFERENCES tasks(id) ON DELETE CASCADE,
        actor_id TEXT NOT NULL REFERENCES members(id),
        type TEXT NOT NULL,
        detail TEXT,
        created_at INTEGER NOT NULL
      )''');
    batch.execute('CREATE INDEX idx_tasks_due ON tasks(due_date)');
    batch.execute('CREATE INDEX idx_tasks_assignee ON tasks(assignee_id)');
    batch.execute('CREATE INDEX idx_activity_task ON activity(task_id)');
    batch.execute('CREATE INDEX idx_subtasks_task ON subtasks(task_id)');
    await batch.commit(noResult: true);
  }

  /// Migration hook. Add one `if (oldVersion < N)` block per schema change so
  /// users upgrading from any older version run every step in order.
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Example for the future:
    // if (oldVersion < 2) await db.execute('ALTER TABLE tasks ADD COLUMN ...');
  }

  /// Wipes every table and inserts the demo data again ("Reset demo data").
  Future<void> resetDemoData() async {
    await db.transaction((txn) async {
      // Children first so foreign keys never block the deletes.
      for (final table in [
        'activity',
        'subtasks',
        'tasks',
        'projects',
        'members',
      ]) {
        await txn.delete(table);
      }
      await DemoSeed.insert(txn, _clock());
    });
  }

  Future<void> close() => db.close();
}
