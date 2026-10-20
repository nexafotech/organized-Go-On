import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_tokens.dart';

export 'app_tokens.dart';

class AppTheme {
  // ─────────────────────────────────────────────────────────────────────────
  // LEGACY DESIGN CONSTANTS (PRESERVED FOR BACKWARD COMPATIBILITY)
  // ─────────────────────────────────────────────────────────────────────────

  // Brand Core Colors (Apple Liquid Glass & Obsidian Chromatic Design System)
  static const Color primary = Color(0xFFE4DFEB); // Soft Pearl Lavender (#E4DFEB)
  static const Color primaryDark = Color(0xFFC5BDD3); // Muted Lilac (#C5BDD3)
  static const Color accent = Color(0xFF818CF8); // Electric Sapphire Crystal (#818CF8)
  static const Color primaryColor = Color(0xFFE4DFEB);
  static const Color primaryNavy = Color(0xFFC5BDD3);
  static const Color primaryLight = Color(0x24C5BDD3);
  static const Color primaryGlow = Color(0x40818CF8);
  static const Color accentColor = Color(0xFF818CF8);
  static const Color accentHover = Color(0xFF6366F1);

  // Liquid Glass Surfaces & Deep Obsidian Canvas
  static const Color background = Color(0xFF0D0C13); // Deep Obsidian Abyss (--bg: #0D0C13)
  static const Color bgMain = Color(0xFF0D0C13);
  static const Color surface = Color(0xFF1E1C27); // Frosted Obsidian Glass (--glass: #1E1C27)
  static const Color surfaceCard = Color(0xFF1E1C27);
  static const Color surfaceElevated = Color(0xFF262332); // Raised Smoked Glass (--glass-strong)
  static const Color glass = Color(0xBF22202A); // Translucent Obsidian Glass
  static const Color glassStrong = Color(0xEB282635);
  static const Color glassSurface = Color(0xBF22202A);
  static const Color glassSurfaceStrong = Color(0xEB282635);
  static const Color glassSurfaceSubtle = Color(0x801E1C27);
  static const Color glassBorder = Color(0x33FFFFFF); // Specular Rim Highlight
  static const Color glassBorderStrong = Color(0x59FFFFFF);
  static const Color glassHighlight = Color(0x66FFFFFF); // Specular Arc Glare
  static const Color border = Color(0x2EFFFFFF); // Specular Glass Border
  static const Color borderSubtle = Color(0x1FFFFFFF); // Divider
  static const Color borderMedium = Color(0x40FFFFFF);
  static const Color textMain = Color(0xFFF7F5EE); // Luminous Pearl Cream
  static const Color textMuted = Color(0xFF867D97); // Slate Violet
  static const Color textPrimary = Color(0xFFF7F5EE);
  static const Color textSecondary = Color(0xFFC5BDD3); // Soft Lavender Mist

  // Semantic Status & Attendance Colors (Liquid Glow Jewels)
  static const Color success = Color(0xFF10B981); // Emerald Green Glow
  static const Color warning = Color(0xFFF59E0B); // Amber Glow
  static const Color danger = Color(0xFFF43F5E); // Ruby Rose Glow
  static const Color info = Color(0xFF818CF8); // Sapphire Blue Glow
  static const Color statusPresent = Color(0xFF10B981);
  static const Color statusOk = Color(0xFF10B981);
  static const Color statusAbsent = Color(0xFFF43F5E);
  static const Color statusCritical = Color(0xFFF43F5E);
  static const Color statusOd = Color(0xFF818CF8); // Sapphire OD
  static const Color statusOdAlt = Color(0xFF6366F1);
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusUncertain = Color(0xFFEAB308);

  // Liquid Glass Radii
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
      canvasColor: c.background,
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
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFFF6F1EA),
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
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
    const c = AppColors.dark;
    const t = AppTypography.standard;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppTypography.fontBody,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      primaryColor: c.primary,
      colorScheme: ColorScheme.dark(
        primary: c.primary,
        secondary: c.accent,
        surface: c.surface,
        error: c.error,
        onPrimary: c.onPrimary,
        onSurface: c.textPrimary,
        outline: c.borderStrong,
        outlineVariant: c.border,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: c.border, width: 1.2),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: t.titleLarge.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
        iconTheme: IconThemeData(color: c.textPrimary),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Color(0xFF0D0C13),
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.glassSurfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: t.bodyMedium.copyWith(color: c.textMuted),
        labelStyle: t.bodyMedium.copyWith(color: c.textSecondary, fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInner),
          borderSide: BorderSide(color: c.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInner),
          borderSide: BorderSide(color: c.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(radiusInner)),
          borderSide: BorderSide(color: c.focusRing, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(radiusInner)),
          borderSide: BorderSide(color: c.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(radiusInner)),
          borderSide: BorderSide(color: c.error, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.primary.withValues(alpha: 0.35),
          disabledForegroundColor: c.onPrimary.withValues(alpha: 0.6),
          minimumSize: const Size(0, 52),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusInner),
          ),
          textStyle: t.labelLarge.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          minimumSize: const Size(0, 50),
          side: BorderSide(color: c.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusInner),
          ),
          textStyle: t.labelLarge.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          textStyle: t.labelLarge,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: c.glassBorderStrong, width: 1.2),
        ),
        elevation: 16,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: c.primary,
        unselectedItemColor: c.textMuted,
        selectedLabelStyle: t.labelMedium.copyWith(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: t.labelMedium.copyWith(fontWeight: FontWeight.w500, fontSize: 12),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceElevated,
        contentTextStyle: t.bodyMedium.copyWith(color: c.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
      ),
      dividerTheme: DividerThemeData(
        color: c.divider,
        thickness: 1,
        space: 1,
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
        AppColors.dark,
        AppTypography.standard,
      ],
    );
  }
}
