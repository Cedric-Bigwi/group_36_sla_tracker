import 'package:flutter/material.dart';

import '../../core/widgets/chips.dart';
import '../../core/widgets/stat_card.dart';
import '../../data/models/enums.dart';
import '../../domain/sla/sla_engine.dart';

/// Keep in sync with pubspec.yaml `version:`.
const String kAppVersion = '1.0.0 (build 1)';

/// TODO(group): replace with your real group members and their areas.
const List<String> kGroupMembers = [
  'Member 1 — Data layer, migrations, seed',
  'Member 2 — SLA engine, tests, statistics',
  'Member 3 — Auth, session, router, profile',
  'Member 4 — Task list, details, form',
  'Member 5 — Dashboard, team screens, theming',
];

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Every number below comes from SlaConfig, so this text can never drift
    // away from what the engine actually does.
    final pctLag = (SlaConfig.lagMinElapsed * 100).round();
    final pctTol = (SlaConfig.lagTolerance * 100).round();
    final pctTodo = (SlaConfig.notStartedElapsed * 100).round();
    final pctUnassigned = (SlaConfig.unassignedElapsed * 100).round();

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Icon(
                    Icons.track_changes,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('On Track', style: theme.textTheme.titleLarge),
                        Text(
                          'Version $kAppVersion',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'An offline project and SLA task tracker for small software teams. '
                'All data stays on this device.',
              ),
              const SectionHeader(title: 'How SLA states work'),
              const Text(
                'Status is what you set (To Do, In Progress, In Review, Done). '
                'The SLA state is calculated from status, dates and progress every '
                'time you look, so it is never out of date. Rules are checked in this '
                'order and the first match wins:',
              ),
              const SizedBox(height: 12),
              _Rule(
                state: SlaState.completed,
                title: '1. Completed',
                body:
                    'The status is Done. We also record whether it finished after '
                    'the due date.',
              ),
              _Rule(
                state: SlaState.overdue,
                title: '2. Overdue',
                body: 'Not done and the due date has passed.',
              ),
              _Rule(
                state: SlaState.atRisk,
                title: '3. At Risk (any one of)',
                body:
                    '• Deadline is close: less than '
                    '${[
                      for (final p in [Priority.critical, Priority.high, Priority.medium, Priority.low]) '${SlaConfig.riskWindow[p]!.inHours} h for ${p.label}',
                    ].join(', ')}.\n'
                    '• Behind schedule: over $pctLag% of the time has passed and progress '
                    'is more than $pctTol points behind a steady pace.\n'
                    '• Not started: still in To Do after $pctTodo% of the time.\n'
                    '• Nobody assigned after $pctUnassigned% of the time.',
              ),
              _Rule(
                state: SlaState.onTrack,
                title: '4. On Track',
                body: 'Everything else.',
              ),
              const SectionHeader(title: 'Team'),
              for (final m in kGroupMembers)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(m),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.state, required this.title, required this.body});

  final SlaState state;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  SlaChip(state: state),
                ],
              ),
              const SizedBox(height: 8),
              Text(body),
            ],
          ),
        ),
      ),
    );
  }
}
