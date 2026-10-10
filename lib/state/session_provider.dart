import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/app_exception.dart';
import '../core/utils/clock.dart';
import '../core/utils/security.dart';
import '../data/models/team_member.dart';
import '../data/repositories/member_repository.dart';

enum SignInResult { success, wrongPin, locked }

/// Who is signed in. Local demo auth: the session is just a member id kept in
/// SharedPreferences, and PINs are compared by SHA-256 hash.
class SessionProvider extends ChangeNotifier {
  SessionProvider(this._prefs, this._members, {Clock clock = systemClock})
    : _clock = clock;

  static const String sessionKey = 'session_user_id';
  static const int maxAttempts = 5;
  static const Duration lockDuration = Duration(seconds: 30);

  final SharedPreferences _prefs;
  final MemberRepository _members;
  final Clock _clock;

  bool _restored = false;
  TeamMember? _user;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  /// False until the splash screen has finished restoring the session. The
  /// router keeps everyone on /splash until then.
  bool get isRestored => _restored;
  TeamMember? get user => _user;
  bool get isSignedIn => _user != null;
  bool get isManager => _user?.isManager ?? false;

  /// Time left on the brute-force lock (zero when not locked).
  Duration get lockRemaining {
    final until = _lockedUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(_clock());
    return left.isNegative ? Duration.zero : left;
  }

  bool get isLocked => lockRemaining > Duration.zero;

  /// Reads the saved session. A missing, corrupted or stale id (the member was
  /// deleted) falls back to the sign-in screen instead of crashing.
  Future<void> restore() async {
    try {
      final id = _prefs.getString(sessionKey);
      _user = id == null ? null : await _members.getById(id);
      if (id != null && _user == null) await _prefs.remove(sessionKey);
    } catch (e) {
      debugPrint('Session restore failed, falling back to sign-in: $e');
      _user = null;
      try {
        await _prefs.remove(sessionKey);
      } catch (_) {}
    }
    _restored = true;
    notifyListeners();
  }

  /// Checks [pin] for [member]. After [maxAttempts] failures sign-in is locked
  /// for [lockDuration].
  Future<SignInResult> signIn(TeamMember member, String pin) async {
    if (isLocked) return SignInResult.locked;
    if (hashPin(member.id, pin) == member.pinHash) {
      _failedAttempts = 0;
      _lockedUntil = null;
      await startSession(member);
      return SignInResult.success;
    }
    _failedAttempts++;
    if (_failedAttempts >= maxAttempts) {
      _failedAttempts = 0;
      _lockedUntil = _clock().add(lockDuration);
      notifyListeners();
      return SignInResult.locked;
    }
    notifyListeners();
    return SignInResult.wrongPin;
  }

  int get attemptsLeft => maxAttempts - _failedAttempts;

  /// Starts a session without a PIN check (used right after sign-up, and
  /// internally after a successful PIN check).
  Future<void> startSession(TeamMember member) async {
    _user = member;
    await _prefs.setString(sessionKey, member.id);
    notifyListeners();
  }

  Future<void> signOut() async {
    _user = null;
    await _prefs.remove(sessionKey);
    notifyListeners();
  }

  /// Replace the cached user after their profile changed.
  void updateUser(TeamMember member) {
    if (_user?.id == member.id) {
      _user = member;
      notifyListeners();
    }
  }

  bool verifyPin(String pin) {
    final u = _user;
    if (u == null) throw const AppException('Please sign in first.');
    return hashPin(u.id, pin) == u.pinHash;
  }
}
