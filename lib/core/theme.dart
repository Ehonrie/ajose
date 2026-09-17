import 'package:flutter/material.dart';

/// Ajose's design system: a fixed Material 3 color scheme and type scale
/// lifted directly from the product's design mockups (not seed-generated),
/// so screens built against these tokens match the designs pixel-for-pixel
/// rather than approximating them.
class AppTheme {
  AppTheme._();

  // --- Tokens with no Material ColorScheme slot of their own ---
  //
  // The design calls these out separately from `surface`/`background`
  // (which are visually close but distinct): `backgroundWarm` is the page
  // ground, `surfaceCard` is the elevated-card white, `statusOverdue` is a
  // semantic color for a circle round that's past due.
  static const Color backgroundWarm = Color(0xFFFAF8F4);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color statusOverdue = Color(0xFFD32F2F);

  static const String headlineFontFamily = 'Plus Jakarta Sans';
  static const String bodyFontFamily = 'Manrope';

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
    inverseSurface: const Color(0xFF2C322D),
    onInverseSurface: const Color(0xFFECF2EB),
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

  /// Headline/title roles use Plus Jakarta Sans; body/label roles use
  /// Manrope — matching the two-family pairing in the design.
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
  /// Material's named roles, so kept as a standalone style.
  static const TextStyle numericCurrency = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 32,
    height: 38 / 32,
    fontWeight: FontWeight.w700,
  );

  static ThemeData get light {
    final scheme = _lightScheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: backgroundWarm,
      fontFamily: bodyFontFamily,
      textTheme: _textTheme(scheme),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: backgroundWarm,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        titleTextStyle: _textTheme(scheme).titleLarge,
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: _textTheme(scheme).headlineMedium,
        ),
      ),
    );
  }

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006038),
          brightness: Brightness.dark,
        ),
        fontFamily: bodyFontFamily,
        appBarTheme: const AppBarTheme(centerTitle: false),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      );
}
