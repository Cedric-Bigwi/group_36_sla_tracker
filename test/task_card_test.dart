import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:group_36_sla_tracker/models/task.dart';
import 'package:group_36_sla_tracker/widgets/task_card.dart';

void main() {
  testWidgets('TaskCard shows title and Overdue chip, and handles taps',
      (tester) async {
    final task = Task(
      id: '1',
      title: 'Fix login',
      team: 'Team Alpha',
      deadline: DateTime.now().subtract(const Duration(days: 1)),
    );
    var tapped = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TaskCard(task: task, onTap: () => tapped = true)),
    ));

    expect(find.text('Fix login'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('To do'), findsOneWidget);

    await tester.tap(find.byType(TaskCard));
    expect(tapped, isTrue);
  });

  testWidgets('SlaChip shows the label for each status', (tester) async {
    for (final s in Sla.values) {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SlaChip(s))));
      expect(find.text(s.label), findsOneWidget);
    }
  });
}