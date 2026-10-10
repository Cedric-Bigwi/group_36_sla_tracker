import 'package:flutter/material.dart';
import '../models/member.dart';
import '../models/task.dart';
import '../services/seed_data.dart';
import '../services/storage.dart';
import 'dashboard_screen.dart';
import 'sign_in_screen.dart';
import 'task_details_screen.dart';
import 'task_form_screen.dart';
import 'task_list_screen.dart';
import 'team_screen.dart';

/// Holds the app state (all tasks) and the bottom navigation.
class HomeShell extends StatefulWidget {
  final Member me;
  const HomeShell({super.key, required this.me});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _loading = true;
  List<Task> _all = [];

  // each team only sees its own tasks
  List<Task> get _tasks => _all.where((t) => t.team == widget.me.team).toList();
  List<Member> get _team => SeedData.teamOf(widget.me.team);

  @override
  void initState() {
    super.initState();
    Storage.loadTasks().then((t) => setState(() {
          _all = t;
          _loading = false;
        }));
  }

  void _save(Task t) {
    setState(() {
      final i = _all.indexWhere((x) => x.id == t.id);
      i < 0 ? _all.add(t) : _all[i] = t;
    });
    Storage.saveTasks(_all);
  }

  void _delete(String id) {
    setState(() => _all.removeWhere((t) => t.id == id));
    Storage.saveTasks(_all);
  }

  void _reset() {
    setState(() => _all = SeedData.tasks());
    Storage.saveTasks(_all);
  }

  Future<void> _create() async {
    final t = await Navigator.push<Task>(
        context,
        MaterialPageRoute(
            builder: (_) => TaskFormScreen(me: widget.me, members: _team)));
    if (t != null) _save(t);
  }

  void _open(Task t) => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TaskDetailsScreen(
                  task: t, me: widget.me, members: _team,
                  onSave: _save, onDelete: _delete)))
      .then((_) => setState(() {}));

  Future<void> _signOut() async {
    await Storage.setSession(null);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const SignInScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(user: widget.me.name, tasks: _tasks, onOpen: _open),
      TaskListScreen(me: widget.me, tasks: _tasks, onOpen: _open),
      TeamScreen(
          me: widget.me, team: _team, tasks: _tasks,
          onSignOut: _signOut, onReset: _reset),
    ];
    return Scaffold(
      body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : pages[_index]),
      // only the captain can create tasks
      floatingActionButton: (_index == 2 || !widget.me.isCaptain)
          ? null
          : FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('New task')),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.group_outlined), label: 'Team'),
        ],
      ),
    );
  }
}