/// "Dapo Williams" -> "Dapo W." — for a name that needs to fit a tight
/// space (ring center labels, compact cards) without an ugly ellipsis.
String shortName(String full) {
  final parts = full.trim().split(RegExp(r'\s+'));
  if (parts.length < 2) return full;
  return '${parts.first} ${parts.last[0]}.';
}

/// Just the first word of a name — for casual address ("Send congrats to
/// Dapo").
String firstName(String full) => full.trim().split(RegExp(r'\s+')).first;
