import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Applies neutral gray highlight styling to Faculty/Staff date pickers and date-range pickers.
///
/// Matches the reference screenshot styling (day 10: #E6E0D9 in Light mode, #4A4856 in Dark mode),
/// replacing the dark brown espresso highlight (#2B1A13) with a clean, high-contrast neutral gray.
Widget buildFacultyDatePickerTheme(BuildContext context, Widget child) {
  final colors = context.colors;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  // Neutral gray highlight matching the reference styling (day 10: #E6E0D9 in Light, #4A4856 in Dark)
  final Color selectedBg = isDark ? const Color(0xFF4A4856) : const Color(0xFFE6E0D9);
  final Color selectedFg = isDark ? const Color(0xFFF7F5EE) : const Color(0xFF22150F);
  final Color inRangeBg = isDark ? const Color(0x594A4856) : const Color(0xFFEFE9E2);
  final Color todayBorderColor = isDark ? const Color(0xFFC5BDD3) : const Color(0xFF75665A);

  final colorScheme = isDark
      ? ColorScheme.dark(
          primary: selectedBg,
          onPrimary: selectedFg,
          surface: colors.background,
          onSurface: colors.textPrimary,
          primaryContainer: inRangeBg,
          onPrimaryContainer: colors.textPrimary,
          secondaryContainer: inRangeBg,
          onSecondaryContainer: colors.textPrimary,
        )
      : ColorScheme.light(
          primary: selectedBg,
          onPrimary: selectedFg,
          surface: colors.background,
          onSurface: colors.textPrimary,
          primaryContainer: inRangeBg,
          onPrimaryContainer: colors.textPrimary,
          secondaryContainer: inRangeBg,
          onSecondaryContainer: colors.textPrimary,
        );

  return Theme(
    data: Theme.of(context).copyWith(
      scaffoldBackgroundColor: colors.background,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        actionsIconTheme: IconThemeData(color: colors.textPrimary),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        rangePickerBackgroundColor: colors.background,
        rangePickerSurfaceTintColor: Colors.transparent,
        rangePickerHeaderBackgroundColor: colors.background,
        rangePickerHeaderForegroundColor: colors.textPrimary,
        rangePickerHeaderHeadlineStyle: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
        rangePickerHeaderHelpStyle: TextStyle(
          color: colors.textMuted,
          fontSize: 12,
        ),
        headerBackgroundColor: colors.background,
        headerForegroundColor: colors.textPrimary,
        rangeSelectionBackgroundColor: inRangeBg,
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return selectedBg;
          }
          return null;
        }),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.textMuted.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.selected)) {
            return selectedFg;
          }
          return colors.textPrimary;
        }),
        todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return selectedBg;
          }
          return null;
        }),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return selectedFg;
          }
          return colors.textPrimary;
        }),
        todayBorder: BorderSide(
          color: todayBorderColor,
          width: 1.2,
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: colors.textPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: colors.textSecondary,
        ),
      ),
    ),
    child: child,
  );
}
