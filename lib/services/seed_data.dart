import '../models/member.dart';
import '../models/task.dart';

/// Shows a username as a display name; null means the task is in the open pool.
String displayName(String? username) =>
    username == null ? 'Open to pick up' : (SeedData.byUsername(username)?.name ?? username);

/// Demo accounts (password = username + "123") and starter tasks.
class SeedData {
  static const members = <Member>[
    Member(username: 'amara', password: 'amara123', name: 'Amara', team: 'Team Alpha', isCaptain: true),
    Member(username: 'jonas', password: 'jonas123', name: 'Jonas', team: 'Team Alpha'),
    Member(username: 'lina', password: 'lina123', name: 'Lina', team: 'Team Alpha'),
    Member(username: 'kofi', password: 'kofi123', name: 'Kofi', team: 'Team Alpha'),
    Member(username: 'zara', password: 'zara123', name: 'Zara', team: 'Team Alpha'),
    Member(username: 'daniel', password: 'daniel123', name: 'Daniel', team: 'Team Beta', isCaptain: true),
    Member(username: 'mei', password: 'mei123', name: 'Mei', team: 'Team Beta'),
    Member(username: 'omar', password: 'omar123', name: 'Omar', team: 'Team Beta'),
    Member(username: 'sofia', password: 'sofia123', name: 'Sofia', team: 'Team Beta'),
    Member(username: 'priya', password: 'priya123', name: 'Priya', team: 'Team Gamma', isCaptain: true),
    Member(username: 'lucas', password: 'lucas123', name: 'Lucas', team: 'Team Gamma'),
    Member(username: 'fatima', password: 'fatima123', name: 'Fatima', team: 'Team Gamma'),
    Member(username: 'noah', password: 'noah123', name: 'Noah', team: 'Team Gamma'),
    Member(username: 'ella', password: 'ella123', name: 'Ella', team: 'Team Gamma'),
  ];

  static Member? login(String user, String pass) {
    for (final m in members) {
      if (m.username == user.trim().toLowerCase() && m.password == pass) return m;
    }
    return null;
  }

  static Member? byUsername(String u) {
    for (final m in members) {
      if (m.username == u) return m;
    }
    return null;
  }

  static List<Member> teamOf(String team) =>
      members.where((m) => m.team == team).toList();

  /// Deadlines are relative to "now" so every SLA status shows up.
  static List<Task> tasks() {
    final now = DateTime.now();
    var n = 0;
    // pri: 0 low, 1 medium, 2 high | st: 0 todo, 1 in progress, 2 done
    Task t(String team, String title, String? who, int pri, int st, int hours) => Task(
        id: 'seed${n++}', title: title, team: team, assignee: who,
        description: 'Part of the $team sprint plan.',
        priority: Priority.values[pri], status: TaskStatus.values[st],
        deadline: now.add(Duration(hours: hours)));
    const a = 'Team Alpha', b = 'Team Beta', g = 'Team Gamma';
    return [
      t(a, 'Design login screen', 'jonas', 2, 2, -30),
      t(a, 'Set up local storage', 'lina', 1, 1, 20),
      t(a, 'Write API docs', 'kofi', 0, 0, -5),
      t(a, 'Fix sync bug', 'zara', 2, 1, 60),
      t(a, 'Prepare sprint demo', null, 1, 0, 120),
      t(a, 'Review pull requests', null, 0, 0, 30),
      t(a, 'Plan release notes', 'amara', 1, 0, 200),
      t(b, 'Build onboarding flow', 'mei', 1, 2, -48),
      t(b, 'Integrate push notifications', 'omar', 2, 1, 10),
      t(b, 'Create app icon set', 'sofia', 0, 0, -12),
      t(b, 'Write unit tests', null, 1, 0, 90),
      t(b, 'Accessibility audit', null, 2, 0, 40),
      t(b, 'Update project roadmap', 'daniel', 1, 1, 150),
      t(g, 'Draft user research survey', 'fatima', 1, 2, -20),
      t(g, 'Refactor payment module', 'lucas', 2, 1, -3),
      t(g, 'Design dark mode palette', 'ella', 0, 1, 100),
      t(g, 'Set up CI pipeline', 'noah', 1, 0, 35),
      t(g, 'Record demo walkthrough', null, 1, 0, 170),
      t(g, 'Performance profiling', null, 2, 0, 200),
      t(g, 'Weekly stand-up notes', 'priya', 0, 0, 60),
    ];
  }
}
