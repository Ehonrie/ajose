import 'package:flutter/material.dart';

/// Ajose's design system: fixed Material 3 color schemes and a type scale
/// lifted directly from the product's design mockups (not seed-generated),
/// so screens built against these tokens match the designs pixel-for-pixel
/// rather than approximating them.
///
/// Only a light palette was ever specified in the designs. The dark scheme
/// below isn't guessed — it's mechanically derived from the light scheme's
/// own "Fixed" tokens (primaryFixed, primaryFixedDim, onPrimaryFixed,
/// onPrimaryFixedVariant, and the tertiary/secondary equivalents), which
/// Material 3 defines as brightness-invariant for exactly this reason: they
/// double as the dark-scheme's primary/onPrimary/primaryContainer/
/// onPrimaryContainer values. See the tone-mapping comment on [_darkScheme].
class AppTheme {
  AppTheme._();

  static const String headlineFontFamily = 'Plus Jakarta Sans';
  static const String bodyFontFamily = 'Manrope';

  // --- Custom tokens with no Material ColorScheme slot of their own ---
  //
  // The design calls these out separately from `surface`/`background`
  // (which are visually close but distinct in light mode): `backgroundWarm`
  // is the page ground, `surfaceCard` is the elevated-card surface,
  // `statusOverdue` is a semantic color for a circle round that's past due.
  // Exposed via the [AjoseColorScheme] extension below so every call site
  // already holding a `ColorScheme` (which is everywhere in this app) gets
  // the theme-correct value automatically instead of a hardcoded light one.
  static const Color _lightBackgroundWarm = Color(0xFFFAF8F4);
  static const Color _lightSurfaceCard = Color(0xFFFFFFFF);
  static const Color _lightStatusOverdue = Color(0xFFD32F2F);

  // Dark neutral base = the light scheme's own `inverseSurface`/
  // `onInverseSurface` pair — M3 defines those as already being the
  // dark-mode surface/onSurface colors (that's what "inverse" previews),
  // so reusing them keeps the dark neutral hue consistent with the design
  // rather than inventing an unrelated gray.
  static const Color _darkSurfaceBase = Color(0xFF2C322D);
  static const Color _darkOnSurfaceBase = Color(0xFFECF2EB);
  static final Color _darkBackgroundWarm = _darkSurfaceBase;
  static final Color _darkSurfaceCard = _lighten(_darkSurfaceBase, 0.05);
  // M3's standard dark-mode error tone — error hue is effectively
  // standardized across Material baseline themes regardless of brand seed.
  static const Color _darkStatusOverdue = Color(0xFFFFB4AB);

  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  static Color _darken(Color color, double amount) => _lighten(color, -amount);

  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF006038),
    brightness: Brightness.light,
  ).copyWith(
    primary: const Color(0xFF006038),
    onPrimary: const Color(0xFFFFFFFF),
    primaryContainer: const Color(0xFF1F7A4D),
    onPrimaryContainer: const Color(0xFFAEFFCA),
    primaryFixed: const Color(0xFF9EF5BE),
    primaryFixedDim: const Color(0xFF82D8A3),
    onPrimaryFixed: const Color(0xFF002110),
    onPrimaryFixedVariant: const Color(0xFF00522F),
    secondary: const Color(0xFF835400),
    onSecondary: const Color(0xFFFFFFFF),
    secondaryContainer: const Color(0xFFFEB64E),
    onSecondaryContainer: const Color(0xFF714800),
    secondaryFixed: const Color(0xFFFFDDB5),
    secondaryFixedDim: const Color(0xFFFFB956),
    onSecondaryFixed: const Color(0xFF2A1800),
    onSecondaryFixedVariant: const Color(0xFF643F00),
    tertiary: const Color(0xFF8A3942),
    onTertiary: const Color(0xFFFFFFFF),
    tertiaryContainer: const Color(0xFFA85059),
    onTertiaryContainer: const Color(0xFFFFE8E8),
    tertiaryFixed: const Color(0xFFFFDADB),
    tertiaryFixedDim: const Color(0xFFFFB2B7),
    onTertiaryFixed: const Color(0xFF40010E),
    onTertiaryFixedVariant: const Color(0xFF7A2C36),
    error: const Color(0xFFBA1A1A),
    onError: const Color(0xFFFFFFFF),
    errorContainer: const Color(0xFFFFDAD6),
    onErrorContainer: const Color(0xFF93000A),
    surface: const Color(0xFFF5FBF4),
    onSurface: const Color(0xFF171D19),
    onSurfaceVariant: const Color(0xFF3F4941),
    outline: const Color(0xFF6F7A71),
    outlineVariant: const Color(0xFFBEC9BF),
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
    inverseSurface: _darkSurfaceBase,
    onInverseSurface: _darkOnSurfaceBase,
    inversePrimary: const Color(0xFF82D8A3),
    surfaceTint: const Color(0xFF066C41),
    surfaceDim: const Color(0xFFD6DCD5),
    surfaceBright: const Color(0xFFF5FBF4),
    surfaceContainerLowest: const Color(0xFFFFFFFF),
    surfaceContainerLow: const Color(0xFFEFF5EE),
    surfaceContainer: const Color(0xFFE9EFE9),
    surfaceContainerHigh: const Color(0xFFE4EAE3),
    surfaceContainerHighest: const Color(0xFFDEE4DD),
  );

  /// Dark scheme, tone-mapped from the light scheme's own tokens per the
  /// standard M3 light/dark tone-role table (primary: light tone 40 → dark
  /// tone 80, primaryContainer: tone 90 → tone 30, etc). Concretely, for
  /// each hue family: dark.X = light.XFixedDim, dark.onX = light.onXFixed,
  /// dark.XContainer = light.onXFixedVariant, dark.onXContainer =
  /// light.XFixed — because those Fixed tokens already sit at exactly
  /// tones 80/10/30/90, the tones M3 wants for dark mode.
  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF006038),
    brightness: Brightness.dark,
  ).copyWith(
    primary: const Color(0xFF82D8A3), // light.primaryFixedDim
    onPrimary: const Color(0xFF002110), // light.onPrimaryFixed
    primaryContainer: const Color(0xFF00522F), // light.onPrimaryFixedVariant
    onPrimaryContainer: const Color(0xFF9EF5BE), // light.primaryFixed
    primaryFixed: const Color(0xFF9EF5BE),
    primaryFixedDim: const Color(0xFF82D8A3),
    onPrimaryFixed: const Color(0xFF002110),
    onPrimaryFixedVariant: const Color(0xFF00522F),
    secondary: const Color(0xFFFFB956), // light.secondaryFixedDim
    onSecondary: const Color(0xFF2A1800), // light.onSecondaryFixed
    secondaryContainer: const Color(0xFF643F00), // light.onSecondaryFixedVariant
    onSecondaryContainer: const Color(0xFFFFDDB5), // light.secondaryFixed
    secondaryFixed: const Color(0xFFFFDDB5),
    secondaryFixedDim: const Color(0xFFFFB956),
    onSecondaryFixed: const Color(0xFF2A1800),
    onSecondaryFixedVariant: const Color(0xFF643F00),
    tertiary: const Color(0xFFFFB2B7), // light.tertiaryFixedDim
    onTertiary: const Color(0xFF40010E), // light.onTertiaryFixed
    tertiaryContainer: const Color(0xFF7A2C36), // light.onTertiaryFixedVariant
    onTertiaryContainer: const Color(0xFFFFDADB), // light.tertiaryFixed
    tertiaryFixed: const Color(0xFFFFDADB),
    tertiaryFixedDim: const Color(0xFFFFB2B7),
    onTertiaryFixed: const Color(0xFF40010E),
    onTertiaryFixedVariant: const Color(0xFF7A2C36),
    // M3's standard baseline dark error tones — error hue doesn't derive
    // from the brand seed, so there's no equivalent "Fixed" token to reuse.
    error: const Color(0xFFFFB4AB),
    onError: const Color(0xFF690005),
    // These two exactly match M3's baseline dark error tones AND happen to
    // equal light.onErrorContainer / light.errorContainer respectively —
    // the standard light↔dark error swap, confirmed against the given
    // light tokens rather than assumed.
    errorContainer: const Color(0xFF93000A),
    onErrorContainer: const Color(0xFFFFDAD6),
    surface: _darkSurfaceBase,
    onSurface: _darkOnSurfaceBase,
    onSurfaceVariant: _darken(_darkOnSurfaceBase, 0.28),
    outline: _lighten(_darkSurfaceBase, 0.35),
    outlineVariant: _lighten(_darkSurfaceBase, 0.14),
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
    inverseSurface: const Color(0xFFF5FBF4), // light.surface
    onInverseSurface: const Color(0xFF171D19), // light.onSurface
    inversePrimary: const Color(0xFF006038), // light.primary
    surfaceTint: const Color(0xFF82D8A3),
    surfaceDim: _darken(_darkSurfaceBase, 0.05),
    surfaceBright: _lighten(_darkSurfaceBase, 0.10),
    surfaceContainerLowest: _darken(_darkSurfaceBase, 0.07),
    surfaceContainerLow: _lighten(_darkSurfaceBase, 0.02),
    surfaceContainer: _lighten(_darkSurfaceBase, 0.045),
    surfaceContainerHigh: _lighten(_darkSurfaceBase, 0.075),
    surfaceContainerHighest: _lighten(_darkSurfaceBase, 0.11),
  );

  /// Headline/title roles use Plus Jakarta Sans; body/label roles use
  /// Manrope — matching the two-family pairing in the design. Every color
  /// here comes from [scheme], so the same builder produces a correct
  /// light- or dark-mode text theme.
  static TextTheme _textTheme(ColorScheme scheme) => TextTheme(
        displayLarge: TextStyle(
          fontFamily: headlineFontFamily,
          fontSize: 40,
          height: 48 / 40,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        headlineLarge: TextStyle(
          fontFamily: headlineFontFamily,
          fontSize: 26,
          height: 34 / 26,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        headlineMedium: TextStyle(
          fontFamily: headlineFontFamily,
          fontSize: 24,
          height: 32 / 24,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        titleLarge: TextStyle(
          fontFamily: headlineFontFamily,
          fontSize: 20,
          height: 28 / 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        titleMedium: TextStyle(
          fontFamily: headlineFontFamily,
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        bodyLarge: TextStyle(
          fontFamily: bodyFontFamily,
          fontSize: 18,
          height: 28 / 18,
          fontWeight: FontWeight.w400,
          color: scheme.onSurface,
        ),
        bodyMedium: TextStyle(
          fontFamily: bodyFontFamily,
          fontSize: 15,
          height: 22 / 15,
          fontWeight: FontWeight.w400,
          color: scheme.onSurface,
        ),
        bodySmall: TextStyle(
          fontFamily: bodyFontFamily,
          fontSize: 13,
          height: 18 / 13,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
        ),
        labelLarge: TextStyle(
          fontFamily: bodyFontFamily,
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        labelSmall: TextStyle(
          fontFamily: bodyFontFamily,
          fontSize: 11,
          height: 16 / 11,
          fontWeight: FontWeight.w700,
          color: scheme.primary,
        ),
      );

  /// Large numeric balance display (SOL/USDC amounts) — not one of
  /// Material's named roles, so kept as a standalone style. No color set:
  /// every call site supplies one from the active `ColorScheme`.
  static const TextStyle numericCurrency = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 32,
    height: 38 / 32,
    fontWeight: FontWeight.w700,
  );

  static ThemeData get light => _buildTheme(_lightScheme);

  static ThemeData get dark => _buildTheme(_darkScheme);

  static ThemeData _buildTheme(ColorScheme scheme) {
    final textTheme = _textTheme(scheme);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.backgroundWarm,
      fontFamily: bodyFontFamily,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.backgroundWarm,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceCard,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: textTheme.headlineMedium,
        ),
      ),
    );
  }
}

/// Theme-aware access to Ajose's custom tokens (see [AppTheme]'s doc
/// comment). Works from any `ColorScheme` already in scope — which is
/// everywhere in this app — so screens don't need a `BuildContext` just to
/// read `scheme.surfaceCard` instead of `scheme.surface`.
extension AjoseColorScheme on ColorScheme {
  Color get surfaceCard =>
      brightness == Brightness.dark ? AppTheme._darkSurfaceCard : AppTheme._lightSurfaceCard;

  Color get backgroundWarm =>
      brightness == Brightness.dark ? AppTheme._darkBackgroundWarm : AppTheme._lightBackgroundWarm;

  Color get statusOverdue =>
      brightness == Brightness.dark ? AppTheme._darkStatusOverdue : AppTheme._lightStatusOverdue;
}
