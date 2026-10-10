import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/app_exception.dart';
import '../core/utils/clock.dart';
import '../core/utils/security.dart';
import '../data/models/enums.dart';
import '../data/models/team_member.dart';
import '../data/repositories/member_repository.dart';
import '../domain/permissions.dart';
import 'session_provider.dart';

class MemberProvider extends ChangeNotifier {
  MemberProvider(this._repo, this._session, {Clock clock = systemClock})
    : _clock = clock;

  final MemberRepository _repo;
  final SessionProvider _session;
  final Clock _clock;
  static const _uuid = Uuid();

  List<TeamMember> _members = const [];
  bool isLoading = true;
  String? error;

  /// Wired in main.dart: tasks must reload after a member is removed (their
  /// tasks become unassigned).
  Future<void> Function()? onTasksAffected;

  List<TeamMember> get members => _members;

  TeamMember? byId(String? id) {
    if (id == null) return null;
    for (final m in _members) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Display name that survives deleted assignees.
  String nameOf(String? id) {
    if (id == null) return 'Unassigned';
    return byId(id)?.name ?? 'Former member';
  }

  /// [silent] reloads without flipping to the loading state (after mutations).
  Future<void> load({bool silent = false}) async {
    if (!silent) {
      isLoading = true;
      error = null;
      notifyListeners();
    }
    try {
      _members = await _repo.getAll();
      error = null;
    } on AppException catch (e) {
      if (!silent) error = e.message;
    } catch (e) {
      if (!silent) error = 'Could not load team members.';
      debugPrint('Member load failed: $e');
    }
    isLoading = false;
    notifyListeners();
  }

  /// Creates a member. Works while signed out too (self sign-up), but then
  /// only the plain Member role is allowed.
  Future<TeamMember> create({
    required String name,
    required String email,
    required String jobTitle,
    required MemberRole role,
    required String pin,
  }) async {
    if (!Permissions.canCreateRole(_session.user, role)) {
      throw const AppException('Only managers can create managers.');
    }
    if (await _repo.getByEmail(email) != null) {
      throw const AppException('A member with this email already exists.');
    }
    final id = _uuid.v4();
    final member = TeamMember(
      id: id,
      name: name.trim(),
      email: email.trim().toLowerCase(),
      jobTitle: jobTitle.trim(),
      role: role,
      pinHash: hashPin(id, pin),
      avatarColor: AppColors
          .avatarPalette[_members.length % AppColors.avatarPalette.length],
      createdAt: _clock(),
    );
    await _repo.insert(member);
    await load(silent: true);
    return member;
  }

  Future<void> update(TeamMember updated) async {
    final existing = byId(updated.id) ?? await _repo.getById(updated.id);
    if (existing == null) {
      throw const AppException('That member no longer exists.');
    }
    if (!Permissions.canEditMember(_session.user, existing)) {
      throw const AppException(Permissions.denied);
    }
    if (updated.role != existing.role) {
      if (!Permissions.canManageMembers(_session.user)) {
        throw const AppException('Only managers can change roles.');
      }
      if (existing.isManager && await _repo.managerCount() <= 1) {
        throw const AppException('There must be at least one manager.');
      }
    }
    final other = await _repo.getByEmail(updated.email);
    if (other != null && other.id != updated.id) {
      throw const AppException('A member with this email already exists.');
    }
    await _repo.update(updated);
    _session.updateUser(updated);
    await load(silent: true);
  }

  /// Changes the signed-in user's PIN after checking the old one.
  Future<void> changeOwnPin(String oldPin, String newPin) async {
    final me = _session.user;
    if (me == null) throw const AppException('Please sign in first.');
    if (!_session.verifyPin(oldPin)) {
      throw const AppException('Current PIN is incorrect.');
    }
    await update(me.copyWith(pinHash: hashPin(me.id, newPin)));
  }

  /// Manager-only. Their tasks become unassigned; history is handed to the
  /// manager performing the removal.
  Future<void> remove(TeamMember member) async {
    final me = _session.user;
    if (!Permissions.canManageMembers(me)) {
      throw const AppException(Permissions.denied);
    }
    if (me!.id == member.id) {
      throw const AppException("You can't remove yourself.");
    }
    if (member.isManager && await _repo.managerCount() <= 1) {
      throw const AppException('There must be at least one manager.');
    }
    await _repo.delete(member.id, reassignHistoryTo: me.id);
    await load(silent: true);
    await onTasksAffected?.call();
  }
}
