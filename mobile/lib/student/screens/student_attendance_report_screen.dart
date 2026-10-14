import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/student_model.dart';
import '../../services/student_service.dart';
import '../../widgets/widgets.dart';

class StudentAttendanceReportScreen extends StatefulWidget {
  final bool showAppBar;
  const StudentAttendanceReportScreen({Key? key, this.showAppBar = true}) : super(key: key);

  @override
  State<StudentAttendanceReportScreen> createState() => _StudentAttendanceReportScreenState();
}

enum AttendanceColorMode {
  sapphire,    // Signature Sapphire Indigo & Electric Azure (#4F46E5 / #38BDF8)
  spectrum,    // 7 distinct luxury jewel tones (Indigo, Azure, Violet, Teal, Jade, Magenta, Cobalt)
  smartHealth, // Attendance Health Tiers (≥85% Mint Green, 75-84% Electric Ocean Azure, <75% Rose Warning)
  cyan,        // Electric Ice Cyan & Sky Blue (#0284C7 / #38BDF8)
  emerald,     // Fresh Mint Emerald (#059669 / #34D399)
  amber,       // Radiant Warm Honey Gold (#F59E0B / #FDE68A)
}

class SubjectColorTheme {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color glow;
  final Color surfaceTint;
  final Color borderTint;

  const SubjectColorTheme({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.glow,
    required this.surfaceTint,
    required this.borderTint,
  });

  static SubjectColorTheme resolve({
    required int index,
    required double percentage,
    required AttendanceColorMode mode,
    required bool isDark,
    String? subjectName,
  }) {
    if (mode == AttendanceColorMode.smartHealth) {
      if (percentage >= 85.0) {
        return isDark
            ? SubjectColorTheme(
                primary: const Color(0xFF34D399),
                secondary: const Color(0xFF059669),
                accent: const Color(0xFF6EE7B7),
                glow: const Color(0xFF34D399).withValues(alpha: 0.35),
                surfaceTint: const Color(0xFF34D399).withValues(alpha: 0.08),
                borderTint: const Color(0xFF34D399).withValues(alpha: 0.35),
              )
            : SubjectColorTheme(
                primary: const Color(0xFF059669),
                secondary: const Color(0xFF047857),
                accent: const Color(0xFF34D399),
                glow: const Color(0xFF059669).withValues(alpha: 0.20),
                surfaceTint: const Color(0xFF059669).withValues(alpha: 0.06),
                borderTint: const Color(0xFF059669).withValues(alpha: 0.30),
              );
      } else if (percentage >= 75.0) {
        // Safe & On Track: Clean Electric Azure (replaces muddy orange)
        return isDark
            ? SubjectColorTheme(
                primary: const Color(0xFF38BDF8),
                secondary: const Color(0xFF0284C7),
                accent: const Color(0xFF7DD3FC),
                glow: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                surfaceTint: const Color(0xFF38BDF8).withValues(alpha: 0.08),
                borderTint: const Color(0xFF38BDF8).withValues(alpha: 0.35),
              )
            : SubjectColorTheme(
                primary: const Color(0xFF0284C7),
                secondary: const Color(0xFF0369A1),
                accent: const Color(0xFF38BDF8),
                glow: const Color(0xFF0284C7).withValues(alpha: 0.20),
                surfaceTint: const Color(0xFF0284C7).withValues(alpha: 0.06),
                borderTint: const Color(0xFF0284C7).withValues(alpha: 0.30),
              );
      } else {
        return isDark
            ? SubjectColorTheme(
                primary: const Color(0xFFFB7185),
                secondary: const Color(0xFFE11D48),
                accent: const Color(0xFFFDA4AF),
                glow: const Color(0xFFFB7185).withValues(alpha: 0.40),
                surfaceTint: const Color(0xFFFB7185).withValues(alpha: 0.10),
                borderTint: const Color(0xFFFB7185).withValues(alpha: 0.45),
              )
            : SubjectColorTheme(
                primary: const Color(0xFFE11D48),
                secondary: const Color(0xFFBE123C),
                accent: const Color(0xFFFB7185),
                glow: const Color(0xFFE11D48).withValues(alpha: 0.20),
                surfaceTint: const Color(0xFFE11D48).withValues(alpha: 0.06),
                borderTint: const Color(0xFFE11D48).withValues(alpha: 0.30),
              );
      }
    }

    if (mode == AttendanceColorMode.sapphire) {
      return isDark
          ? SubjectColorTheme(
              primary: const Color(0xFF818CF8),
              secondary: const Color(0xFF6366F1),
              accent: const Color(0xFFA5B4FC),
              glow: const Color(0xFF818CF8).withValues(alpha: 0.35),
              surfaceTint: const Color(0xFF818CF8).withValues(alpha: 0.08),
              borderTint: const Color(0xFF818CF8).withValues(alpha: 0.35),
            )
          : SubjectColorTheme(
              primary: const Color(0xFF4F46E5),
              secondary: const Color(0xFF3730A3),
              accent: const Color(0xFF38BDF8),
              glow: const Color(0xFF4F46E5).withValues(alpha: 0.25),
              surfaceTint: const Color(0xFF4F46E5).withValues(alpha: 0.05),
              borderTint: const Color(0xFF4F46E5).withValues(alpha: 0.28),
            );
    }

    if (mode == AttendanceColorMode.cyan) {
      return isDark
          ? SubjectColorTheme(
              primary: const Color(0xFF38BDF8),
              secondary: const Color(0xFF0284C7),
              accent: const Color(0xFF7DD3FC),
              glow: const Color(0xFF38BDF8).withValues(alpha: 0.35),
              surfaceTint: const Color(0xFF38BDF8).withValues(alpha: 0.08),
              borderTint: const Color(0xFF38BDF8).withValues(alpha: 0.35),
            )
          : SubjectColorTheme(
              primary: const Color(0xFF0284C7),
              secondary: const Color(0xFF0369A1),
              accent: const Color(0xFF38BDF8),
              glow: const Color(0xFF0284C7).withValues(alpha: 0.20),
              surfaceTint: const Color(0xFF0284C7).withValues(alpha: 0.06),
              borderTint: const Color(0xFF0284C7).withValues(alpha: 0.30),
            );
    }

    if (mode == AttendanceColorMode.emerald) {
      return isDark
          ? SubjectColorTheme(
              primary: const Color(0xFF34D399),
              secondary: const Color(0xFF059669),
              accent: const Color(0xFF6EE7B7),
              glow: const Color(0xFF34D399).withValues(alpha: 0.35),
              surfaceTint: const Color(0xFF34D399).withValues(alpha: 0.08),
              borderTint: const Color(0xFF34D399).withValues(alpha: 0.35),
            )
          : SubjectColorTheme(
              primary: const Color(0xFF059669),
              secondary: const Color(0xFF047857),
              accent: const Color(0xFF34D399),
              glow: const Color(0xFF059669).withValues(alpha: 0.20),
              surfaceTint: const Color(0xFF059669).withValues(alpha: 0.06),
              borderTint: const Color(0xFF059669).withValues(alpha: 0.30),
            );
    }

    if (mode == AttendanceColorMode.amber) {
      return isDark
          ? SubjectColorTheme(
              primary: const Color(0xFFFBBF24),
              secondary: const Color(0xFFF59E0B),
              accent: const Color(0xFFFDE68A),
              glow: const Color(0xFFFBBF24).withValues(alpha: 0.35),
              surfaceTint: const Color(0xFFFBBF24).withValues(alpha: 0.08),
              borderTint: const Color(0xFFFBBF24).withValues(alpha: 0.35),
            )
          : SubjectColorTheme(
              primary: const Color(0xFFF59E0B),
              secondary: const Color(0xFFD97706),
              accent: const Color(0xFFFDE68A),
              glow: const Color(0xFFF59E0B).withValues(alpha: 0.20),
              surfaceTint: const Color(0xFFF59E0B).withValues(alpha: 0.06),
              borderTint: const Color(0xFFF59E0B).withValues(alpha: 0.30),
            );
    }

    // Default: Multi-Spectrum (distinct luxury jewel tone per subject index)
    final darkSpectrum = [
      // 0. Sapphire Indigo
      const SubjectColorTheme(
        primary: Color(0xFF818CF8),
        secondary: Color(0xFF6366F1),
        accent: Color(0xFFA5B4FC),
        glow: Color(0x59818CF8),
        surfaceTint: Color(0x14818CF8),
        borderTint: Color(0x52818CF8),
      ),
      // 1. Electric Ice Cyan
      const SubjectColorTheme(
        primary: Color(0xFF38BDF8),
        secondary: Color(0xFF0284C7),
        accent: Color(0xFF7DD3FC),
        glow: Color(0x5938BDF8),
        surfaceTint: Color(0x1438BDF8),
        borderTint: Color(0x5238BDF8),
      ),
      // 2. Royal Amethyst Purple
      const SubjectColorTheme(
        primary: Color(0xFFC084FC),
        secondary: Color(0xFF9333EA),
        accent: Color(0xFFE9D5FF),
        glow: Color(0x59C084FC),
        surfaceTint: Color(0x14C084FC),
        borderTint: Color(0x52C084FC),
      ),
      // 3. Marine Aquamarine
      const SubjectColorTheme(
        primary: Color(0xFF2DD4BF),
        secondary: Color(0xFF0D9488),
        accent: Color(0xFF99F6E4),
        glow: Color(0x592DD4BF),
        surfaceTint: Color(0x142DD4BF),
        borderTint: Color(0x522DD4BF),
      ),
      // 4. Emerald Mint
      const SubjectColorTheme(
        primary: Color(0xFF34D399),
        secondary: Color(0xFF059669),
        accent: Color(0xFF6EE7B7),
        glow: Color(0x5934D399),
        surfaceTint: Color(0x1434D399),
        borderTint: Color(0x5234D399),
      ),
      // 5. Royal Orchid Magenta
      const SubjectColorTheme(
        primary: Color(0xFFE879F9),
        secondary: Color(0xFFC026D3),
        accent: Color(0xFFF5D0FE),
        glow: Color(0x59E879F9),
        surfaceTint: Color(0x14E879F9),
        borderTint: Color(0x52E879F9),
      ),
      // 6. Royal Cobalt Cerulean
      const SubjectColorTheme(
        primary: Color(0xFF60A5FA),
        secondary: Color(0xFF2563EB),
        accent: Color(0xFF93C5FD),
        glow: Color(0x5960A5FA),
        surfaceTint: Color(0x1460A5FA),
        borderTint: Color(0x5260A5FA),
      ),
    ];

    final lightSpectrum = [
      // 0. Sapphire Indigo
      const SubjectColorTheme(
        primary: Color(0xFF4F46E5),
        secondary: Color(0xFF4338CA),
        accent: Color(0xFF38BDF8),
        glow: Color(0x334F46E5),
        surfaceTint: Color(0x0F4F46E5),
        borderTint: Color(0x404F46E5),
      ),
      // 1. Electric Ocean Azure
      const SubjectColorTheme(
        primary: Color(0xFF0284C7),
        secondary: Color(0xFF0369A1),
        accent: Color(0xFF38BDF8),
        glow: Color(0x330284C7),
        surfaceTint: Color(0x0F0284C7),
        borderTint: Color(0x400284C7),
      ),
      // 2. Royal Amethyst Purple
      const SubjectColorTheme(
        primary: Color(0xFF7C3AED),
        secondary: Color(0xFF6D28D9),
        accent: Color(0xFFA78BFA),
        glow: Color(0x337C3AED),
        surfaceTint: Color(0x0F7C3AED),
        borderTint: Color(0x407C3AED),
      ),
      // 3. Deep Marine Teal
      const SubjectColorTheme(
        primary: Color(0xFF0D9488),
        secondary: Color(0xFF0F766E),
        accent: Color(0xFF2DD4BF),
        glow: Color(0x330D9488),
        surfaceTint: Color(0x0F0D9488),
        borderTint: Color(0x400D9488),
      ),
      // 4. Emerald Jade
      const SubjectColorTheme(
        primary: Color(0xFF059669),
        secondary: Color(0xFF047857),
        accent: Color(0xFF34D399),
        glow: Color(0x33059669),
        surfaceTint: Color(0x0F059669),
        borderTint: Color(0x40059669),
      ),
      // 5. Royal Orchid Magenta
      const SubjectColorTheme(
        primary: Color(0xFFC026D3),
        secondary: Color(0xFFA21CAF),
        accent: Color(0xFFE879F9),
        glow: Color(0x33C026D3),
        surfaceTint: Color(0x0FC026D3),
        borderTint: Color(0x40C026D3),
      ),
      // 6. Royal Cobalt Cerulean
      const SubjectColorTheme(
        primary: Color(0xFF2563EB),
        secondary: Color(0xFF1D4ED8),
        accent: Color(0xFF60A5FA),
        glow: Color(0x332563EB),
        surfaceTint: Color(0x0F2563EB),
        borderTint: Color(0x402563EB),
      ),
    ];

    final list = isDark ? darkSpectrum : lightSpectrum;
    return list[index % list.length];
  }
}

class _StudentAttendanceReportScreenState extends State<StudentAttendanceReportScreen> {
  int? _selectedSubjectId;
  AttendanceColorMode _colorMode = AttendanceColorMode.sapphire;
  bool _showOverallAttendance = false;
  String? _selectedDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final studentService = Provider.of<StudentService>(context, listen: false);
      if (studentService.dateWise.isEmpty) {
        studentService.fetchAttendanceReport();
      }
      if (studentService.timetable.isEmpty) {
        studentService.fetchTimetable();
      }
    });
  }

  DateWiseEntryModel? _resolveActiveDailyEntry(List<DateWiseEntryModel> dateWise) {
    if (dateWise.isEmpty) return null;

    if (_selectedDate != null) {
      for (final e in dateWise) {
        if (e.date == _selectedDate) return e;
      }
    }

    // Try finding today's date
    final now = DateTime.now();
    final todayStr =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    for (final e in dateWise) {
      if (e.date == todayStr) return e;
    }

    // Default to latest date in list (since records are sorted ascending)
    return dateWise.last;
  }

  String _formatDateLabel(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        final now = DateTime.now();
        final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final weekday = weekdays[dt.weekday - 1];
        final month = months[dt.month - 1];
        final formatted = "$weekday, ${dt.day} $month ${dt.year}";
        return isToday ? "Today • $formatted" : formatted;
      }
    } catch (_) {}
    return dateStr;
  }

  Future<void> _refreshData() async {
    final studentService = Provider.of<StudentService>(context, listen: false);
    await Future.wait([
      studentService.fetchStudentSummary(),
      studentService.fetchSubjects(),
      studentService.fetchTimetable(),
      studentService.fetchAttendanceReportFiltered(subjectId: _selectedSubjectId),
    ]);
  }

  Widget _buildSubjectCard(
    SubjectAttendanceModel sub,
    int index,
    List<TimetableItemModel> timetable,
  ) {
    final colors = context.colors;
    final theme = SubjectColorTheme.resolve(
      index: index,
      percentage: sub.percentage,
      mode: _colorMode,
      isDark: colors.isDark,
      subjectName: sub.subjectName,
    );

    // 1. Resolve matching timetable item or fallback to period schedule
    TimetableItemModel? matchedTt;
    for (final tt in timetable) {
      if ((tt.subjectCode != null && tt.subjectCode!.trim().toUpperCase() == sub.subjectCode.trim().toUpperCase()) ||
          (tt.subjectName != null && tt.subjectName!.trim().toUpperCase() == sub.subjectName.trim().toUpperCase())) {
        matchedTt = tt;
        break;
      }
    }

    const defaultSlots = [
      {'num': 1, 'start': '08:45 AM', 'end': '09:40 AM', 'startM': 525, 'endM': 580},
      {'num': 2, 'start': '09:40 AM', 'end': '10:35 AM', 'startM': 580, 'endM': 635},
      {'num': 3, 'start': '10:55 AM', 'end': '11:50 AM', 'startM': 655, 'endM': 710},
      {'num': 4, 'start': '11:50 AM', 'end': '12:45 PM', 'startM': 710, 'endM': 765},
      {'num': 5, 'start': '01:45 PM', 'end': '02:40 PM', 'startM': 825, 'endM': 880},
      {'num': 6, 'start': '02:40 PM', 'end': '03:30 PM', 'startM': 880, 'endM': 930},
      {'num': 7, 'start': '03:30 PM', 'end': '04:20 PM', 'startM': 930, 'endM': 980},
    ];
    final slotIndex = index % defaultSlots.length;
    final defaultSlot = defaultSlots[slotIndex];

    final periodNum = matchedTt?.periodNumber ?? (index + 1);
    final periodLabel = matchedTt?.periodName ?? 'Period $periodNum';
    final startTime = matchedTt?.startTime ?? (defaultSlot['start'] as String);
    final endTime = matchedTt?.endTime ?? (defaultSlot['end'] as String);
    final timeSlot = '$startTime - $endTime';
    final startM = defaultSlot['startM'] as int;
    final endM = defaultSlot['endM'] as int;

    // 2. Compute dynamic live class state (Completed / In Progress / Upcoming)
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    String liveStatusText;
    Color liveBadgeColor;
    if (currentMinutes >= endM) {
      liveStatusText = 'Completed ✓';
      liveBadgeColor = colors.textMuted;
    } else if (currentMinutes >= startM && currentMinutes < endM) {
      final leftM = endM - currentMinutes;
      liveStatusText = 'In Progress (${leftM}m left)';
      liveBadgeColor = theme.primary;
    } else {
      final cleanStartTime = startTime.replaceAll(' ', '');
      liveStatusText = 'Upcoming (Starts $cleanStartTime)';
      liveBadgeColor = colors.od;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.isDark ? colors.glassSurfaceStrong : const Color(0xFFEFF3F8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.isDark
              ? theme.borderTint.withValues(alpha: 0.40)
              : const Color(0xFFD6E0EC),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.isDark
                ? theme.glow.withValues(alpha: 0.14)
                : const Color(0xFF2B3A4A).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => SubjectDetailSheet.show(context, sub),
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Row 1: Period dot & time on left, Live status pill on right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: theme.primary.withValues(alpha: 0.65),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '$periodLabel • $timeSlot',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: liveStatusText.contains('Completed')
                            ? (colors.isDark ? colors.surfaceElevated : const Color(0xFFFFFFFF))
                            : liveBadgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: liveStatusText.contains('Completed')
                              ? (colors.isDark ? colors.glassBorderStrong : const Color(0xFFD6E0EC))
                              : liveBadgeColor.withValues(alpha: 0.45),
                          width: 0.9,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (liveStatusText.contains('In Progress')) ...[
                            Container(
                              width: 5.5,
                              height: 5.5,
                              margin: const EdgeInsets.only(right: 4.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: liveBadgeColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: liveBadgeColor.withValues(alpha: 0.8),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Text(
                            liveStatusText,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: liveStatusText.contains('Completed')
                                  ? colors.textSecondary
                                  : liveBadgeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),

                // Row 2: Subject Name & Code on left, Percentage pill on right
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub.subjectName,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: colors.isDark ? theme.surfaceTint : const Color(0xFFFFFFFF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: colors.isDark
                                    ? theme.borderTint.withValues(alpha: 0.55)
                                    : const Color(0xFFD0DDEB),
                                width: 0.9,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.tag_rounded,
                                  size: 11,
                                  color: theme.primary,
                                ),
                                const SizedBox(width: 3.5),
                                Text(
                                  'Code: ${sub.subjectCode}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildPercentagePill(sub.percentage, theme, colors),
                  ],
                ),
                const SizedBox(height: 14),

                // Row 3: Horizontal Progress Bar with 75% Institutional Notch & Glowing Pearl Tip
                LayoutBuilder(
                  builder: (context, constraints) {
                    final totalWidth = constraints.maxWidth;
                    final pct = (sub.percentage / 100.0).clamp(0.0, 1.0);
                    final activeWidth = totalWidth * pct;
                    final target75X = totalWidth * 0.75;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Background Track (Recessed bevel with subtle inner border)
                            Container(
                              height: 8.5,
                              decoration: BoxDecoration(
                                color: colors.isDark
                                    ? colors.surfaceElevated
                                    : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: colors.isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : const Color(0xFFCBD5E1).withValues(alpha: 0.6),
                                  width: 0.8,
                                ),
                              ),
                            ),

                            // 75% Institutional Threshold Line
                            Positioned(
                              left: target75X - 1.0,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 2.0,
                                decoration: BoxDecoration(
                                  color: colors.isDark
                                      ? Colors.white.withValues(alpha: 0.35)
                                      : const Color(0xFF64748B).withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ),

                            // Active Fill with Multi-stop Gradient and Glow
                            if (activeWidth > 0)
                              Container(
                                width: activeWidth,
                                height: 8.5,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      theme.secondary,
                                      theme.primary,
                                      theme.accent,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(100),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.primary.withValues(alpha: colors.isDark ? 0.45 : 0.32),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                      spreadRadius: 0.5,
                                    ),
                                  ],
                                ),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    width: 6.5,
                                    height: 6.5,
                                    margin: const EdgeInsets.only(right: 1),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(alpha: 0.92),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withValues(alpha: 0.8),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        // Milestone footer labels: 0% | 75% Min Target | 100%
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '0%',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: colors.textMuted.withValues(alpha: 0.75),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: sub.percentage >= 75.0 ? colors.present : colors.warning,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '75% Min Target',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: sub.percentage >= 75.0
                                        ? (colors.isDark ? colors.present : const Color(0xFF047857))
                                        : colors.warning,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '100%',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: colors.textMuted.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPercentagePill(
    double percentage,
    SubjectColorTheme theme,
    AppColors colors,
  ) {
    final String statusLabel;
    final Color statusColor;

    if (percentage >= 85.0) {
      statusLabel = 'Safe';
      statusColor = colors.present;
    } else if (percentage >= 75.0) {
      statusLabel = 'On Track';
      statusColor = const Color(0xFF0284C7);
    } else if (percentage >= 65.0) {
      statusLabel = 'Warning';
      statusColor = colors.warning;
    } else {
      statusLabel = 'Critical';
      statusColor = colors.absent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: colors.isDark ? theme.surfaceTint : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.isDark ? theme.primary.withValues(alpha: 0.45) : const Color(0xFFC7D7E8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.glow.withValues(alpha: colors.isDark ? 0.25 : 0.10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.6),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceHeroCard(
    AppColors colors,
    StudentSummaryModel? summary,
    List<DateWiseEntryModel> dateWise,
  ) {
    // Mode Switcher Header Pill (Daily Attendance by default, with option to inspect Overall)
    final modeSwitcher = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.glassSurfaceStrong,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.glassBorderStrong, width: 1.1),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_showOverallAttendance) {
                    setState(() => _showOverallAttendance = false);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: !_showOverallAttendance ? colors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.today_rounded,
                          size: 14,
                          color: !_showOverallAttendance ? Colors.white : colors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Daily Attendance',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: !_showOverallAttendance ? Colors.white : colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (!_showOverallAttendance) {
                    setState(() => _showOverallAttendance = true);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _showOverallAttendance ? colors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.insights_rounded,
                          size: 14,
                          color: _showOverallAttendance ? Colors.white : colors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Overall Attendance',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _showOverallAttendance ? Colors.white : colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (_showOverallAttendance && summary != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          modeSwitcher,
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: AttendanceSummaryCard(
              title: 'OVERALL ATTENDANCE',
              subtitle: 'Min Requirement: ${summary.minimumRequired.toStringAsFixed(0)}%',
              icon: Icons.insights_rounded,
              percentage: summary.percentage,
              total: summary.total,
              present: summary.present,
              absent: summary.absent,
              od: summary.od,
              halfDayPresent: summary.halfDayPresent,
              halfDayAbsent: summary.halfDayAbsent,
              status: summary.attendanceStatus,
              minimumRequired: summary.minimumRequired,
              calculationMode: summary.calculationMode,
              alertMessage: summary.alertMessage,
            ),
          ),
        ],
      );
    }

    // Daily Attendance View (Default & Primary Focus)
    final activeDaily = _resolveActiveDailyEntry(dateWise);
    final now = DateTime.now();
    final todayStr =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final effectiveDate = activeDaily?.date ?? todayStr;
    final dateLabel = _formatDateLabel(effectiveDate);

    int dayTotal = 0;
    int dayPresent = 0;
    int dayAbsent = 0;
    int dayOd = 0;

    if (activeDaily != null) {
      for (final p in activeDaily.periods) {
        final st = p.status.toUpperCase();
        if (st == 'PRESENT') {
          dayPresent++;
          dayTotal++;
        } else if (st == 'ABSENT') {
          dayAbsent++;
          dayTotal++;
        } else if (st == 'OD') {
          dayOd++;
          dayTotal++;
        } else if (st != 'NOT_ENTERED') {
          dayTotal++;
        }
      }
    }

    final double dayPercentage = dayTotal > 0
        ? (((dayPresent + dayOd) / dayTotal) * 100.0).clamp(0.0, 100.0)
        : 0.0;

    final String dayStatus;
    if (activeDaily?.dailyResult != null && activeDaily!.dailyResult!.isNotEmpty) {
      final dr = activeDaily.dailyResult!.toUpperCase();
      if (dr.contains('FULL DAY PRESENT') || dr == 'PRESENT') {
        dayStatus = 'FULL DAY';
      } else if (dr.contains('HALF-DAY') || dr.contains('PARTIAL')) {
        dayStatus = 'PARTIAL';
      } else if (dr.contains('ABSENT')) {
        dayStatus = 'ABSENT';
      } else if (dr.contains('OD')) {
        dayStatus = 'OD';
      } else {
        dayStatus = dayPercentage >= 75.0 ? 'OK' : 'CRITICAL';
      }
    } else {
      dayStatus = dayTotal == 0 ? 'NO_DATA' : (dayPercentage >= 75.0 ? 'OK' : 'CRITICAL');
    }

    final String dayAlertMessage;
    if (dayTotal == 0) {
      dayAlertMessage = 'No attendance recorded for this date.';
    } else if (dayAbsent == 0 && (dayPresent + dayOd) > 0) {
      dayAlertMessage = 'Full Attendance: All $dayTotal scheduled periods attended.';
    } else if (dayPresent > 0 && dayAbsent > 0) {
      dayAlertMessage = 'Partial Attendance: Attended ${dayPresent + dayOd} of $dayTotal periods ($dayAbsent absent).';
    } else if (dayPresent == 0 && dayAbsent > 0) {
      dayAlertMessage = 'Absent for all $dayTotal scheduled periods.';
    } else if (dayOd > 0 && dayAbsent == 0) {
      dayAlertMessage = 'On-Duty approved for $dayOd scheduled periods.';
    } else {
      dayAlertMessage = 'Daily Attendance: $dayPresent Present, $dayAbsent Absent, $dayOd OD.';
    }

    final currentIndex = activeDaily != null ? dateWise.indexOf(activeDaily) : -1;
    final hasPrev = currentIndex > 0;
    final hasNext = currentIndex >= 0 && currentIndex < dateWise.length - 1;

    final dateSwitcher = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: hasPrev
              ? () => setState(() => _selectedDate = dateWise[currentIndex - 1].date)
              : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: hasPrev
                  ? colors.glassSurfaceStrong
                  : colors.glassSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasPrev
                    ? colors.glassBorderStrong
                    : colors.glassBorder.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chevron_left_rounded,
                  size: 16,
                  color: hasPrev ? colors.textPrimary : colors.textMuted.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 3),
                Text(
                  'Prev Day',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: hasPrev ? colors.textSecondary : colors.textMuted.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month_rounded, size: 14, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                dateLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: hasNext
              ? () => setState(() => _selectedDate = dateWise[currentIndex + 1].date)
              : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: hasNext
                  ? colors.glassSurfaceStrong
                  : colors.glassSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasNext
                    ? colors.glassBorderStrong
                    : colors.glassBorder.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Next Day',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: hasNext ? colors.textSecondary : colors.textMuted.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: hasNext ? colors.textPrimary : colors.textMuted.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        modeSwitcher,
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: AttendanceSummaryCard(
            title: 'DAILY ATTENDANCE',
            subtitle: dateLabel,
            icon: Icons.today_rounded,
            percentage: dayPercentage,
            total: dayTotal,
            present: dayPresent,
            absent: dayAbsent,
            od: dayOd,
            status: dayStatus,
            minimumRequired: summary?.minimumRequired ?? 75.0,
            alertMessage: dayAlertMessage,
            headerAction: dateWise.length > 1 ? dateSwitcher : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final studentService = Provider.of<StudentService>(context);
    final summary = studentService.summary;
    final subjects = studentService.subjects;
    final dateWise = studentService.dateWise;
    final activeDaily = _resolveActiveDailyEntry(dateWise);
    final now = DateTime.now();
    final todayStr =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final effectiveDate = activeDaily?.date ?? todayStr;
    final dateLabel = _formatDateLabel(effectiveDate);

    final Widget bodyContent = studentService.isLoading && summary == null
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            color: colors.primary,
              backgroundColor: colors.surface,
              onRefresh: _refreshData,
              child: Stack(
                children: [
                  AppScaffold.buildLiquidAmbientCanvas(),
                  SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Student Info Header (Apple VisionOS Profile Card)
                        if (summary != null)
                          Container(
                            margin: const EdgeInsets.fromLTRB(AppSpacing.md, 4, AppSpacing.md, 0),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: colors.glassSurfaceStrong,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: colors.glassBorderStrong,
                                width: 1.2,
                              ),
                              boxShadow: AppGlass.shadow,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: colors.isDark
                                          ? const [
                                              Color(0xFF2E2A3C),
                                              Color(0xFF1E1C27),
                                            ]
                                          : const [
                                              Color(0xFF2B1A13),
                                              Color(0xFF4A2E20),
                                            ],
                                    ),
                                    border: colors.isDark ? Border.all(color: colors.glassBorderStrong, width: 1.2) : null,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      summary.fullName.isNotEmpty ? summary.fullName[0].toUpperCase() : 'A',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: colors.isDark ? colors.textPrimary : const Color(0xFFFFF8F0),
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    summary.fullName,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: colors.textPrimary,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 12),

                        // Attendance Summary Card (Daily Attendance by default, Overall on switch)
                        _buildAttendanceHeroCard(colors, summary, dateWise),

                        const SizedBox(height: 12),

                        // Daily Schedule Breakdown (Target Reference UI) or Subject Cards if viewing Overall Attendance
                        if (!_showOverallAttendance)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                            child: DailyScheduleCard(
                              entry: activeDaily,
                              timetable: studentService.timetable,
                              subjects: subjects,
                              dateLabel: dateLabel,
                            ),
                          )
                        else if (subjects.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.xxl),
                            child: Center(
                              child: Text(
                                'No subject attendance data available.',
                                style: TextStyle(color: colors.textSecondary),
                              ),
                            ),
                          )
                        else
                          ...subjects.asMap().entries.map((entry) {
                            return _buildSubjectCard(
                              entry.value,
                              entry.key,
                              studentService.timetable,
                            );
                          }),

                        const SizedBox(height: AppSpacing.md),

                        // Attendance Legend
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          child: AttendanceLegend(),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                      ],
                    ),
                  ),
                ],
              ),
            );

    if (!widget.showAppBar) {
      return bodyContent;
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Attendance Report',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: colors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              color: colors.textPrimary,
              onPressed: _refreshData,
            ),
          ),
        ],
      ),
      body: bodyContent,
    );
  }
}
