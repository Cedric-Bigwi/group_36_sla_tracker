import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_exception.dart';
import '../models/team_member.dart';

class MemberRepository {
  MemberRepository(this._db);

  final Database _db;

  Future<List<TeamMember>> getAll() => guardDb(() async {
    final rows = await _db.query('members', orderBy: 'name COLLATE NOCASE');
    return rows.map(TeamMember.fromMap).toList();
  }, what: 'load members');

  Future<TeamMember?> getById(String id) => guardDb(() async {
    final rows = await _db.query(
      'members',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : TeamMember.fromMap(rows.first);
  }, what: 'load the member');

  Future<TeamMember?> getByEmail(String email) => guardDb(() async {
    final rows = await _db.query(
      'members',
      where: 'LOWER(email) = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : TeamMember.fromMap(rows.first);
  }, what: 'look up the member');

  Future<void> insert(TeamMember member) => guardDb(
    () => _db.insert('members', member.toMap()),
    what: 'add the member',
  );

  Future<void> update(TeamMember member) => guardDb(
    () => _db.update(
      'members',
      member.toMap(),
      where: 'id = ?',
      whereArgs: [member.id],
    ),
    what: 'save the member',
  );

  /// Removes a member.
  ///
  /// * Their assigned tasks become unassigned automatically
  ///   (`assignee_id ... ON DELETE SET NULL`).
  /// * `tasks.created_by` and `activity.actor_id` are NOT NULL foreign keys,
  ///   so history they authored is handed to [reassignHistoryTo] (the manager
  ///   doing the removal) instead of being lost.
  Future<void> delete(String id, {required String reassignHistoryTo}) =>
      guardDb(() async {
        await _db.transaction((txn) async {
          await txn.update(
            'tasks',
            {'created_by': reassignHistoryTo},
            where: 'created_by = ?',
            whereArgs: [id],
          );
          await txn.update(
            'activity',
            {'actor_id': reassignHistoryTo},
            where: 'actor_id = ?',
            whereArgs: [id],
          );
          await txn.delete('members', where: 'id = ?', whereArgs: [id]);
        });
      }, what: 'remove the member');

  Future<int> managerCount() => guardDb(() async {
    final rows = await _db.rawQuery(
      "SELECT COUNT(*) AS c FROM members WHERE role = 'manager'",
    );
    return (rows.first['c'] as int?) ?? 0;
  }, what: 'count managers');
}
