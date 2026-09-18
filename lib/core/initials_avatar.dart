import 'package:flutter/material.dart';

/// First-letter-of-first-name + first-letter-of-last-name, upper-cased.
/// Shared so every place that shows initials (contact pickers, member
/// lists) formats them the same way.
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

/// A colored circle showing a person's initials — used wherever a real
/// profile photo isn't available (device contacts, mock circle members).
/// Colors rotate through a small palette keyed by [paletteIndex] so a list
/// of avatars reads as visually distinct without needing real photos.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    required this.size,
    this.paletteIndex = 0,
    this.background,
    this.foreground,
  });

  final String name;
  final double size;
  final int paletteIndex;

  /// Override the palette color — used when a status (paid/overdue/etc.)
  /// should drive the avatar color instead of the rotating palette.
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = [
      (scheme.secondaryFixed, scheme.onSecondaryFixed),
      (scheme.primaryFixed, scheme.onPrimaryFixed),
      (scheme.secondaryContainer.withValues(alpha: 0.4), scheme.onSecondaryContainer),
      (scheme.tertiaryContainer.withValues(alpha: 0.4), scheme.onTertiaryContainer),
      (scheme.primaryContainer.withValues(alpha: 0.3), scheme.onPrimaryContainer),
    ];
    final (paletteBg, paletteFg) = palette[paletteIndex % palette.length];

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background ?? paletteBg, shape: BoxShape.circle),
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontSize: size * 0.35,
          fontWeight: FontWeight.bold,
          color: foreground ?? paletteFg,
        ),
      ),
    );
  }
}
