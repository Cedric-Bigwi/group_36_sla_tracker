import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/seed_data.dart';

class SlaChip extends StatelessWidget {
  final Sla sla;
  const SlaChip(this.sla, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: sla.color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(sla.icon, size: 14, color: sla.color),
          const SizedBox(width: 4),
          Text(sla.label,
              style: TextStyle(
                  color: sla.color, fontWeight: FontWeight.w600, fontSize: 12)),
        ]),
      );
}

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  const TaskCard({super.key, required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final grey = Colors.grey.shade600;
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold))),
              SlaChip(task.sla),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.person_outline, size: 16, color: grey),
              const SizedBox(width: 4),
              Text(displayName(task.assignee),
                  style: TextStyle(
                      color: task.assignee == null ? Colors.indigo : grey,
                      fontWeight: task.assignee == null ? FontWeight.w600 : null)),
              const Spacer(),
              Icon(Icons.schedule, size: 16, color: grey),
              const SizedBox(width: 4),
              Text(fmt(task.deadline), style: TextStyle(color: grey, fontSize: 12)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.flag, size: 16, color: task.priorityColor),
              const SizedBox(width: 4),
              Text(task.priority.name.toUpperCase(),
                  style: TextStyle(fontSize: 11, color: task.priorityColor)),
              const Spacer(),
              Text(task.status.label,
                  style: TextStyle(fontSize: 12, color: grey)),
            ]),
          ]),
        ),
      ),
    );
  }
}