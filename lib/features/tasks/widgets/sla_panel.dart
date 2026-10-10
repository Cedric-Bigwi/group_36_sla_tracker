import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/enums.dart';
import '../../../domain/sla/sla_result.dart';

/// Colored panel explaining WHY a task has its SLA state, with time remaining
/// and a start → now → due timeline.
class SlaPanel extends StatelessWidget {
  const SlaPanel({
    super.key,
    required this.result,
    required this.start,
    required this.due,
    required this.now,
  });

  final SlaResult result;
  final DateTime start;
  final DateTime due;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.sla(result.state, theme.brightness);

    final String timeText;
    if (result.state == SlaState.completed) {
      timeText = result.completedLate ? 'Finished late' : 'Finished on time';
    } else if (result.timeRemaining.isNegative) {
      timeText = 'Overdue by ${humanizeDuration(result.timeRemaining)}';
    } else {
      timeText = '${humanizeDuration(result.timeRemaining)} remaining';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(Spacing.cardRadius),
      ),
      child: Semantics(
        container: true,
        label: 'SLA ${result.state.label}. ${result.reason} $timeText.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppColors.slaIcon(result.state), color: c.fg, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.state.label,
                    style: theme.textTheme.titleLarge?.copyWith(color: c.fg),
                  ),
                ),
                Flexible(
                  child: Text(
                    timeText,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelLarge?.copyWith(color: c.fg),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              result.reason,
              style: theme.textTheme.bodyMedium?.copyWith(color: c.fg),
            ),
            const SizedBox(height: 16),
            TimelineBar(
              start: start,
              due: due,
              now: now,
              ratio: result.timeElapsedRatio,
              color: c.fg,
            ),
          ],
        ),
      ),
    );
  }
}

/// Start ──●── Due bar. The dot is "now"; it sticks to the end once overdue.
class TimelineBar extends StatelessWidget {
  const TimelineBar({
    super.key,
    required this.start,
    required this.due,
    required this.now,
    required this.ratio,
    required this.color,
  });

  final DateTime start;
  final DateTime due;
  final DateTime now;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(color: color);
    final pos = ratio.clamp(0.0, 1.0);
    return Semantics(
      label: 'Timeline: ${(pos * 100).round()} percent of the time window used',
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: 16,
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: 6,
                      width: w * pos,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 400),
                      left: (w * pos - 8).clamp(0.0, w - 16),
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 3),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Start ${formatShortDate(start)}',
                  style: labelStyle,
                ),
              ),
              Flexible(
                child: Text(
                  'Due ${formatShortDate(due)}',
                  textAlign: TextAlign.end,
                  style: labelStyle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
