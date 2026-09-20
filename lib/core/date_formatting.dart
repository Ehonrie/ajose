/// Small hand-rolled date/duration formatters shared across circle screens.
/// No `intl` dependency — these are simple enough not to need one, and it
/// keeps the app's dependency list to what was actually asked for.
library;

const _kMonthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _kWeekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

String formatShortDate(DateTime d) => '${_kMonthAbbrev[d.month - 1]} ${d.day}';

/// "Thursday, Nov 21" — a full weekday-plus-date, for when a date is a
/// headline element rather than a small caption.
String formatWeekdayDate(DateTime d) => '${_kWeekdayNames[d.weekday - 1]}, ${formatShortDate(d)}';

/// "Next Friday" if within a week, otherwise a short date — for a date far
/// enough out that `Next <weekday>` would be ambiguous.
String formatUpcoming(DateTime d) {
  final diff = d.difference(DateTime.now());
  if (diff.inDays < 7) return 'Next ${_kWeekdayNames[d.weekday - 1]}';
  return formatShortDate(d);
}

/// "3 days, 14 hrs" style countdown to a deadline.
String formatCountdown(DateTime deadline) {
  final diff = deadline.difference(DateTime.now());
  if (diff.isNegative) return 'Deadline passed';
  return '${diff.inDays} days, ${diff.inHours % 24} hrs';
}

/// "5 days" / "tomorrow" / "today" — a looser countdown for compact cards
/// that don't need hour precision.
String formatRelativeDays(DateTime date) {
  final diff = date.difference(DateTime.now()).inDays;
  if (diff <= 0) return 'today';
  if (diff == 1) return 'tomorrow';
  return '$diff days';
}

/// "2h ago" / "Yesterday" / "3 days ago" — for a timestamp in the past, as
/// used in an activity feed. Falls back to a short date once it's more
/// than a week old.
String formatRelativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return formatShortDate(time);
}
