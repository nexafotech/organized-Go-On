import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. STATUS STYLE DATA CONTAINER
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class AppStatusStyle {
  final Color fg;
  final Color bg;
  final IconData icon;
  final String label;

  const AppStatusStyle({
    required this.fg,
    required this.bg,
    required this.icon,
    required this.label,
  });

  AppStatusStyle copyWith({
    Color? fg,
    Color? bg,
    IconData? icon,
    String? label,
  }) {
    return AppStatusStyle(
      fg: fg ?? this.fg,
      bg: bg ?? this.bg,
      icon: icon ?? this.icon,
      label: label ?? this.label,
    );
  }

  static AppStatusStyle lerp(AppStatusStyle a, AppStatusStyle b, double t) {
    return AppStatusStyle(
      fg: Color.lerp(a.fg, b.fg, t) ?? a.fg,
      bg: Color.lerp(a.bg, b.bg, t) ?? a.bg,
      icon: t < 0.5 ? a.icon : b.icon,
      label: t < 0.5 ? a.label : b.label,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. COLOR TOKENS (CREAM & ESPRESSO)
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class AppColors extends ThemeExtension<AppColors> {
  // Surfaces & Text
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceMuted;
  final Color surfaceTint;
  final Color hero;
  final Color heroRaised;
  final Color heroGradientEnd;
  final Color onHero;
  final Color onHeroSecondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color borderStrong;
  final Color divider;
  final Color scrim;

  // Brand
  final Color primary;
  final Color primaryPressed;
  final Color onPrimary;
  final Color accent;
  final Color accentStrong;
  final Color accentOnHero;
  final Color focusRing;

  // Attendance & Status (Foregrounds)
  final Color present;
  final Color presentBg;
  final Color absent;
  final Color absentBg;
  final Color od;
  final Color odBg;
  final Color notEntered;
  final Color notEnteredBg;
  final Color excluded;
  final Color excludedBg;
  final Color breakColor;
  final Color breakBg;
  final Color lunch;
  final Color lunchBg;

  // Semantic Status
  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color error;
  final Color errorBg;
  final Color info;
  final Color infoBg;

  // Additional Specific Tokens
  final Color heroChip;
  final Color rateHigh;
  final Color rateMedium;
  final Color rateLow;

  // Glassmorphism Tokens
  final Color glassSurface;
  final Color glassSurfaceStrong;
  final Color glassSurfaceSubtle;
  final Color glassSurfaceHero;
  final Color glassBorder;
  final Color glassBorderStrong;
  final Color glassHighlight;
  final Color glassScrim;
  final Color glassTint;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.surfaceTint,
    required this.hero,
    required this.heroRaised,
    required this.heroGradientEnd,
    required this.onHero,
    required this.onHeroSecondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.borderStrong,
    required this.divider,
    required this.scrim,
    required this.primary,
    required this.primaryPressed,
    required this.onPrimary,
    required this.accent,
    required this.accentStrong,
    required this.accentOnHero,
    required this.focusRing,
    required this.present,
    required this.presentBg,
    required this.absent,
    required this.absentBg,
    required this.od,
    required this.odBg,
    required this.notEntered,
    required this.notEnteredBg,
    required this.excluded,
    required this.excludedBg,
    required this.breakColor,
    required this.breakBg,
    required this.lunch,
    required this.lunchBg,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.error,
    required this.errorBg,
    required this.info,
    required this.infoBg,
    required this.heroChip,
    required this.rateHigh,
    required this.rateMedium,
    required this.rateLow,
    this.glassSurface = const Color(0xC4FFFFFF),
    this.glassSurfaceStrong = const Color(0xEBFFFFFF),
    this.glassSurfaceSubtle = const Color(0x80FFFFFF),
    this.glassSurfaceHero = const Color(0xE62B1A13),
    this.glassBorder = const Color(0x80FFFFFF),
    this.glassBorderStrong = const Color(0xB3FFFFFF),
    this.glassHighlight = const Color(0x66FFFFFF),
    this.glassScrim = const Color(0x332B1A13),
    this.glassTint = const Color(0x1AF6F1EA),
  });

  /// Quick check for dark mode based on background luminance
  bool get isDark => background.computeLuminance() < 0.2;

  /// Authoritative Light "Cream & Espresso" Token Palette
  static const AppColors light = AppColors(
    background: Color(0xFFF6F1EA),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1EAE1),
    surfaceTint: Color(0xFFF3E9E4),
    hero: Color(0xFF2B1A13),
    heroRaised: Color(0xFF3A2419),
    heroGradientEnd: Color(0xFF4A2E20),
    onHero: Color(0xFFFFF8F0),
    onHeroSecondary: Color(0xFFD9C7B8),
    textPrimary: Color(0xFF22150F),
    textSecondary: Color(0xFF6B5B50),
    textMuted: Color(0xFF75665A),
    border: Color(0xFFE6DCD0),
    borderStrong: Color(0xFF9A8B7F),
    divider: Color(0xFFEFE7DD),
    scrim: Color(0x7A1A0F0A), // #1A0F0A @ 48%
    primary: Color(0xFF2B1A13),
    primaryPressed: Color(0xFF1A0F0A),
    onPrimary: Color(0xFFFFF8F0),
    accent: Color(0xFFB87B4B),
    accentStrong: Color(0xFF8A5530),
    accentOnHero: Color(0xFFE0A878),
    focusRing: Color(0xFFB87B4B),
    present: Color(0xFF0B7A55), // Forest / Emerald Green (#0B7A55)
    presentBg: Color(0xFFDDF3E8), // Soft emerald background tint
    absent: Color(0xFFB42318), // Crimson Red (#B42318)
    absentBg: Color(0xFFFEECEB), // Soft crimson peach tint
    od: Color(0xFF3D4FB8), // Royal Indigo (#3D4FB8)
    odBg: Color(0xFFEEF0FA), // Soft indigo denim tint
    notEntered: Color(0xFF6B5B50),
    notEnteredBg: Color(0xFFEFE7DD),
    excluded: Color(0xFF6B5B50),
    excludedBg: Color(0xFFEFE7DD),
    breakColor: Color(0xFF7A5A12),
    breakBg: Color(0xFFF3E6C8),
    lunch: Color(0xFF44546A),
    lunchBg: Color(0xFFE4E8EE),
    success: Color(0xFF0B7A55),
    successBg: Color(0xFFDDF3E8),
    warning: Color(0xFF8A5A00),
    warningBg: Color(0xFFFDF0D2),
    error: Color(0xFFB42318),
    errorBg: Color(0xFFFBE4E1),
    info: Color(0xFF3D4FB8),
    infoBg: Color(0xFFE4E8FA),
    heroChip: Color(0x24FFFFFF), // #FFFFFF @ 14%
    rateHigh: Color(0xFF10B981), // >= 75%
    rateMedium: Color(0xFFF59E0B), // 65% - 74.9%
    rateLow: Color(0xFFEF4444), // < 65%
    glassSurface: Color(0xF5FFFFFF), // Crisp ~96% opaque white surface
    glassSurfaceStrong: Color(0xFFFFFFFF), // Pure crisp card white
    glassSurfaceSubtle: Color(0xFFF4ECE2), // Warm muted cream container surface
    glassSurfaceHero: Color(0xE62B1A13), // ~90% translucent espresso
    glassBorder: Color(0xFFE6DCD0), // Crisp warm espresso hairline border
    glassBorderStrong: Color(0xFFD5C8B8), // Defined tactile contour border
    glassHighlight: Color(0x33FFFFFF), // Subtle specular sheen
    glassScrim: Color(0x332B1A13), // ~20% warm espresso scrim
    glassTint: Color(0x1AF6F1EA), // ~10% warm cream tint
  );

  /// Authoritative Liquid Glass Dark Token Palette (Petal Chart & Apple visionOS aesthetic)
  static const AppColors dark = AppColors(
    background: Color(0xFF0D0C13), // Deep obsidian abyss
    surface: Color(0xFF1E1C27),    // Translucent obsidian glass card (~85%)
    surfaceElevated: Color(0xFF262332), // Raised smoked obsidian glass
    surfaceMuted: Color(0xFF161420),    // Muted obsidian
    surfaceTint: Color(0xFF2A2738),
    hero: Color(0xFF22202A),       // Smoked obsidian hero card
    heroRaised: Color(0xFF2E2A3C),
    heroGradientEnd: Color(0xFF14131A),
    onHero: Color(0xFFF7F5EE),     // Luminous pearl cream
    onHeroSecondary: Color(0xFFC5BDD3), // Soft lavender mist
    textPrimary: Color(0xFFF7F5EE),     // Luminous pearl cream (ultra clear)
    textSecondary: Color(0xFFC5BDD3),   // Muted lilac / soft lavender mist
    textMuted: Color(0xFF867D97),       // Slate violet
    border: Color(0x1F7E7594),          // Restrained soft obsidian border (~12%)
    borderStrong: Color(0x33A89EC0),    // Restrained edge highlight (~20%)
    divider: Color(0x1FFFFFFF),         // Subtle glass divider (~12%)
    scrim: Color(0xB30D0C13),           // Smoked scrim
    primary: Color(0xFFE4DFEB),         // Soft pearl lavender / luminous cream
    primaryPressed: Color(0xFF867D97),
    onPrimary: Color(0xFF161420),       // Deep obsidian text on pearl buttons
    accent: Color(0xFF818CF8),          // Sapphire crystal / electric indigo
    accentStrong: Color(0xFF6366F1),
    accentOnHero: Color(0xFFE4DFEB),
    focusRing: Color(0xFFC5BDD3),
    present: Color(0xFF10B981),         // Emerald liquid glow
    presentBg: Color(0x1A10B981),       // Restrained emerald jewel (~10%)
    absent: Color(0xFFF43F5E),          // Ruby rose liquid glow
    absentBg: Color(0x1AF43F5E),        // Restrained ruby jewel (~10%)
    od: Color(0xFF818CF8),              // Sapphire crystal liquid glow
    odBg: Color(0x1A818CF8),            // Restrained sapphire jewel (~10%)
    notEntered: Color(0xFF867D97),      // Slate violet
    notEnteredBg: Color(0x24867D97),
    excluded: Color(0xFF867D97),
    excludedBg: Color(0x24867D97),
    breakColor: Color(0xFFC5BDD3),
    breakBg: Color(0x24C5BDD3),
    lunch: Color(0xFF867D97),
    lunchBg: Color(0x24867D97),
    success: Color(0xFF10B981),
    successBg: Color(0x2610B981),
    warning: Color(0xFFF59E0B),
    warningBg: Color(0x1AF59E0B),
    error: Color(0xFFF43F5E),
    errorBg: Color(0x1AF43F5E),
    info: Color(0xFF818CF8),
    infoBg: Color(0x1A818CF8),
    heroChip: Color(0x24FFFFFF),
    rateHigh: Color(0xFF10B981),
    rateMedium: Color(0xFFF59E0B),
    rateLow: Color(0xFFF43F5E),
    glassSurface: Color(0xBF22202A),       // ~75% frosted obsidian glass
    glassSurfaceStrong: Color(0xEB282635), // ~92% frosted obsidian glass
    glassSurfaceSubtle: Color(0x801E1C27), // ~50% frosted obsidian glass
    glassSurfaceHero: Color(0xEB22202A),
    glassBorder: Color(0x24FFFFFF),        // 14% subtle specular rim (reduced glow)
    glassBorderStrong: Color(0x38FFFFFF),  // 22% refined specular rim (reduced glow)
    glassHighlight: Color(0x26FFFFFF),     // Restrained specular glare (~15%)
    glassScrim: Color(0x800D0C13),
    glassTint: Color(0x1AC5BDD3),          // Lavender mist optic tint
  );

  // Status bundle accessors with paired icon & label
  AppStatusStyle get presentStyle => AppStatusStyle(
        fg: present,
        bg: presentBg,
        icon: Icons.check_rounded,
        label: 'Present',
      );

  AppStatusStyle get absentStyle => AppStatusStyle(
        fg: absent,
        bg: absentBg,
        icon: Icons.close_rounded,
        label: 'Absent',
      );

  AppStatusStyle get odStyle => AppStatusStyle(
        fg: od,
        bg: odBg,
        icon: Icons.badge_outlined,
        label: 'OD',
      );

  AppStatusStyle get notEnteredStyle => AppStatusStyle(
        fg: notEntered,
        bg: notEnteredBg,
        icon: Icons.remove_rounded,
        label: 'Not entered',
      );

  AppStatusStyle get excludedStyle => AppStatusStyle(
        fg: excluded,
        bg: excludedBg,
        icon: Icons.block_rounded,
        label: 'EXCLUDED',
      );

  AppStatusStyle get breakStyle => AppStatusStyle(
        fg: breakColor,
        bg: breakBg,
        icon: Icons.coffee_rounded,
        label: 'SHORT BREAK',
      );

  AppStatusStyle get lunchStyle => AppStatusStyle(
        fg: lunch,
        bg: lunchBg,
        icon: Icons.restaurant_rounded,
        label: 'LUNCH',
      );

  AppStatusStyle get successStyle => AppStatusStyle(
        fg: success,
        bg: successBg,
        icon: Icons.check_circle_rounded,
        label: 'Success',
      );

  AppStatusStyle get warningStyle => AppStatusStyle(
        fg: warning,
        bg: warningBg,
        icon: Icons.warning_amber_rounded,
        label: 'Warning',
      );

  AppStatusStyle get errorStyle => AppStatusStyle(
        fg: error,
        bg: errorBg,
        icon: Icons.error_outline_rounded,
        label: 'Error',
      );

  AppStatusStyle get infoStyle => AppStatusStyle(
        fg: info,
        bg: infoBg,
        icon: Icons.info_outline_rounded,
        label: 'Info',
      );

  /// Helper to obtain authoritative health wording and icon from attendance percentage
  AppStatusStyle healthStyle(double percentage) {
    if (percentage >= 75.0) {
      return AppStatusStyle(
        fg: present,
        bg: presentBg,
        icon: Icons.check_circle_rounded,
        label: 'On track',
      );
    } else if (percentage >= 65.0) {
      return AppStatusStyle(
        fg: warning,
        bg: warningBg,
        icon: Icons.warning_amber_rounded,
        label: 'Needs attention',
      );
    } else {
      return AppStatusStyle(
        fg: error,
        bg: errorBg,
        icon: Icons.error_outline_rounded,
        label: 'At risk',
      );
    }
  }

  static AppColors of(BuildContext context) {
    final ext = Theme.of(context).extension<AppColors>();
    if (ext != null) return ext;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.dark : AppColors.light;
  }

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceMuted,
    Color? surfaceTint,
    Color? hero,
    Color? heroRaised,
    Color? heroGradientEnd,
    Color? onHero,
    Color? onHeroSecondary,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? borderStrong,
    Color? divider,
    Color? scrim,
    Color? primary,
    Color? primaryPressed,
    Color? onPrimary,
    Color? accent,
    Color? accentStrong,
    Color? accentOnHero,
    Color? focusRing,
    Color? present,
    Color? presentBg,
    Color? absent,
    Color? absentBg,
    Color? od,
    Color? odBg,
    Color? notEntered,
    Color? notEnteredBg,
    Color? excluded,
    Color? excludedBg,
    Color? breakColor,
    Color? breakBg,
    Color? lunch,
    Color? lunchBg,
    Color? success,
    Color? successBg,
    Color? warning,
    Color? warningBg,
    Color? error,
    Color? errorBg,
    Color? info,
    Color? infoBg,
    Color? heroChip,
    Color? rateHigh,
    Color? rateMedium,
    Color? rateLow,
    Color? glassSurface,
    Color? glassSurfaceStrong,
    Color? glassSurfaceSubtle,
    Color? glassSurfaceHero,
    Color? glassBorder,
    Color? glassBorderStrong,
    Color? glassHighlight,
    Color? glassScrim,
    Color? glassTint,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceTint: surfaceTint ?? this.surfaceTint,
      hero: hero ?? this.hero,
      heroRaised: heroRaised ?? this.heroRaised,
      heroGradientEnd: heroGradientEnd ?? this.heroGradientEnd,
      onHero: onHero ?? this.onHero,
      onHeroSecondary: onHeroSecondary ?? this.onHeroSecondary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      divider: divider ?? this.divider,
      scrim: scrim ?? this.scrim,
      primary: primary ?? this.primary,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      accentStrong: accentStrong ?? this.accentStrong,
      accentOnHero: accentOnHero ?? this.accentOnHero,
      focusRing: focusRing ?? this.focusRing,
      present: present ?? this.present,
      presentBg: presentBg ?? this.presentBg,
      absent: absent ?? this.absent,
      absentBg: absentBg ?? this.absentBg,
      od: od ?? this.od,
      odBg: odBg ?? this.odBg,
      notEntered: notEntered ?? this.notEntered,
      notEnteredBg: notEnteredBg ?? this.notEnteredBg,
      excluded: excluded ?? this.excluded,
      excludedBg: excludedBg ?? this.excludedBg,
      breakColor: breakColor ?? this.breakColor,
      breakBg: breakBg ?? this.breakBg,
      lunch: lunch ?? this.lunch,
      lunchBg: lunchBg ?? this.lunchBg,
      success: success ?? this.success,
      successBg: successBg ?? this.successBg,
      warning: warning ?? this.warning,
      warningBg: warningBg ?? this.warningBg,
      error: error ?? this.error,
      errorBg: errorBg ?? this.errorBg,
      info: info ?? this.info,
      infoBg: infoBg ?? this.infoBg,
      heroChip: heroChip ?? this.heroChip,
      rateHigh: rateHigh ?? this.rateHigh,
      rateMedium: rateMedium ?? this.rateMedium,
      rateLow: rateLow ?? this.rateLow,
      glassSurface: glassSurface ?? this.glassSurface,
      glassSurfaceStrong: glassSurfaceStrong ?? this.glassSurfaceStrong,
      glassSurfaceSubtle: glassSurfaceSubtle ?? this.glassSurfaceSubtle,
      glassSurfaceHero: glassSurfaceHero ?? this.glassSurfaceHero,
      glassBorder: glassBorder ?? this.glassBorder,
      glassBorderStrong: glassBorderStrong ?? this.glassBorderStrong,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      glassScrim: glassScrim ?? this.glassScrim,
      glassTint: glassTint ?? this.glassTint,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t) ?? surfaceElevated,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t) ?? surfaceMuted,
      surfaceTint: Color.lerp(surfaceTint, other.surfaceTint, t) ?? surfaceTint,
      hero: Color.lerp(hero, other.hero, t) ?? hero,
      heroRaised: Color.lerp(heroRaised, other.heroRaised, t) ?? heroRaised,
      heroGradientEnd: Color.lerp(heroGradientEnd, other.heroGradientEnd, t) ?? heroGradientEnd,
      onHero: Color.lerp(onHero, other.onHero, t) ?? onHero,
      onHeroSecondary: Color.lerp(onHeroSecondary, other.onHeroSecondary, t) ?? onHeroSecondary,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      border: Color.lerp(border, other.border, t) ?? border,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t) ?? borderStrong,
      divider: Color.lerp(divider, other.divider, t) ?? divider,
      scrim: Color.lerp(scrim, other.scrim, t) ?? scrim,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      primaryPressed: Color.lerp(primaryPressed, other.primaryPressed, t) ?? primaryPressed,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t) ?? onPrimary,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t) ?? accentStrong,
      accentOnHero: Color.lerp(accentOnHero, other.accentOnHero, t) ?? accentOnHero,
      focusRing: Color.lerp(focusRing, other.focusRing, t) ?? focusRing,
      present: Color.lerp(present, other.present, t) ?? present,
      presentBg: Color.lerp(presentBg, other.presentBg, t) ?? presentBg,
      absent: Color.lerp(absent, other.absent, t) ?? absent,
      absentBg: Color.lerp(absentBg, other.absentBg, t) ?? absentBg,
      od: Color.lerp(od, other.od, t) ?? od,
      odBg: Color.lerp(odBg, other.odBg, t) ?? odBg,
      notEntered: Color.lerp(notEntered, other.notEntered, t) ?? notEntered,
      notEnteredBg: Color.lerp(notEnteredBg, other.notEnteredBg, t) ?? notEnteredBg,
      excluded: Color.lerp(excluded, other.excluded, t) ?? excluded,
      excludedBg: Color.lerp(excludedBg, other.excludedBg, t) ?? excludedBg,
      breakColor: Color.lerp(breakColor, other.breakColor, t) ?? breakColor,
      breakBg: Color.lerp(breakBg, other.breakBg, t) ?? breakBg,
      lunch: Color.lerp(lunch, other.lunch, t) ?? lunch,
      lunchBg: Color.lerp(lunchBg, other.lunchBg, t) ?? lunchBg,
      success: Color.lerp(success, other.success, t) ?? success,
      successBg: Color.lerp(successBg, other.successBg, t) ?? successBg,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      warningBg: Color.lerp(warningBg, other.warningBg, t) ?? warningBg,
      error: Color.lerp(error, other.error, t) ?? error,
      errorBg: Color.lerp(errorBg, other.errorBg, t) ?? errorBg,
      info: Color.lerp(info, other.info, t) ?? info,
      infoBg: Color.lerp(infoBg, other.infoBg, t) ?? infoBg,
      heroChip: Color.lerp(heroChip, other.heroChip, t) ?? heroChip,
      rateHigh: Color.lerp(rateHigh, other.rateHigh, t) ?? rateHigh,
      rateMedium: Color.lerp(rateMedium, other.rateMedium, t) ?? rateMedium,
      rateLow: Color.lerp(rateLow, other.rateLow, t) ?? rateLow,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t) ?? glassSurface,
      glassSurfaceStrong: Color.lerp(glassSurfaceStrong, other.glassSurfaceStrong, t) ?? glassSurfaceStrong,
      glassSurfaceSubtle: Color.lerp(glassSurfaceSubtle, other.glassSurfaceSubtle, t) ?? glassSurfaceSubtle,
      glassSurfaceHero: Color.lerp(glassSurfaceHero, other.glassSurfaceHero, t) ?? glassSurfaceHero,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t) ?? glassBorder,
      glassBorderStrong: Color.lerp(glassBorderStrong, other.glassBorderStrong, t) ?? glassBorderStrong,
      glassHighlight: Color.lerp(glassHighlight, other.glassHighlight, t) ?? glassHighlight,
      glassScrim: Color.lerp(glassScrim, other.glassScrim, t) ?? glassScrim,
      glassTint: Color.lerp(glassTint, other.glassTint, t) ?? glassTint,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. TYPOGRAPHY TOKENS
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  final TextStyle display;
  final TextStyle headlineLarge;
  final TextStyle headlineMedium;
  final TextStyle headlineSmall;
  final TextStyle titleLarge;
  final TextStyle titleMedium;
  final TextStyle bodyLarge;
  final TextStyle bodyMedium;
  final TextStyle bodySmall;
  final TextStyle labelLarge;
  final TextStyle labelMedium;
  final TextStyle caption;
  final TextStyle numeric;
  final TextStyle numericLarge;
  final TextStyle numericCell;

  const AppTypography({
    required this.display,
    required this.headlineLarge,
    required this.headlineMedium,
    required this.headlineSmall,
    required this.titleLarge,
    required this.titleMedium,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.labelLarge,
    required this.labelMedium,
    required this.caption,
    required this.numeric,
    required this.numericLarge,
    required this.numericCell,
  });

  /// Standard font family with fallback to Inter and platform sans-serif
  static const String fontDisplay = 'Inter';
  static const String fontBody = 'Inter';

  static const AppTypography standard = AppTypography(
    display: TextStyle(
      fontFamily: fontDisplay,
      fontSize: 32.0,
      fontWeight: FontWeight.w800,
      height: 38.0 / 32.0, // ~1.1875
      letterSpacing: -0.6,
    ),
    headlineLarge: TextStyle(
      fontFamily: fontDisplay,
      fontSize: 28.0,
      fontWeight: FontWeight.w700,
      height: 34.0 / 28.0, // ~1.214
      letterSpacing: -0.5,
    ),
    headlineMedium: TextStyle(
      fontFamily: fontDisplay,
      fontSize: 24.0,
      fontWeight: FontWeight.w700,
      height: 30.0 / 24.0, // 1.25
      letterSpacing: -0.4,
    ),
    headlineSmall: TextStyle(
      fontFamily: fontDisplay,
      fontSize: 20.0,
      fontWeight: FontWeight.w700,
      height: 26.0 / 20.0, // 1.3
      letterSpacing: -0.2,
    ),
    titleLarge: TextStyle(
      fontFamily: fontDisplay,
      fontSize: 18.0,
      fontWeight: FontWeight.w700,
      height: 24.0 / 18.0, // ~1.333
      letterSpacing: -0.1,
    ),
    titleMedium: TextStyle(
      fontFamily: fontDisplay,
      fontSize: 16.0,
      fontWeight: FontWeight.w600,
      height: 22.0 / 16.0, // 1.375
      letterSpacing: 0.0,
    ),
    bodyLarge: TextStyle(
      fontFamily: fontBody,
      fontSize: 16.0,
      fontWeight: FontWeight.w400,
      height: 24.0 / 16.0, // 1.5
      letterSpacing: 0.0,
    ),
    bodyMedium: TextStyle(
      fontFamily: fontBody,
      fontSize: 14.0,
      fontWeight: FontWeight.w400,
      height: 20.0 / 14.0, // ~1.428
      letterSpacing: 0.0,
    ),
    bodySmall: TextStyle(
      fontFamily: fontBody,
      fontSize: 12.5,
      fontWeight: FontWeight.w400,
      height: 18.0 / 12.5, // 1.44
      letterSpacing: 0.1,
    ),
    labelLarge: TextStyle(
      fontFamily: fontBody,
      fontSize: 14.0,
      fontWeight: FontWeight.w600,
      height: 18.0 / 14.0, // ~1.285
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontFamily: fontBody,
      fontSize: 12.0,
      fontWeight: FontWeight.w600,
      height: 16.0 / 12.0, // ~1.333
      letterSpacing: 0.3,
    ),
    caption: TextStyle(
      fontFamily: fontBody,
      fontSize: 11.0,
      fontWeight: FontWeight.w500,
      height: 14.0 / 11.0, // ~1.272
      letterSpacing: 0.5,
    ),
    numeric: TextStyle(
      fontFamily: fontBody,
      fontSize: 28.0,
      fontWeight: FontWeight.w800,
      height: 32.0 / 28.0, // ~1.143
      letterSpacing: -0.5,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
    numericLarge: TextStyle(
      fontFamily: fontBody,
      fontSize: 44.0,
      fontWeight: FontWeight.w800,
      height: 48.0 / 44.0, // ~1.09
      letterSpacing: -1.0,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
    numericCell: TextStyle(
      fontFamily: fontBody,
      fontSize: 12.0,
      fontWeight: FontWeight.w700,
      height: 16.0 / 12.0, // ~1.333
      letterSpacing: 0.0,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
  );

  static AppTypography of(BuildContext context) {
    return Theme.of(context).extension<AppTypography>() ?? AppTypography.standard;
  }

  @override
  AppTypography copyWith({
    TextStyle? display,
    TextStyle? headlineLarge,
    TextStyle? headlineMedium,
    TextStyle? headlineSmall,
    TextStyle? titleLarge,
    TextStyle? titleMedium,
    TextStyle? bodyLarge,
    TextStyle? bodyMedium,
    TextStyle? bodySmall,
    TextStyle? labelLarge,
    TextStyle? labelMedium,
    TextStyle? caption,
    TextStyle? numeric,
    TextStyle? numericLarge,
    TextStyle? numericCell,
  }) {
    return AppTypography(
      display: display ?? this.display,
      headlineLarge: headlineLarge ?? this.headlineLarge,
      headlineMedium: headlineMedium ?? this.headlineMedium,
      headlineSmall: headlineSmall ?? this.headlineSmall,
      titleLarge: titleLarge ?? this.titleLarge,
      titleMedium: titleMedium ?? this.titleMedium,
      bodyLarge: bodyLarge ?? this.bodyLarge,
      bodyMedium: bodyMedium ?? this.bodyMedium,
      bodySmall: bodySmall ?? this.bodySmall,
      labelLarge: labelLarge ?? this.labelLarge,
      labelMedium: labelMedium ?? this.labelMedium,
      caption: caption ?? this.caption,
      numeric: numeric ?? this.numeric,
      numericLarge: numericLarge ?? this.numericLarge,
      numericCell: numericCell ?? this.numericCell,
    );
  }

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) return this;
    return AppTypography(
      display: TextStyle.lerp(display, other.display, t) ?? display,
      headlineLarge: TextStyle.lerp(headlineLarge, other.headlineLarge, t) ?? headlineLarge,
      headlineMedium: TextStyle.lerp(headlineMedium, other.headlineMedium, t) ?? headlineMedium,
      headlineSmall: TextStyle.lerp(headlineSmall, other.headlineSmall, t) ?? headlineSmall,
      titleLarge: TextStyle.lerp(titleLarge, other.titleLarge, t) ?? titleLarge,
      titleMedium: TextStyle.lerp(titleMedium, other.titleMedium, t) ?? titleMedium,
      bodyLarge: TextStyle.lerp(bodyLarge, other.bodyLarge, t) ?? bodyLarge,
      bodyMedium: TextStyle.lerp(bodyMedium, other.bodyMedium, t) ?? bodyMedium,
      bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t) ?? bodySmall,
      labelLarge: TextStyle.lerp(labelLarge, other.labelLarge, t) ?? labelLarge,
      labelMedium: TextStyle.lerp(labelMedium, other.labelMedium, t) ?? labelMedium,
      caption: TextStyle.lerp(caption, other.caption, t) ?? caption,
      numeric: TextStyle.lerp(numeric, other.numeric, t) ?? numeric,
      numericLarge: TextStyle.lerp(numericLarge, other.numericLarge, t) ?? numericLarge,
      numericCell: TextStyle.lerp(numericCell, other.numericCell, t) ?? numericCell,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. SPACING TOKENS
// ─────────────────────────────────────────────────────────────────────────────

abstract class AppSpacing {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0; // 2xl
  static const double xxxl = 32.0; // 3xl
  static const double x4l = 40.0; // 4xl
  static const double x5l = 48.0; // 5xl
  static const double x6l = 64.0; // 6xl

  // Semantic Spacing
  static const double pagePaddingDefault = 20.0; // >= 390px
  static const double pagePaddingCompact = 16.0; // <= 380px
  static const double sectionSpacing = 24.0;
  static const double cardSpacing = 12.0;
  static const double rosterRowSpacing = 8.0;
  static const double cardInnerPadding = 16.0;
  static const double heroCardInnerPadding = 20.0;

  /// Dynamic horizontal page padding based on screen width
  static double pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200.0) return 40.0;
    if (width >= 900.0) return 32.0;
    if (width >= 600.0) return 24.0;
    return width >= 390.0 ? pagePaddingDefault : pagePaddingCompact;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. RADIUS TOKENS
// ─────────────────────────────────────────────────────────────────────────────

abstract class AppRadius {
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double card = 24.0;
  static const double sheet = 28.0;
  static const double dialog = 24.0;
  static const double hero = 32.0;
  static const double pill = 999.0;

  // BorderRadius Helpers
  static BorderRadius get smallBorder => BorderRadius.circular(small);
  static BorderRadius get mediumBorder => BorderRadius.circular(medium);
  static BorderRadius get largeBorder => BorderRadius.circular(large);
  static BorderRadius get cardBorder => BorderRadius.circular(card);
  static BorderRadius get heroBorder => BorderRadius.circular(hero);
  static BorderRadius get sheetBorder => const BorderRadius.only(
        topLeft: Radius.circular(sheet),
        topRight: Radius.circular(sheet),
      );
  static BorderRadius get dialogBorder => BorderRadius.circular(dialog);
  static BorderRadius get pillBorder => BorderRadius.circular(pill);
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. ELEVATION TOKENS (RESTRAINED ESPRESSO SHADOWS)
// ─────────────────────────────────────────────────────────────────────────────

abstract class AppElevation {
  /// e0: Flat rows, roster rows, matrix (none; 1px border hairline)
  static const List<BoxShadow> e0 = [];

  /// e1: Standard liquid glass cards
  static const List<BoxShadow> e1 = [
    BoxShadow(
      color: Color(0x122B1A13), // rgba(43, 26, 19, 0.07) warm espresso depth
      offset: Offset(0, 4),
      blurRadius: 16,
    ),
    BoxShadow(
      color: Color(0x082B1A13),
      offset: Offset(0, 1),
      blurRadius: 4,
    ),
  ];

  /// e2: Raised cards, carousel hero card, primary buttons
  static const List<BoxShadow> e2 = [
    BoxShadow(
      color: Color(0x1A2B1A13), // rgba(43, 26, 19, 0.10)
      offset: Offset(0, 8),
      blurRadius: 22,
    ),
    BoxShadow(
      color: Color(0x0D2B1A13),
      offset: Offset(0, 2),
      blurRadius: 6,
    ),
  ];

  /// e3: Floating nav, bottom action bars
  static const List<BoxShadow> e3 = [
    BoxShadow(
      color: Color(0x242B1A13), // rgba(43, 26, 19, 0.14)
      offset: Offset(0, 12),
      blurRadius: 30,
    ),
    BoxShadow(
      color: Color(0x0F2B1A13),
      offset: Offset(0, 3),
      blurRadius: 10,
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// 6.5. GLASSMORPHISM TOKENS
// ─────────────────────────────────────────────────────────────────────────────

abstract class AppGlass {
  // Blur amounts (Sigma values for ImageFilter.blur)
  static const double blurSubtle = 12.0;
  static const double blurStandard = 18.0;
  static const double blurStrong = 24.0;
  static const double blurSheet = 28.0;

  // Opacities
  static const double opacitySubtle = 0.50;
  static const double opacityStandard = 0.78;
  static const double opacityStrong = 0.92;

  // Glass Shadows (warm espresso optical depth for cream canvas)
  static const List<BoxShadow> shadow = [
    BoxShadow(
      color: Color(0x122B1A13), // rgba(43, 26, 19, 0.07)
      offset: Offset(0, 6),
      blurRadius: 18,
    ),
    BoxShadow(
      color: Color(0x082B1A13),
      offset: Offset(0, 1),
      blurRadius: 4,
    ),
  ];

  static const List<BoxShadow> shadowElevated = [
    BoxShadow(
      color: Color(0x1A2B1A13), // rgba(43, 26, 19, 0.10)
      offset: Offset(0, 10),
      blurRadius: 26,
    ),
    BoxShadow(
      color: Color(0x0C2B1A13),
      offset: Offset(0, 2),
      blurRadius: 8,
    ),
  ];

  static const List<BoxShadow> shadowFloating = [
    BoxShadow(
      color: Color(0x242B1A13), // rgba(43, 26, 19, 0.14)
      offset: Offset(0, 14),
      blurRadius: 32,
    ),
    BoxShadow(
      color: Color(0x0F2B1A13),
      offset: Offset(0, 4),
      blurRadius: 12,
    ),
  ];

  static const LinearGradient darkSpecularGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x0AFFFFFF), // 4% subtle sheen (no milky glow)
      Color(0x00FFFFFF), // Transparent base
    ],
  );

  // Specular Gradients (simulating light passing through frosted glass with top glare reflection)
  static const LinearGradient specularGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x2EFFFFFF), // 18% white specular highlight
      Color(0x0AFFFFFF), // 4% white base
    ],
  );

  static const LinearGradient heroSpecularGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xF02B1A13), // Deep espresso glass
      Color(0xE61A0F0A), // Espresso shadow
    ],
  );

  static const LinearGradient subtleSpecularGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x1FFFFFFF), // 12%
      Color(0x08FFFFFF), // 3%
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. MOTION TOKENS
// ─────────────────────────────────────────────────────────────────────────────

abstract class AppMotion {
  // Durations
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 360);

  // Easing Curves
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve emphasizedDecel = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve accelerate = Cubic(0.3, 0.0, 0.8, 0.15);
  static const Curve press = Curves.easeOut;

  /// Respects user's reduced-motion preference
  static Duration duration(BuildContext context, Duration baseDuration) {
    final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return disable ? Duration.zero : baseDuration;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 8. ICON CONVENTIONS
// ─────────────────────────────────────────────────────────────────────────────

abstract class AppIconSize {
  static const double statusChip = 16.0;
  static const double chip = 20.0;
  static const double row = 22.0;
  static const double navHeader = 24.0;
}

// ─────────────────────────────────────────────────────────────────────────────
// 9. COMPONENT SIZE CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

abstract class AppSize {
  static const double minTouchTarget = 48.0;
  static const Size minTouchTargetSize = Size(48.0, 48.0);
  static const double primaryButton = 52.0;
  static const double secondaryButton = 48.0;
  static const double compactButton = 40.0;
  static const double input = 52.0;
  static const double standardRow = 72.0;
  static const double rosterRow = 72.0;
  static const double matrixRow = 48.0;
  static const double chip = 32.0;
  static const Size matrixChip = Size(28.0, 28.0);
}

// ─────────────────────────────────────────────────────────────────────────────
// 10. RESPONSIVE BREAKPOINT TOKENS
// ─────────────────────────────────────────────────────────────────────────────

abstract class AppBreakpoints {
  static const double narrowMobile = 360.0;
  static const double compactMobile = 400.0;
  static const double mobile = 600.0;
  static const double tablet = 1024.0;
  static const double desktop = 1200.0;
  static const double maxContentWidth = 1200.0;

  static bool isNarrow(BuildContext context) => MediaQuery.sizeOf(context).width < narrowMobile;
  static bool isCompact(BuildContext context) => MediaQuery.sizeOf(context).width < compactMobile;
  static bool isMobile(BuildContext context) => MediaQuery.sizeOf(context).width < mobile;
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobile && width < desktop;
  }
  static bool isDesktop(BuildContext context) => MediaQuery.sizeOf(context).width >= desktop;

  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppBreakpoints.desktop && desktop != null) return desktop;
    if (width >= AppBreakpoints.mobile && tablet != null) return tablet;
    return mobile;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 11. CONTEXT CONVENIENCE EXTENSION
// ─────────────────────────────────────────────────────────────────────────────

extension AppTokensContextExtension on BuildContext {
  AppColors get colors => AppColors.of(this);
  AppTypography get typography => AppTypography.of(this);
  bool get isNarrow => AppBreakpoints.isNarrow(this);
  bool get isCompact => AppBreakpoints.isCompact(this);
  bool get isMobile => AppBreakpoints.isMobile(this);
  bool get isTablet => AppBreakpoints.isTablet(this);
  bool get isDesktop => AppBreakpoints.isDesktop(this);

  T responsive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) =>
      AppBreakpoints.value<T>(
        this,
        mobile: mobile,
        tablet: tablet,
        desktop: desktop,
      );
}
