import 'package:flutter/material.dart';

/// Brand color palette — matches the revo-maket web app design system.
///
///  Primary navy  = hsl(222, 60%, 16%)  ≈ #101F41
///  Accent amber  = hsl(38,  92%, 50%)  ≈ #F59E0B
class AppColors {
  const AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────────
  /// Dark navy (sidebar-background / primary in web app).
  static const Color primary = Color(0xFF101F41);
  static const Color primaryDark = Color(0xFF0B1630);

  /// Amber accent (web app --accent: 38 92% 50%).
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentDark = Color(0xFFD97706);

  // ── Backgrounds ────────────────────────────────────────────────────────
  /// App-wide light background (white).
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundAlt = Color(0xFFF8FAFC);
  static const Color backgroundDark = Color(0xFF101F41);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1B2D50);

  // ── Text ───────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF101F41);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent = Color(0xFF0D1117);
  static const Color textInverted = Color(0xFFF8FAFC);

  // ── Feedback ───────────────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);

  // ── Splash / login ─────────────────────────────────────────────────────
  /// Native splash and Dart splash screen background — clean white.
  static const Color splashBackground = Color(0xFFFFFFFF);

  /// Subtle border / divider.
  static const Color border = Color(0xFFE5E7EB);
}
