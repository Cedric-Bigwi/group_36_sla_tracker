import 'package:flutter/material.dart';
import '../models/member.dart';
import '../models/task.dart';

/// Captain-only form: create or edit a task, assign it or post it to the pool.
class TaskFormScreen extends StatefulWidget {
  final Member me;
  final List<Member> members;
  final Task? task;
  const TaskFormScreen(
      {super.key, required this.me, required this.members, this.task});
  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.task?.title);
  late final _desc = TextEditingController(text: widget.task?.description);
  late String? _assignee = widget.task?.assignee;
  late bool _postToPool = widget.task != null && widget.task!.assignee == null;
  late Priority _priority = widget.task?.priority ?? Priority.medium;
  late DateTime? _deadline = widget.task?.deadline;
  String? _dateError;

  Future<void> _pickDeadline() async {
    final date = await showDatePicker(
        context: context,
        initialDate: _deadline ?? DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 3)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_deadline ?? DateTime.now()));
    if (time == null) return;
    setState(() {
      _deadline = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _dateError = null;
    });
  }

  void _submit() {
    final valid = _form.currentState!.validate();
    if (_deadline == null) setState(() => _dateError = 'Please choose a deadline');
    if (!valid || _deadline == null) return;
    Navigator.pop(
        context,
        Task(
          id: widget.task?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
          title: _title.text.trim(),
          description: _desc.text.trim(),
          team: widget.me.team,
          assignee: _postToPool ? null : _assignee, // null = open pool
          priority: _priority,
          status: widget.task?.status ?? TaskStatus.todo,
          deadline: _deadline!,
        ));
  }

  InputDecoration _dec(String label) => InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.task == null ? 'New task' : 'Edit task')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            TextFormField(
              controller: _title,
              decoration: _dec('Title'),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Title is required';
                if (t.length < 3) return 'Use at least 3 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _desc,
              maxLines: 3,
              maxLength: 200,
              decoration: _dec('Description (optional)'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: const Text('Post to team pool'),
              subtitle: const Text('Teammates pick it up themselves'),
              value: _postToPool,
              onChanged: (v) => setState(() => _postToPool = v),
            ),
            if (!_postToPool) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _assignee,
                decoration: _dec('Assign to'),
                items: widget.members
                    .map((m) => DropdownMenuItem(
                        value: m.username,
                        child: Text(m.isCaptain ? '${m.name} (captain)' : m.name)))
                    .toList(),
                onChanged: (v) => setState(() => _assignee = v),
                validator: (v) => v == null ? 'Pick a teammate or post to the pool' : null,
              ),
            ],
            const SizedBox(height: 20),
            const Text('Priority', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<Priority>(
              segments: const [
                ButtonSegment(value: Priority.low, label: Text('Low')),
                ButtonSegment(value: Priority.medium, label: Text('Medium')),
                ButtonSegment(value: Priority.high, label: Text('High')),
              ],
              selected: {_priority},
              onSelectionChanged: (s) => setState(() => _priority = s.first),
            ),
            const SizedBox(height: 20),
            ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              leading: const Icon(Icons.event),
              title: Text(_deadline == null ? 'Choose deadline' : fmt(_deadline!)),
              subtitle: _dateError == null
                  ? null
                  : Text(_dateError!, style: const TextStyle(color: Colors.red)),
              onTap: _pickDeadline,
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: FilledButton(
                  onPressed: _submit,
                  child: Text(widget.task == null ? 'Create task' : 'Save changes')),
            ),
          ]),
        ),
      );
}