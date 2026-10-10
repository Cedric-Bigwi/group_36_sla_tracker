import 'package:intl/intl.dart';

/// Date/time helpers. Stored values are UTC; every formatter converts to the
/// device's local time zone itself, so callers never have to remember.

final DateFormat _dateFmt = DateFormat('d MMM yyyy');
final DateFormat _shortDateFmt = DateFormat('d MMM');
final DateFormat _dateTimeFmt = DateFormat('d MMM yyyy, HH:mm');
final DateFormat _timeFmt = DateFormat('HH:mm');
final DateFormat _longDateFmt = DateFormat('EEEE, d MMMM');

String formatDate(DateTime d) => _dateFmt.format(d.toLocal());
String formatShortDate(DateTime d) => _shortDateFmt.format(d.toLocal());
String formatDateTime(DateTime d) => _dateTimeFmt.format(d.toLocal());
String formatTime(DateTime d) => _timeFmt.format(d.toLocal());
String formatLongDate(DateTime d) => _longDateFmt.format(d.toLocal());

String greetingFor(DateTime now) {
  final h = now.toLocal().hour;
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

/// Human readable length of a duration, always positive:
/// "less than a minute", "25 min", "18 h", "2 days".
/// Pure Dart on purpose: the SLA engine uses it for its reason text.
String humanizeDuration(Duration d) {
  final abs = d.abs();
  if (abs.inMinutes < 1) return 'less than a minute';
  if (abs.inMinutes < 60) return '${abs.inMinutes} min';
  if (abs.inHours < 24) return '${abs.inHours} h';
  final days = abs.inDays;
  return days == 1 ? '1 day' : '$days days';
}

/// Relative due text for list cards: "in 2 days", "3 days late", "in 5 h".
String relativeDue(DateTime due, DateTime now) {
  final diff = due.difference(now);
  final text = humanizeDuration(diff);
  if (diff.isNegative) return '$text late';
  return 'in $text';
}

/// Section header for the activity feed: Today / Yesterday / date.
String dayLabel(DateTime d, DateTime now) {
  final local = d.toLocal();
  final today = DateTime(
    now.toLocal().year,
    now.toLocal().month,
    now.toLocal().day,
  );
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return _longDateFmt.format(local);
}

/// "5 min ago", "3 h ago", "2 days ago".
String timeAgo(DateTime d, DateTime now) {
  final diff = now.difference(d);
  if (diff.inMinutes < 1) return 'just now';
  return '${humanizeDuration(diff)} ago';
}

/// Local calendar day key used for grouping.
DateTime dateOnly(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}
