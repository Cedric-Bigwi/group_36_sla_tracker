import 'package:flutter/material.dart';

import '../../data/models/enums.dart';

/// Our visual identity: deep teal seed + fixed semantic SLA colors.
abstract final class AppColors {
  /// Seed for `ColorScheme.fromSeed` (deep teal).
  static const Color seed = Color(0xFF0F766E);

  /// Avatar palette offered when creating members.
  static const List<int> avatarPalette = [
    0xFF0F766E,
    0xFF7C3AED,
    0xFFEA580C,
    0xFF2563EB,
    0xFFDB2777,
    0xFF4D7C0F,
    0xFF0E7490,
    0xFFB45309,
  ];

  /// Foreground / background pair for an SLA state. Fixed (not derived from the
  /// theme seed) so On Track is always green, At Risk amber, Overdue red and
  /// Completed slate, in both themes, with contrast >= 4.5:1 for text.
  static ({Color fg, Color bg}) sla(SlaState state, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (state) {
      SlaState.onTrack =>
        dark
            ? (fg: const Color(0xFF4ADE80), bg: const Color(0xFF12361F))
            : (fg: const Color(0xFF15803D), bg: const Color(0xFFDCFCE7)),
      SlaState.atRisk =>
        dark
            ? (fg: const Color(0xFFFBBF24), bg: const Color(0xFF3F2E0A))
            : (fg: const Color(0xFF9A5B00), bg: const Color(0xFFFEF3C7)),
      SlaState.overdue =>
        dark
            ? (fg: const Color(0xFFF87171), bg: const Color(0xFF451515))
            : (fg: const Color(0xFFB91C1C), bg: const Color(0xFFFEE2E2)),
      SlaState.completed =>
        dark
            ? (fg: const Color(0xFFCBD5E1), bg: const Color(0xFF2B3544))
            : (fg: const Color(0xFF475569), bg: const Color(0xFFE2E8F0)),
    };
  }

  /// Icons make the state readable without color.
  static IconData slaIcon(SlaState state) => switch (state) {
    SlaState.onTrack => Icons.check_circle_outline,
    SlaState.atRisk => Icons.warning_amber_rounded,
    SlaState.overdue => Icons.alarm,
    SlaState.completed => Icons.done_all,
  };

  static Color priority(Priority p, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (p) {
      Priority.low => dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      Priority.medium =>
        dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
      Priority.high => dark ? const Color(0xFFFB923C) : const Color(0xFFC2410C),
      Priority.critical =>
        dark ? const Color(0xFFF472B6) : const Color(0xFFBE123C),
    };
  }

  static IconData priorityIcon(Priority p) => switch (p) {
    Priority.low => Icons.keyboard_arrow_down,
    Priority.medium => Icons.drag_handle,
    Priority.high => Icons.keyboard_arrow_up,
    Priority.critical => Icons.keyboard_double_arrow_up,
  };
}

/// 4/8-pt spacing scale.
abstract final class Spacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;

  /// Standard screen padding and card radius.
  static const double screen = 16;
  static const double cardRadius = 16;
}

/// Layout breakpoint for the two-column tablet / landscape layout.
const double kWideBreakpoint = 840;
