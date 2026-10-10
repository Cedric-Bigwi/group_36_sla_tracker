import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/security.dart';
import '../models/activity_entry.dart';
import '../models/enums.dart';
import '../models/project.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../models/team_member.dart';

/// Demo data inserted on first launch (and by "Reset demo data").
///
/// All task dates are RELATIVE to [now], so whenever the app is first opened
/// the demo shows a mix of On Track, At Risk, Overdue and Completed tasks.
abstract final class DemoSeed {
  /// Everyone in the seed uses this PIN (shown as a hint on the sign-in screen).
  static const String demoPin = '1234';

  static const _uuid = Uuid();

  static Future<void> insert(DatabaseExecutor db, DateTime now) async {
    final members = _members(now);
    final manager = members.first;
    final byKey = {for (final m in members) m.email.split('@').first: m};

    final project = Project(
      id: _uuid.v4(),
      name: 'Campus Connect Mobile App',
      description: 'A student life app: events, campus map, notifications.',
      startDate: now.subtract(const Duration(days: 21)),
      endDate: now.add(const Duration(days: 21)),
    );

    final tasks = <Task>[];
    final subtasks = <Subtask>[];
    final activity = <ActivityEntry>[];

    Duration h(num hours) => Duration(minutes: (hours * 60).round());

    void add({
      required String title,
      required String category,
      String? assignee,
      required Priority priority,
      required TaskStatus status,
      required int progress,
      required num startH, // hours relative to now
      required num dueH,
      num? doneH,
      String? description,
      List<String> subs = const [],
      int doneSubs = 0,
    }) {
      final id = _uuid.v4();
      final start = now.add(h(startH));
      // A task cannot have been created in the future.
      final created = start.isAfter(now) ? now : start;
      var prog = progress;
      if (subs.isNotEmpty) prog = (doneSubs * 100 / subs.length).round();
      final completedAt = doneH == null ? null : now.add(h(doneH));
      tasks.add(
        Task(
          id: id,
          projectId: project.id,
          title: title,
          description: description,
          category: category,
          assigneeId: assignee == null ? null : byKey[assignee]!.id,
          createdBy: manager.id,
          priority: priority,
          status: status,
          progress: status == TaskStatus.done ? 100 : prog,
          startDate: start,
          dueDate: now.add(h(dueH)),
          completedAt: completedAt,
          createdAt: created,
          updatedAt: completedAt ?? created,
        ),
      );
      for (var i = 0; i < subs.length; i++) {
        subtasks.add(
          Subtask(
            id: _uuid.v4(),
            taskId: id,
            title: subs[i],
            isDone: i < doneSubs,
            position: i,
          ),
        );
      }
      activity.add(
        ActivityEntry(
          id: _uuid.v4(),
          taskId: id,
          actorId: manager.id,
          type: ActivityType.created,
          detail: 'Task created',
          createdAt: created,
        ),
      );
      if (completedAt != null) {
        activity.add(
          ActivityEntry(
            id: _uuid.v4(),
            taskId: id,
            actorId: assignee == null ? manager.id : byKey[assignee]!.id,
            type: ActivityType.statusChanged,
            detail: 'In Review → Done',
            createdAt: completedAt,
          ),
        );
      }
    }

    const day = 24;

    // ── Completed ──
    add(
      title: 'Design onboarding screens',
      category: 'UI/UX',
      assignee: 'brenda',
      priority: Priority.medium,
      status: TaskStatus.done,
      progress: 100,
      startH: -14 * day,
      dueH: -7 * day,
      doneH: -8 * day, // a day early
      description: 'Three-step welcome flow with illustrations.',
    );
    add(
      title: 'Set up CI pipeline',
      category: 'DevOps',
      assignee: 'chen',
      priority: Priority.high,
      status: TaskStatus.done,
      progress: 100,
      startH: -12 * day,
      dueH: -5 * day,
      doneH: -4 * day, // a day late
    );
    add(
      title: 'Implement login screen',
      category: 'Mobile',
      assignee: 'dina',
      priority: Priority.high,
      status: TaskStatus.done,
      progress: 100,
      startH: -10 * day,
      dueH: -3 * day,
      doneH: -4 * day - 6,
    );
    add(
      title: 'Database schema review',
      category: 'Backend',
      assignee: 'chen',
      priority: Priority.medium,
      status: TaskStatus.done,
      progress: 100,
      startH: -6 * day,
      dueH: -1 * day,
      doneH: -2 * day,
    );

    // ── Overdue ──
    add(
      title: 'Write regression test plan',
      category: 'QA',
      assignee: 'emeka',
      priority: Priority.medium,
      status: TaskStatus.inProgress,
      progress: 50,
      startH: -8 * day,
      dueH: -1 * day,
    );
    add(
      title: 'Accessibility audit',
      category: 'QA',
      assignee: 'emeka',
      priority: Priority.high,
      status: TaskStatus.inReview,
      progress: 90,
      startH: -9 * day,
      dueH: -2 * day,
      description: 'Check contrast, tap targets and screen-reader labels.',
    );

    // ── At risk ──
    add(
      title: 'Write API contract for events',
      category: 'Backend',
      assignee: 'chen',
      priority: Priority.medium,
      status: TaskStatus.inProgress,
      progress: 40,
      startH: -6 * day,
      dueH: 30, // lag rule: ~83% of time used, 40% done
    );
    add(
      title: 'Push notification service',
      category: 'Backend',
      assignee: 'chen',
      priority: Priority.critical,
      status: TaskStatus.inProgress,
      progress: 20,
      startH: -4 * day,
      dueH: 2 * day, // critical: flagged within 72 h
    );
    add(
      title: 'Write user guide',
      category: 'Docs',
      priority: Priority.low,
      status: TaskStatus.todo,
      progress: 0,
      startH: -4 * day,
      dueH: 5 * day, // unassigned, ~44% elapsed
    );
    add(
      title: 'Profile settings screen',
      category: 'Mobile',
      assignee: 'dina',
      priority: Priority.medium,
      status: TaskStatus.todo,
      progress: 0,
      startH: -5 * day,
      dueH: 3 * day,
    );

    // ── On track ──
    add(
      title: 'Event feed UI',
      category: 'UI/UX',
      assignee: 'brenda',
      priority: Priority.high,
      status: TaskStatus.inProgress,
      progress: 0,
      startH: -5 * day,
      dueH: 4 * day,
      subs: ['Card layout', 'Filter chips', 'Empty state'],
      doneSubs: 2,
    );
    add(
      title: 'Campus map integration',
      category: 'Mobile',
      assignee: 'dina',
      priority: Priority.medium,
      status: TaskStatus.todo,
      progress: 0,
      startH: -2 * day,
      dueH: 10 * day,
    );
    add(
      title: 'Dark mode polish',
      category: 'UI/UX',
      assignee: 'brenda',
      priority: Priority.low,
      status: TaskStatus.inProgress,
      progress: 60,
      startH: -2 * day,
      dueH: 12 * day,
    );
    add(
      title: 'Release checklist',
      category: 'Docs',
      assignee: 'ali',
      priority: Priority.medium,
      status: TaskStatus.inProgress,
      progress: 0,
      startH: -1 * day,
      dueH: 14 * day,
      subs: ['Store listing', 'Privacy policy', 'Version bump', 'Smoke test'],
      doneSubs: 1,
    );

    final batch = db.batch();
    for (final m in members) {
      batch.insert('members', m.toMap());
    }
    batch.insert('projects', project.toMap());
    for (final t in tasks) {
      batch.insert('tasks', t.toMap());
    }
    for (final s in subtasks) {
      batch.insert('subtasks', s.toMap());
    }
    for (final a in activity) {
      batch.insert('activity', a.toMap());
    }
    await batch.commit(noResult: true);
  }

  static List<TeamMember> _members(DateTime now) {
    TeamMember make(
      String name,
      String email,
      String title,
      MemberRole role,
      int color,
    ) {
      final id = _uuid.v4();
      return TeamMember(
        id: id,
        name: name,
        email: email,
        jobTitle: title,
        role: role,
        pinHash: hashPin(id, demoPin),
        avatarColor: color,
        createdAt: now.subtract(const Duration(days: 21)),
      );
    }

    // The manager comes first: the seed uses `members.first` as task creator.
    return [
      make(
        'Ali Rashid',
        'ali@ontrack.dev',
        'Project Manager',
        MemberRole.manager,
        0xFF0F766E,
      ),
      make(
        'Phillip',
        'brenda@ontrack.dev',
        'UI/UX Designer',
        MemberRole.member,
        0xFF7C3AED,
      ),
      make(
        'Cedrick',
        'chen@ontrack.dev',
        'Backend Engineer',
        MemberRole.member,
        0xFFEA580C,
      ),
      make(
        'Rico',
        'dina@ontrack.dev',
        'Mobile Developer',
        MemberRole.member,
        0xFF2563EB,
      ),
      make(
        'Emeka Obi',
        'emeka@ontrack.dev',
        'QA Engineer',
        MemberRole.member,
        0xFFDB2777,
      ),
    ];
  }
}
