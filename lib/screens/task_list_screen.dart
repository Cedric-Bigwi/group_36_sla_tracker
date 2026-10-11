import 'package:flutter/material.dart';
import '../models/member.dart';
import '../models/task.dart';
import '../widgets/task_card.dart';

class TaskListScreen extends StatefulWidget {
  final Member me;
  final List<Task> tasks;
  final void Function(Task) onOpen;
  const TaskListScreen(
      {super.key, required this.me, required this.tasks, required this.onOpen});
  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  Sla? _sla; // null = any SLA status
  int _scope = 0; // 0 all, 1 mine, 2 open pool

  @override
  Widget build(BuildContext context) {
    final shown = widget.tasks.where((t) {
      if (_sla != null && t.sla != _sla) return false;
      if (_scope == 1) return t.assignee == widget.me.username;
      if (_scope == 2) return t.assignee == null;
      return true;
    }).toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));

    return Column(children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Tasks',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold))),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('All')),
            ButtonSegment(value: 1, label: Text('Mine')),
            ButtonSegment(value: 2, label: Text('Open pool')),
          ],
          selected: {_scope},
          onSelectionChanged: (s) => setState(() => _scope = s.first),
        ),
      ),
      SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                  label: const Text('Any status'),
                  selected: _sla == null,
                  onSelected: (_) => setState(() => _sla = null)),
            ),
            ...Sla.values.map((s) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                      label: Text(s.label),
                      selected: _sla == s,
                      onSelected: (_) => setState(() => _sla = s)),
                )),
          ],
        ),
      ),
      Expanded(
        child: shown.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text('No tasks here yet',
                    style: TextStyle(color: Colors.grey.shade600)),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
                itemCount: shown.length,
                itemBuilder: (_, i) =>
                    TaskCard(task: shown[i], onTap: () => widget.onOpen(shown[i])),
              ),
      ),
    ]);
  }
}
