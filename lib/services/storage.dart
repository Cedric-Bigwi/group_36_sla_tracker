import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/member.dart';
import '../models/task.dart';
import 'seed_data.dart';

/// All local persistence lives here (SharedPreferences, tasks saved as JSON).
class Storage {
  static Future<List<Task>> loadTasks() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('tasks_v2');
    if (raw == null) {
      // first launch: fill the app with demo data
      final seed = SeedData.tasks();
      await saveTasks(seed);
      return seed;
    }
    return (jsonDecode(raw) as List).map((e) => Task.fromJson(e)).toList();
  }

  static Future<void> saveTasks(List<Task> tasks) async =>
      (await SharedPreferences.getInstance()).setString(
          'tasks_v2', jsonEncode(tasks.map((t) => t.toJson()).toList()));

  /// The logged-in member (null if nobody is signed in).
  static Future<Member?> getSession() async {
    final u = (await SharedPreferences.getInstance()).getString('session');
    return u == null ? null : SeedData.byUsername(u);
  }

  static Future<void> setSession(String? username) async {
    final p = await SharedPreferences.getInstance();
    username == null ? await p.remove('session') : await p.setString('session', username);
  }
}
