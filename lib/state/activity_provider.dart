import 'package:flutter/foundation.dart';

import '../core/utils/app_exception.dart';
import '../data/models/activity_entry.dart';
import '../data/repositories/activity_repository.dart';
import 'task_provider.dart';

/// Activity feed state. Reloads itself whenever the task list changes, because
/// every task mutation writes an activity row.
class ActivityProvider extends ChangeNotifier {
  ActivityProvider(this._repo, this._tasks) {
    _lastRevision = _tasks.revision;
    _tasks.addListener(_onTasksChanged);
  }

  final ActivityRepository _repo;
  final TaskProvider _tasks;
  late int _lastRevision;

  List<ActivityView> _all = const [];
  bool isLoading = true;
  String? error;

  /// Filter by actor on the Activity screen (null = everyone).
  String? actorFilter;

  List<ActivityView> get all => _all;
  List<ActivityView> get recent => _all.take(5).toList();
  List<ActivityView> get filtered => actorFilter == null
      ? _all
      : _all.where((a) => a.entry.actorId == actorFilter).toList();

  void setActorFilter(String? id) {
    actorFilter = id;
    notifyListeners();
  }

  void _onTasksChanged() {
    if (_tasks.revision == _lastRevision) return;
    _lastRevision = _tasks.revision;
    load(silent: true);
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      isLoading = true;
      error = null;
      notifyListeners();
    }
    try {
      _all = await _repo.list();
      error = null;
    } on AppException catch (e) {
      if (!silent) error = e.message;
    } catch (e) {
      if (!silent) error = 'Could not load activity.';
      debugPrint('Activity load failed: $e');
    }
    isLoading = false;
    notifyListeners();
  }

  Future<List<ActivityView>> forTask(String taskId) => _repo.forTask(taskId);

  @override
  void dispose() {
    _tasks.removeListener(_onTasksChanged);
    super.dispose();
  }
}
