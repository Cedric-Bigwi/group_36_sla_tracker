import 'package:flutter/material.dart';

import '../../data/models/enums.dart';
import '../theme/app_colors.dart';

/// Number that counts up/down smoothly whenever [value] changes.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.suffix = '',
  });

  final int value;
  final TextStyle? style;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    // TweenAnimationBuilder remembers the previous end value, so changes animate
    // from the old number to the new one (and from 0 on first build).
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}$suffix', style: style),
    );
  }
}

/// Tappable summary card for one SLA state (Dashboard).
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.state,
    required this.value,
    this.onTap,
  });

  final SlaState state;
  final int value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.sla(state, theme.brightness);
    return Semantics(
      button: onTap != null,
      label: '${state.label}: $value tasks. Tap to view.',
      excludeSemantics: true,
      child: Material(
        color: c.bg,
        borderRadius: BorderRadius.circular(Spacing.cardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(Spacing.cardRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(AppColors.slaIcon(state), color: c.fg, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.label,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: c.fg,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AnimatedCount(
                  value: value,
                  style: theme.textTheme.displaySmall?.copyWith(color: c.fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
