import 'package:flutter/material.dart';
import '../models/member.dart';
import '../models/task.dart';

class TeamScreen extends StatelessWidget {
  final Member me;
  final List<Member> team;
  final List<Task> tasks;
  final VoidCallback onSignOut;
  final VoidCallback onReset;
  const TeamScreen(
      {super.key, required this.me, required this.team, required this.tasks,
      required this.onSignOut, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final mine = tasks.where((t) => t.assignee == me.username).toList();
    final mineDone = mine.where((t) => t.status == TaskStatus.done).length;
    final openPool = tasks.where((t) => t.assignee == null).length;

    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(me.team,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      Text('$openPool task${openPool == 1 ? '' : 's'} waiting in the open pool',
          style: TextStyle(color: Colors.grey.shade600)),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          CircleAvatar(
              radius: 30,
              child: Text(me.name[0], style: const TextStyle(fontSize: 24))),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(me.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text('@${me.username} · ${me.isCaptain ? 'Captain ★' : 'Member'}',
                  style: TextStyle(color: Colors.grey.shade600)),
              Text('$mineDone of ${mine.length} assigned tasks done',
                  style: TextStyle(color: Colors.grey.shade600)),
            ]),
          ),
          IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: onSignOut),
        ]),
      ),
      const SizedBox(height: 20),
      const Text('Members',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      ...team.map((m) {
        final open = tasks
            .where((t) => t.assignee == m.username && t.status != TaskStatus.done)
            .length;
        return ListTile(
          leading: CircleAvatar(child: Text(m.name[0])),
          title: Text(m.isCaptain ? '${m.name} ★' : m.name),
          subtitle: Text('$open open task${open == 1 ? '' : 's'}'),
          trailing: m.isCaptain ? const Chip(label: Text('Captain')) : null,
        );
      }),
      const SizedBox(height: 12),
      TextButton.icon(
        icon: const Icon(Icons.refresh),
        label: const Text('Reset demo data'),
        onPressed: () {
          onReset();
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Demo data reset')));
        },
      ),
    ]);
  }
}
