import 'package:flutter/material.dart';
import 'package:mycut_ui/src/theme/mycut_colors.dart';

/// MyCut Material 3 theme — dark mode, gold/charcoal luxury aesthetic.
///
/// Usage:
/// ```dart
/// MaterialApp(
///   theme: MyCutTheme.dark,
/// )
/// ```
abstract final class MyCutTheme {
  /// The dark theme for MyCut apps.
  ///
  /// Both customer and receiver apps use this. The receiver may
  /// override textTheme for larger minimum font sizes.
  static ThemeData get dark {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: MyCutColors.primary,
      onPrimary: MyCutColors.onPrimary,
      primaryContainer: MyCutColors.primaryContainer,
      onPrimaryContainer: MyCutColors.onPrimaryContainer,
      secondary: MyCutColors.secondary,
      onSecondary: MyCutColors.onSecondary,
      secondaryContainer: MyCutColors.secondaryContainer,
      onSecondaryContainer: MyCutColors.onSecondaryContainer,
      tertiary: MyCutColors.tertiary,
      onTertiary: MyCutColors.onTertiary,
      tertiaryContainer: MyCutColors.tertiaryContainer,
      onTertiaryContainer: MyCutColors.onTertiaryContainer,
      error: MyCutColors.error,
      onError: MyCutColors.onError,
      errorContainer: MyCutColors.errorContainer,
      onErrorContainer: MyCutColors.onErrorContainer,
      surface: MyCutColors.surface,
      onSurface: MyCutColors.onSurface,
      surfaceContainerHighest: MyCutColors.surfaceContainerHighest,
      onSurfaceVariant: MyCutColors.onSurfaceVariant,
      outline: MyCutColors.outline,
      outlineVariant: MyCutColors.outlineVariant,
      inverseSurface: MyCutColors.inverseSurface,
      onInverseSurface: MyCutColors.inverseOnSurface,
      inversePrimary: MyCutColors.inversePrimary,
      surfaceTint: MyCutColors.surfaceTint,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: MyCutColors.surface,
      fontFamily: 'Plus Jakarta Sans',
      textTheme: _textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: MyCutColors.surfaceContainerLowest.withAlpha(217),
        foregroundColor: MyCutColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: MyCutColors.surfaceContainerLowest.withAlpha(217),
        indicatorColor: MyCutColors.primaryContainer,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: MyCutColors.secondary,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: MyCutColors.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MyCutColors.primary,
          foregroundColor: MyCutColors.onPrimary,
          minimumSize: const Size(64, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.01,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: MyCutColors.surfaceContainerHigh,
        labelStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.96,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: MyCutColors.surfaceVariant,
        thickness: 1,
      ),
    );
  }

  /// Theme variant for the Receiver app: enforces larger minimum
  /// text sizes (24pt body) for readability from 1.5m away.
  static ThemeData get receiver {
    return dark.copyWith(
      textTheme: _receiverTextTheme,
    );
  }

  // ── Private text theme definitions ────────────────────────────

  static const _textTheme = TextTheme(
    // Syne headlines
    displayLarge: TextStyle(
      fontFamily: 'Syne',
      fontSize: 56,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.68,
      height: 64 / 56,
    ),
    displayMedium: TextStyle(
      fontFamily: 'Syne',
      fontSize: 38,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.76,
      height: 44 / 38,
    ),
    displaySmall: TextStyle(
      fontFamily: 'Syne',
      fontSize: 30,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      height: 36 / 30,
    ),
    headlineLarge: TextStyle(
      fontFamily: 'Syne',
      fontSize: 32,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.32,
      height: 40 / 32,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Syne',
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 28 / 22,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'Syne',
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.24,
      height: 30 / 24,
    ),
    // Plus Jakarta Sans body/title/label
    titleLarge: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 28 / 22,
    ),
    titleMedium: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.18,
      height: 24 / 18,
    ),
    titleSmall: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.14,
      height: 20 / 14,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 26 / 16,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.14,
      height: 22 / 14,
    ),
    bodySmall: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.48,
      height: 16 / 12,
    ),
    labelLarge: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.14,
      height: 20 / 14,
    ),
    labelMedium: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.96,
      height: 16 / 12,
    ),
    labelSmall: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      height: 14 / 10,
    ),
  );

  /// Receiver text theme: minimum 24pt body for barber readability.
  static const _receiverTextTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'Syne',
      fontSize: 64,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.92,
      height: 72 / 64,
    ),
    displayMedium: TextStyle(
      fontFamily: 'Syne',
      fontSize: 48,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.96,
      height: 56 / 48,
    ),
    displaySmall: TextStyle(
      fontFamily: 'Syne',
      fontSize: 36,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.72,
      height: 44 / 36,
    ),
    headlineLarge: TextStyle(
      fontFamily: 'Syne',
      fontSize: 40,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
      height: 48 / 40,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Syne',
      fontSize: 32,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 40 / 32,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'Syne',
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.28,
      height: 36 / 28,
    ),
    titleLarge: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 36 / 28,
    ),
    titleMedium: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.24,
      height: 32 / 24,
    ),
    titleSmall: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      height: 28 / 20,
    ),
    // Minimum 24pt body for barber readability at 1.5m
    bodyLarge: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 28,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 38 / 28,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 24,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.24,
      height: 34 / 24,
    ),
    bodySmall: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 20,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.8,
      height: 28 / 20,
    ),
    labelLarge: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      height: 28 / 20,
    ),
    labelMedium: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.28,
      height: 24 / 16,
    ),
    labelSmall: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 14,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.68,
      height: 20 / 14,
    ),
  );
}
