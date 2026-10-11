import 'package:flutter/material.dart';
import '../models/member.dart';
import '../models/task.dart';
import '../services/seed_data.dart';
import '../widgets/task_card.dart';
import 'task_form_screen.dart';

class TaskDetailsScreen extends StatefulWidget {
  final Task task;
  final Member me;
  final List<Member> members;
  final void Function(Task) onSave;
  final void Function(String) onDelete;
  const TaskDetailsScreen(
      {super.key, required this.task, required this.me, required this.members,
      required this.onSave, required this.onDelete});
  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  late Task task = widget.task;

  Future<void> _edit() async {
    final t = await Navigator.push<Task>(
        context,
        MaterialPageRoute(
            builder: (_) => TaskFormScreen(
                me: widget.me, members: widget.members, task: task)));
    if (t != null) {
      widget.onSave(t);
      setState(() => task = t);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      widget.onDelete(task.id);
      if (mounted) Navigator.pop(context);
    }
  }

  // a teammate picks a task from the open pool
  void _claim() {
    setState(() => task.assignee = widget.me.username);
    widget.onSave(task);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Task is now yours 💪')));
  }

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final isOpen = task.assignee == null;
    final canUpdate = me.isCaptain || task.assignee == me.username;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task details'),
        actions: me.isCaptain
            ? [
                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _edit),
                IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
              ]
            : null,
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(task.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: SlaChip(task.sla)),
        const SizedBox(height: 16),
        Text(task.description.isEmpty ? 'No description.' : task.description,
            style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            _row(Icons.person_outline, 'Assignee', displayName(task.assignee)),
            _row(Icons.flag_outlined, 'Priority', task.priority.name.toUpperCase()),
            _row(Icons.schedule, 'Deadline', fmt(task.deadline)),
          ]),
        ),
        const SizedBox(height: 24),
        if (isOpen)
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _claim,
              icon: const Icon(Icons.back_hand_outlined),
              label: const Text('Pick up this task'),
            ),
          )
        else ...[
          const Text('Update status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (canUpdate)
            SegmentedButton<TaskStatus>(
              segments: const [
                ButtonSegment(value: TaskStatus.todo, label: Text('To do')),
                ButtonSegment(value: TaskStatus.inProgress, label: Text('Doing')),
                ButtonSegment(value: TaskStatus.done, label: Text('Done')),
              ],
              selected: {task.status},
              onSelectionChanged: (s) {
                setState(() => task.status = s.first); // SLA recalculates
                widget.onSave(task);
              },
            )
          else
            Text('Only ${displayName(task.assignee)} or the captain can update this.',
                style: TextStyle(color: Colors.grey.shade600)),
        ],
      ]),
    );
  }
}
