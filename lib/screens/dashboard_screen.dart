import 'package:flutter/material.dart';
import '../models/task.dart';
import '../widgets/task_card.dart';

class DashboardScreen extends StatelessWidget {
  final String user;
  final List<Task> tasks;
  final void Function(Task) onOpen;
  const DashboardScreen(
      {super.key, required this.user, required this.tasks, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    int count(Sla s) => tasks.where((t) => t.sla == s).length;
    final done = count(Sla.completed);
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;
    final urgent = tasks
        .where((t) => t.sla == Sla.overdue || t.sla == Sla.atRisk)
        .toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));

    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Hello, $user 👋',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF8B5CF6)]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Project progress',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Text('${(progress * 100).round()}%',
              style: const TextStyle(
                  color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              color: Colors.white,
              borderRadius: BorderRadius.circular(8)),
          const SizedBox(height: 8),
          Text('$done of ${tasks.length} tasks completed',
              style: const TextStyle(color: Colors.white70)),
        ]),
      ),
      const SizedBox(height: 16),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: Sla.values
            .map((s) => Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    Icon(s.icon, color: s.color, size: 30),
                    const SizedBox(width: 10),
                    Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${count(s)}',
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          Text(s.label, style: const TextStyle(fontSize: 12)),
                        ]),
                  ]),
                ))
            .toList(),
      ),
      const SizedBox(height: 24),
      const Text('Needs attention',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (urgent.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
              child: Text('Nothing urgent 🎉',
                  style: TextStyle(color: Colors.grey.shade600))),
        )
      else
        ...urgent.take(3).map((t) => TaskCard(task: t, onTap: () => onOpen(t))),
      const SizedBox(height: 80), // space for the FAB
    ]);
  }
}