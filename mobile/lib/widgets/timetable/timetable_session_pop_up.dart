import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/faculty_model.dart';
import '../../models/student_model.dart';

/// Clean, compact timetable session pop-up displaying exclusively
/// the assigned faculty details and period timing.
/// Reusable across Student, Faculty, and Class Adviser portals.
class TimetableSessionPopUp extends StatelessWidget {
  final String? facultyName;
  final String? startTime;
  final String? endTime;

  const TimetableSessionPopUp({
    Key? key,
    this.facultyName,
    this.startTime,
    this.endTime,
  }) : super(key: key);

  /// Shows the timetable session pop-up bottom sheet from raw faculty and time strings.
  static Future<void> show(
    BuildContext context, {
    String? facultyName,
    String? startTime,
    String? endTime,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (ctx) => TimetableSessionPopUp(
        facultyName: facultyName,
        startTime: startTime,
        endTime: endTime,
      ),
    );
  }

  /// Convenience helper to show the pop-up directly from a [TimetableItemModel].
  static Future<void> showFromItem(
    BuildContext context,
    TimetableItemModel item,
  ) {
    return show(
      context,
      facultyName: item.facultyName,
      startTime: item.startTime,
      endTime: item.endTime,
    );
  }

  /// Convenience helper to show the pop-up directly from a [FacultyScheduleItem].
  static Future<void> showFromFacultySchedule(
    BuildContext context,
    FacultyScheduleItem item,
  ) {
    return show(
      context,
      facultyName: item.facultyName,
      startTime: item.startTime,
      endTime: item.endTime,
    );
  }

  /// Formats a time string into 12-hour format with AM/PM (IST).
  ///
  /// Examples:
  ///   '09:10' -> '09:10 AM'
  ///   '09:10:00' -> '09:10 AM'
  ///   '9:10' -> '09:10 AM'
  ///   '13:40' -> '01:40 PM'
  ///   '12:00' -> '12:00 PM'
  ///   '09:10 AM' -> '09:10 AM'
  static String formatTimeTo12h(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return '';
    final clean = timeStr.trim().toUpperCase();
    final isPm = clean.contains('PM');
    final isAm = clean.contains('AM');
    final raw = clean.replaceAll('AM', '').replaceAll('PM', '').trim();
    final parts = raw.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        int h = hour;
        if (isPm && h < 12) h += 12;
        if (isAm && h == 12) h = 0;
        final ampm = h >= 12 ? 'PM' : 'AM';
        int displayHour = h % 12;
        if (displayHour == 0) displayHour = 12;
        final hStr = displayHour.toString().padLeft(2, '0');
        final mStr = minute.toString().padLeft(2, '0');
        return '$hStr:$mStr $ampm';
      }
    }
    return timeStr.trim();
  }

  /// Formats period start and end time into 'hh:mm AM – hh:mm PM'.
  /// Returns 'Time unavailable' if neither time is provided or valid.
  static String formatPeriodTiming(String? start, String? end) {
    final s = formatTimeTo12h(start);
    final e = formatTimeTo12h(end);
    if (s.isEmpty && e.isEmpty) {
      return 'Time unavailable';
    }
    if (s.isNotEmpty && e.isNotEmpty) {
      return '$s – $e';
    }
    if (s.isNotEmpty) return s;
    return e;
  }

  /// Formats faculty assignment.
  /// Returns 'Faculty not assigned' if name is null, empty, or 'null'.
  static String formatFacultyName(String? name) {
    if (name == null || name.trim().isEmpty || name.trim().toLowerCase() == 'null') {
      return 'Faculty not assigned';
    }
    return name.trim();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final displayFaculty = formatFacultyName(facultyName);
    final displayTiming = formatPeriodTiming(startTime, endTime);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colors.glassBorderStrong, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.35 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: bottomInset + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Header Row with Title and Close Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Session Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                    color: colors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                key: const Key('timetable_popup_close_icon'),
                icon: const Icon(Icons.close_rounded, size: 20),
                color: colors.textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                splashRadius: 18,
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Details Card: Faculty & Time ONLY
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colors.border.withValues(alpha: colors.isDark ? 0.4 : 0.8),
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Faculty Row
                _buildInfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'FACULTY',
                  value: displayFaculty,
                  colors: colors,
                  valueKey: const Key('timetable_popup_faculty_value'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: colors.border.withValues(alpha: 0.5),
                  ),
                ),
                // Time Row
                _buildInfoRow(
                  icon: Icons.access_time_rounded,
                  label: 'TIME',
                  value: displayTiming,
                  colors: colors,
                  valueKey: const Key('timetable_popup_time_value'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Primary Close Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('timetable_popup_close_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required AppColors colors,
    Key? valueKey,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: colors.isDark ? 0.22 : 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: colors.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                key: valueKey,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
