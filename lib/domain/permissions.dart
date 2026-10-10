import '../data/models/enums.dart';
import '../data/models/task.dart';
import '../data/models/team_member.dart';

/// Role-based rules. The UI uses these to hide/disable actions AND providers
/// call the same functions before every mutation, so the UI is never the only
/// line of defense.
abstract final class Permissions {
  static bool canCreateTask(TeamMember? user) => user != null;

  /// Managers: any task. Members: tasks they created or are assigned to.
  static bool canEditTask(TeamMember? user, Task task) =>
      user != null &&
      (user.isManager ||
          task.createdBy == user.id ||
          task.assigneeId == user.id);

  /// Status / progress / notes follow the same rule as editing.
  static bool canUpdateProgress(TeamMember? user, Task task) =>
      canEditTask(user, task);

  /// Managers: any task. Members: only tasks they created themselves.
  static bool canDeleteTask(TeamMember? user, Task task) =>
      user != null && (user.isManager || task.createdBy == user.id);

  /// Managers can assign anyone. Members can only assign to themselves or
  /// leave a task unassigned.
  static bool canAssignTo(TeamMember? user, String? assigneeId) {
    if (user == null) return false;
    if (user.isManager) return true;
    return assigneeId == null || assigneeId == user.id;
  }

  static bool canManageMembers(TeamMember? user) => user?.isManager ?? false;

  /// Managers edit anyone; everyone edits themselves.
  static bool canEditMember(TeamMember? user, TeamMember target) =>
      user != null && (user.isManager || user.id == target.id);

  /// Only managers can create managers.
  static bool canCreateRole(TeamMember? user, MemberRole role) =>
      role == MemberRole.member || (user?.isManager ?? false);

  static const String denied = "You don't have permission to do that.";
}
