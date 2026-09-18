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
