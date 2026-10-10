import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_exception.dart';
import '../models/project.dart';

class ProjectRepository {
  ProjectRepository(this._db);

  final Database _db;

  Future<List<Project>> getAll() => guardDb(() async {
    final rows = await _db.query('projects', orderBy: 'start_date');
    return rows.map(Project.fromMap).toList();
  }, what: 'load projects');

  /// This version of the app has a single project; new tasks go into it.
  Future<Project?> getDefault() async {
    final all = await getAll();
    return all.isEmpty ? null : all.first;
  }
}
