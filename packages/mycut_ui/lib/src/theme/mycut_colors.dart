import 'package:flutter/material.dart';

/// MyCut color palette — gold/charcoal dark luxury aesthetic.
///
/// Derived from the Material 3 design tokens provided in the design spec.
/// All colors are for the dark theme only (light theme out of scope for v1).
abstract final class MyCutColors {
  // ── Primary (Gold) ──────────────────────────────
  static const primary = Color(0xFFF2CA50);
  static const primaryContainer = Color(0xFFD4AF37);
  static const onPrimary = Color(0xFF3C2F00);
  static const onPrimaryContainer = Color(0xFF554300);
  static const primaryFixed = Color(0xFFFFE088);
  static const primaryFixedDim = Color(0xFFE9C349);
  static const onPrimaryFixed = Color(0xFF241A00);
  static const onPrimaryFixedVariant = Color(0xFF574500);
  static const inversePrimary = Color(0xFF735C00);

  // ── Secondary (Cool Grey) ──────────────────────
  static const secondary = Color(0xFFC4C7CA);
  static const secondaryContainer = Color(0xFF46494D);
  static const onSecondary = Color(0xFF2D3134);
  static const onSecondaryContainer = Color(0xFFB6B8BC);
  static const secondaryFixed = Color(0xFFE0E2E6);
  static const secondaryFixedDim = Color(0xFFC4C7CA);
  static const onSecondaryFixed = Color(0xFF191C1F);
  static const onSecondaryFixedVariant = Color(0xFF44474A);

  // ── Tertiary (Warm Gold) ───────────────────────
  static const tertiary = Color(0xFFF4C87D);
  static const tertiaryContainer = Color(0xFFD6AD64);
  static const onTertiary = Color(0xFF422D00);
  static const onTertiaryContainer = Color(0xFF5C4000);
  static const tertiaryFixed = Color(0xFFFFDEA8);
  static const tertiaryFixedDim = Color(0xFFEBC075);
  static const onTertiaryFixed = Color(0xFF271900);
  static const onTertiaryFixedVariant = Color(0xFF5E4200);

  // ── Error ──────────────────────────────────────
  static const error = Color(0xFFFFB4AB);
  static const errorContainer = Color(0xFF93000A);
  static const onError = Color(0xFF690005);
  static const onErrorContainer = Color(0xFFFFDAD6);

  // ── Surface (Charcoal/Black) ───────────────────
  static const surface = Color(0xFF131315);
  static const surfaceDim = Color(0xFF131315);
  static const surfaceBright = Color(0xFF39393B);
  static const surfaceContainer = Color(0xFF201F22);
  static const surfaceContainerLow = Color(0xFF1C1B1E);
  static const surfaceContainerLowest = Color(0xFF0E0E10);
  static const surfaceContainerHigh = Color(0xFF2A2A2C);
  static const surfaceContainerHighest = Color(0xFF353437);
  static const surfaceVariant = Color(0xFF353437);
  static const surfaceTint = Color(0xFFE9C349);
  static const onSurface = Color(0xFFE5E1E4);
  static const onSurfaceVariant = Color(0xFFD0C5AF);
  static const inverseSurface = Color(0xFFE5E1E4);
  static const inverseOnSurface = Color(0xFF313032);

  // ── Outline ────────────────────────────────────
  static const outline = Color(0xFF99907C);
  static const outlineVariant = Color(0xFF4D4635);

  // ── Background (alias for surface in M3) ──────
  static const background = Color(0xFF131315);
  static const onBackground = Color(0xFFE5E1E4);

  // ── Gradient sets ──────────────────────────────
  static const goldGradient = LinearGradient(
    colors: [primaryContainer, primary, tertiaryContainer],
  );

  static const ctaGradient = LinearGradient(
    colors: [primaryContainer, primary],
  );
}
