import 'package:flutter/material.dart';
import 'app_tokens.dart';

export 'app_tokens.dart';

class AppTheme {
  // ─────────────────────────────────────────────────────────────────────────
  // LEGACY DESIGN CONSTANTS (PRESERVED FOR BACKWARD COMPATIBILITY)
  // ─────────────────────────────────────────────────────────────────────────

  // Brand Core Colors (Milky Glass & Vibrant Orange Design System)
  static const Color primary = Color(0xFFF97316); // Vibrant Orange (#F97316)
  static const Color primaryDark = Color(0xFFEA580C);
  static const Color accent = Color(0xFFFF8811); // Warm Amber Orange
  static const Color primaryColor = Color(0xFFF97316);
  static const Color primaryNavy = Color(0xFFF97316); // Vibrant Orange Brand
  static const Color primaryLight = Color(0x24F97316); // rgba(249, 115, 22, 0.14)
  static const Color primaryGlow = Color(0x59F97316); // rgba(249, 115, 22, 0.35)
  static const Color accentColor = Color(0xFFFF8811);
  static const Color accentHover = Color(0xFFEA580C);

  // Milky Glass Surfaces & Dark Visual Language
  static const Color background = Color(0xFF0F1115); // Dark Canvas (--bg: #0F1115)
  static const Color bgMain = Color(0xFF0F1115);
  static const Color surface = Color(0xFF1E2026); // Milky Glass Card (--glass: #1E2026)
  static const Color surfaceCard = Color(0xFF1E2026);
  static const Color surfaceElevated = Color(0xFF282A32); // (--glass-strong: #282A32)
  static const Color glass = Color(0xB31E2026); // Translucent Glass
  static const Color glassStrong = Color(0xE6282A32);
  static const Color glassSurface = Color(0xC4FFFFFF);
  static const Color glassSurfaceStrong = Color(0xEBFFFFFF);
  static const Color glassSurfaceSubtle = Color(0x80FFFFFF);
  static const Color glassBorder = Color(0x80FFFFFF);
  static const Color glassBorderStrong = Color(0xB3FFFFFF);
  static const Color glassHighlight = Color(0x66FFFFFF);
  static const Color border = Color(0x1AFFFFFF); // Subtle Glass Border (--glass-border)
  static const Color borderSubtle = Color(0x14FFFFFF); // Divider (--separator)
  static const Color borderMedium = Color(0x33FFFFFF);
  static const Color textMain = Color(0xFFF9FAFB); // High Contrast White (--ink)
  static const Color textMuted = Color(0xFF9CA3AF); // Muted Secondary (--ink-secondary)
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF9CA3AF);

  // Semantic Status & Attendance Colors
  static const Color success = Color(0xFF10B981); // Emerald Green (--success)
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color danger = Color(0xFFEF4444); // Coral Red (--danger)
  static const Color info = Color(0xFF38BDF8); // Sky Blue
  static const Color statusPresent = Color(0xFF10B981);
  static const Color statusOk = Color(0xFF10B981);
  static const Color statusAbsent = Color(0xFFEF4444);
  static const Color statusCritical = Color(0xFFEF4444);
  static const Color statusOd = Color(0xFFF97316); // Vibrant Orange OD
  static const Color statusOdAlt = Color(0xFFFB923C); // Warm Orange
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusUncertain = Color(0xFFEAB308);

  // Milky Glass Radii
  static const double radiusCard = 24.0;
  static const double radiusInner = 18.0;
  static const double radiusPill = 100.0;

  // ─────────────────────────────────────────────────────────────────────────
  // THEME ACCESSORS
  // ─────────────────────────────────────────────────────────────────────────

  static AppColors colors(BuildContext context) => AppColors.of(context);
  static AppTypography typography(BuildContext context) => AppTypography.of(context);

  // ─────────────────────────────────────────────────────────────────────────
  // AUTHORITATIVE LIGHT THEME: "CREAM & ESPRESSO"
  // ─────────────────────────────────────────────────────────────────────────

  static ThemeData get lightTheme {
    const c = AppColors.light;
    const t = AppTypography.standard;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppTypography.fontBody,
      scaffoldBackgroundColor: c.background,
      primaryColor: c.primary,
      colorScheme: ColorScheme.light(
        primary: c.primary,
        onPrimary: c.onPrimary,
        secondary: c.accent,
        onSecondary: c.onHero,
        surface: c.surface,
        onSurface: c.textPrimary,
        error: c.error,
        onError: Colors.white,
        outline: c.borderStrong,
        outlineVariant: c.border,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: c.border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: t.titleLarge.copyWith(color: c.textPrimary),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: t.bodyMedium.copyWith(color: c.textMuted),
        labelStyle: t.bodyMedium.copyWith(color: c.textSecondary, fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.medium)),
          borderSide: BorderSide(color: c.focusRing, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.medium)),
          borderSide: BorderSide(color: c.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.medium)),
          borderSide: BorderSide(color: c.error, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.primary.withValues(alpha: 0.35),
          disabledForegroundColor: c.onPrimary.withValues(alpha: 0.6),
          minimumSize: const Size(0, AppSize.primaryButton),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          textStyle: t.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size(0, AppSize.secondaryButton),
          side: BorderSide(color: c.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          textStyle: t.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accentStrong,
          textStyle: t.labelLarge,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
          side: BorderSide(color: c.border, width: 1),
        ),
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: c.primary,
        unselectedItemColor: c.textMuted,
        selectedLabelStyle: t.labelMedium.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: t.labelMedium.copyWith(fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: DividerThemeData(
        color: c.divider,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.hero,
        contentTextStyle: t.bodyMedium.copyWith(color: c.onHero),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
      ),
      textTheme: TextTheme(
        displayLarge: t.display.copyWith(color: c.textPrimary),
        headlineLarge: t.headlineLarge.copyWith(color: c.textPrimary),
        headlineMedium: t.headlineMedium.copyWith(color: c.textPrimary),
        headlineSmall: t.headlineSmall.copyWith(color: c.textPrimary),
        titleLarge: t.titleLarge.copyWith(color: c.textPrimary),
        titleMedium: t.titleMedium.copyWith(color: c.textPrimary),
        bodyLarge: t.bodyLarge.copyWith(color: c.textPrimary),
        bodyMedium: t.bodyMedium.copyWith(color: c.textPrimary),
        bodySmall: t.bodySmall.copyWith(color: c.textSecondary),
        labelLarge: t.labelLarge.copyWith(color: c.textPrimary),
        labelMedium: t.labelMedium.copyWith(color: c.textSecondary),
        labelSmall: t.caption.copyWith(color: c.textMuted),
      ),
      extensions: const [
        AppColors.light,
        AppTypography.standard,
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DARK THEME (PRESERVED IN FULL FOR DUAL COMPATIBILITY)
  // ─────────────────────────────────────────────────────────────────────────

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: danger,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInner),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInner),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusInner)),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusInner)),
          borderSide: BorderSide(color: danger, width: 1.5),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusInner)),
          borderSide: BorderSide(color: danger, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primary.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size(0, 52),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusInner),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(0, 50),
          side: const BorderSide(color: borderMedium),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusInner),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: border, width: 1),
        ),
        elevation: 8,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      extensions: const [
        AppColors.light,
        AppTypography.standard,
      ],
    );
  }
}
