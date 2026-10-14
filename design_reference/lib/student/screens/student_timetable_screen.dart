import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/student_model.dart';
import '../../services/student_service.dart';
import '../../design_mode/design_mock_data.dart';
import '../../widgets/widgets.dart';
import 'student_attendance_report_screen.dart';

enum TimetableViewMode {
  weeklyGrid, // Editorial Matrix Table Grid View
  dayAgenda,  // Modernized Day-wise List View
}

enum PeriodClassStatus {
  activeNow,
  upcoming,
  completed,
  freePeriod,
  none,
}

enum TimetableHighlightTone {
  sapphireIndigo, // Default: Signature Obsidian Electric Indigo / Sapphire Crystal
  electricCyan,   // High-tech Ice Cyan & Cerulean Azure
  solarAmber,     // Radiant Solar Amber & CAD Gold
  emeraldMint,    // Refined High-contrast Emerald Mint
}

class HighlightPalette {
  final String label;
  final Color primary;
  final Color accentLight;
  final Color headerBg;
  final Color columnBg;
  final Color glow;
  final Color badgeBg;
  final Color badgeFg;
  final Color cardBorder;
  final List<Color> dockGradient;

  const HighlightPalette({
    required this.label,
    required this.primary,
    required this.accentLight,
    required this.headerBg,
    required this.columnBg,
    required this.glow,
    required this.badgeBg,
    required this.badgeFg,
    required this.cardBorder,
    required this.dockGradient,
  });

  static HighlightPalette of(TimetableHighlightTone tone, bool isDark) {
    switch (tone) {
      case TimetableHighlightTone.sapphireIndigo:
        return HighlightPalette(
          label: 'Sapphire Indigo',
          primary: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
          accentLight: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF3730A3),
          headerBg: isDark ? const Color(0xFF201D38) : const Color(0xFFE2EAF4),
          columnBg: isDark ? const Color(0xFF151326) : const Color(0xFFEFF3F8),
          glow: (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)).withValues(alpha: 0.35),
          badgeBg: isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5),
          badgeFg: Colors.white,
          cardBorder: isDark ? const Color(0xFF818CF8) : const Color(0xFFC5D5E6),
          dockGradient: isDark
              ? const [Color(0xFF1F1D38), Color(0xFF141324)]
              : const [Color(0xFFEFF3F8), Color(0xFFE5EDF5)],
        );

      case TimetableHighlightTone.electricCyan:
        return HighlightPalette(
          label: 'Electric Cyan',
          primary: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
          accentLight: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
          headerBg: isDark ? const Color(0xFF12283A) : const Color(0xFFE2EAF4),
          columnBg: isDark ? const Color(0xFF0E1C27) : const Color(0xFFEFF3F8),
          glow: (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)).withValues(alpha: 0.35),
          badgeBg: isDark ? const Color(0xFF0284C7) : const Color(0xFF0369A1),
          badgeFg: Colors.white,
          cardBorder: isDark ? const Color(0xFF38BDF8) : const Color(0xFFB5CCE0),
          dockGradient: isDark
              ? const [Color(0xFF142938), Color(0xFF0E1A24)]
              : const [Color(0xFFEFF3F8), Color(0xFFE2EAF4)],
        );

      case TimetableHighlightTone.solarAmber:
        return HighlightPalette(
          label: 'Solar Amber',
          primary: isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B),
          accentLight: isDark ? const Color(0xFFFDE68A) : const Color(0xFFD97706),
          headerBg: isDark ? const Color(0xFF342310) : const Color(0xFFE8EEF5),
          columnBg: isDark ? const Color(0xFF22170D) : const Color(0xFFEFF3F8),
          glow: (isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B)).withValues(alpha: 0.35),
          badgeBg: isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
          badgeFg: Colors.white,
          cardBorder: isDark ? const Color(0xFFFBBF24) : const Color(0xFFE2D6BE),
          dockGradient: isDark
              ? const [Color(0xFF332010), Color(0xFF1F140A)]
              : const [Color(0xFFEFF3F8), Color(0xFFF9F5EB)],
        );

      case TimetableHighlightTone.emeraldMint:
        return HighlightPalette(
          label: 'Emerald Mint',
          primary: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
          accentLight: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
          headerBg: isDark ? const Color(0xFF152A20) : const Color(0xFFE2EAF4),
          columnBg: isDark ? const Color(0xFF0E1C15) : const Color(0xFFEFF3F8),
          glow: (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)).withValues(alpha: 0.35),
          badgeBg: isDark ? const Color(0xFF059669) : const Color(0xFF047857),
          badgeFg: Colors.white,
          cardBorder: isDark ? const Color(0xFF34D399) : const Color(0xFFB4D8C7),
          dockGradient: isDark
              ? const [Color(0xFF162B21), Color(0xFF0E1B15)]
              : const [Color(0xFFEFF3F8), Color(0xFFE4EFEA)],
        );
    }
  }
}

class ScheduleSlotConfig {
  final int periodNumber;
  final String label;
  final String startTime;
  final String endTime;
  final bool isBreak;
  final double height;

  const ScheduleSlotConfig({
    required this.periodNumber,
    required this.label,
    required this.startTime,
    required this.endTime,
    this.isBreak = false,
    this.height = 72.0,
  });
}

class StudentTimetableScreen extends StatefulWidget {
  const StudentTimetableScreen({Key? key}) : super(key: key);

  @override
  State<StudentTimetableScreen> createState() => _StudentTimetableScreenState();
}

class _StudentTimetableScreenState extends State<StudentTimetableScreen> {
  static const List<String> _weekdays = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];

  static const List<String> _dayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  // Standard College Period Schedule Slots
  static const List<ScheduleSlotConfig> _slots = [
    ScheduleSlotConfig(periodNumber: 1, label: 'P1', startTime: '08:45 AM', endTime: '09:40 AM', height: 72.0),
    ScheduleSlotConfig(periodNumber: 2, label: 'P2', startTime: '09:40 AM', endTime: '10:35 AM', height: 72.0),
    ScheduleSlotConfig(periodNumber: -1, label: 'TEA BREAK', startTime: '10:35 AM', endTime: '10:55 AM', isBreak: true, height: 26.0),
    ScheduleSlotConfig(periodNumber: 3, label: 'P3', startTime: '10:55 AM', endTime: '11:50 AM', height: 72.0),
    ScheduleSlotConfig(periodNumber: 4, label: 'P4', startTime: '11:50 AM', endTime: '12:45 PM', height: 72.0),
    ScheduleSlotConfig(periodNumber: -2, label: 'LUNCH BREAK', startTime: '12:45 PM', endTime: '01:45 PM', isBreak: true, height: 28.0),
    ScheduleSlotConfig(periodNumber: 5, label: 'P5', startTime: '01:45 PM', endTime: '02:40 PM', height: 72.0),
    ScheduleSlotConfig(periodNumber: 6, label: 'P6', startTime: '02:40 PM', endTime: '03:30 PM', height: 72.0),
    ScheduleSlotConfig(periodNumber: 7, label: 'P7', startTime: '03:30 PM', endTime: '04:20 PM', height: 72.0),
  ];

  TimetableViewMode _viewMode = TimetableViewMode.weeklyGrid;
  late String _selectedDay;
  bool _simulateLiveClass = true;
  TimetableHighlightTone _highlightTone = TimetableHighlightTone.sapphireIndigo;

  @override
  void initState() {
    super.initState();
    _selectedDay = _getCurrentWeekdayName();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final studentService = Provider.of<StudentService>(context, listen: false);
      if (studentService.timetable.isEmpty) {
        studentService.fetchTimetable();
      }
    });
  }

  String _getCurrentWeekdayName() {
    final now = DateTime.now();
    switch (now.weekday) {
      case DateTime.monday:
        return 'MONDAY';
      case DateTime.tuesday:
        return 'TUESDAY';
      case DateTime.wednesday:
        return 'WEDNESDAY';
      case DateTime.thursday:
        return 'THURSDAY';
      case DateTime.friday:
        return 'FRIDAY';
      case DateTime.saturday:
        return 'SATURDAY';
      case DateTime.sunday:
        return 'SUNDAY';
      default:
        return 'MONDAY';
    }
  }

  bool _isToday(String day) {
    return day.toUpperCase() == _getCurrentWeekdayName().toUpperCase();
  }

  int _parseTimeToMinutes(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return -1;
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final raw = clean.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = raw.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        if (isPm && hour < 12) hour += 12;
        if (isAm && hour == 12) hour = 0;
        return hour * 60 + minute;
      }
    } catch (_) {}
    return -1;
  }

  bool _hasAnyRealActivePeriod() {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    for (final slot in _slots) {
      if (!slot.isBreak) {
        final start = _parseTimeToMinutes(slot.startTime);
        final end = _parseTimeToMinutes(slot.endTime);
        if (start != -1 && end != -1 && nowMin >= start && nowMin <= end) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isItemActiveNow(TimetableItemModel item) {
    if (!_isToday(item.dayOfWeek)) return false;
    final startMin = _parseTimeToMinutes(item.startTime);
    final endMin = _parseTimeToMinutes(item.endTime);
    if (startMin == -1 || endMin == -1) return false;
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    if (nowMin >= startMin && nowMin <= endMin) {
      return true;
    }
    // Simulation fallback: ONLY activate if NO real period is currently within active hours
    if (_simulateLiveClass) {
      final hasRealActive = _hasAnyRealActivePeriod();
      if (!hasRealActive && item.periodNumber == 2) {
        return true;
      }
    }
    return false;
  }

  PeriodClassStatus _determinePeriodStatus(TimetableItemModel item, List<TimetableItemModel> dayItems) {
    if (item.subjectCode == null || item.subjectCode!.isEmpty) {
      return PeriodClassStatus.freePeriod;
    }

    if (!_isToday(_selectedDay)) {
      return PeriodClassStatus.none;
    }

    final startMinutes = _parseTimeToMinutes(item.startTime);
    final endMinutes = _parseTimeToMinutes(item.endTime);

    if (startMinutes == -1 || endMinutes == -1) {
      return PeriodClassStatus.none;
    }

    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    if (nowMinutes >= startMinutes && nowMinutes <= endMinutes) {
      return PeriodClassStatus.activeNow;
    } else if (nowMinutes > endMinutes) {
      return PeriodClassStatus.completed;
    } else if (nowMinutes < startMinutes) {
      TimetableItemModel? nextUpcoming;
      for (final other in dayItems) {
        final otherStart = _parseTimeToMinutes(other.startTime);
        if (otherStart > nowMinutes) {
          if (nextUpcoming == null) {
            nextUpcoming = other;
          } else {
            final bestStart = _parseTimeToMinutes(nextUpcoming.startTime);
            if (otherStart < bestStart) {
              nextUpcoming = other;
            }
          }
        }
      }
      if (nextUpcoming == item) {
        return PeriodClassStatus.upcoming;
      }
    }

    return PeriodClassStatus.none;
  }

  Color _getCardColor(TimetableItemModel item) {
    final tag = (item.colorTag ?? '').toLowerCase();
    switch (tag) {
      case 'slate':
        return const Color(0xFF535D6C); // Slate Denim Grey
      case 'pine':
        return const Color(0xFF284638); // Deep Pine Muted Green
      case 'emerald':
        return const Color(0xFF0B6A4E); // Vibrant Forest Emerald Green
      case 'espresso':
      default:
        return const Color(0xFF2E2724); // Roasted Espresso / Charcoal
    }
  }

  double _getSlotTop(int slotIndex) {
    double top = 0;
    for (int i = 0; i < slotIndex && i < _slots.length; i++) {
      top += _slots[i].height;
    }
    return top;
  }

  double _getTotalSlotsHeight() {
    double total = 0;
    for (final s in _slots) {
      total += s.height;
    }
    return total;
  }

  int _mapPeriodToSlotIndex(int periodNumber) {
    for (int i = 0; i < _slots.length; i++) {
      if (_slots[i].periodNumber == periodNumber) return i;
    }
    return 0;
  }

  void _showClassDetailsModal(TimetableItemModel item) {
    final colors = context.colors;
    final palette = HighlightPalette.of(_highlightTone, colors.isDark);
    final cardColor = _getCardColor(item);
    final isCurrent = _isItemActiveNow(item);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: colors.glassBorderStrong, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 28,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.md,
            bottom: MediaQuery.of(ctx).padding.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Color Banner Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: cardColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.subjectCode ?? 'COURSE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: palette.badgeBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'LIVE CLASS NOW',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (item.span > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${item.span} Periods Span',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.subjectName ?? 'Class Session',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.dayOfWeek} • ${item.startTime ?? ""} - ${item.endTime ?? ""}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Detail Grid
              Row(
                children: [
                  Expanded(
                    child: _buildDetailPuck(
                      icon: Icons.person_outline_rounded,
                      label: 'FACULTY',
                      value: item.facultyName ?? 'Faculty Assignment Pending',
                      colors: colors,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildDetailPuck(
                      icon: Icons.meeting_room_outlined,
                      label: 'VENUE',
                      value: item.roomNo ?? 'Lecture Hall',
                      colors: colors,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailPuck(
                      icon: Icons.access_time_rounded,
                      label: 'TIME SLOT',
                      value: '${item.startTime ?? "--"} to ${item.endTime ?? "--"}',
                      colors: colors,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildDetailPuck(
                      icon: Icons.school_outlined,
                      label: 'TYPE',
                      value: (item.type ?? (item.subjectName?.toLowerCase().contains('lab') == true ? 'Laboratory' : 'Core Theory')).toUpperCase(),
                      colors: colors,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Quick Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: colors.border),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Close',
                        style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StudentAttendanceReportScreen(),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.analytics_outlined, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Attendance Report',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailPuck({
    required IconData icon,
    required String label,
    required String value,
    required AppColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.glassSurfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final studentService = Provider.of<StudentService>(context);

    // Sole authoritative schedule source from backend (with design fallback)
    final allItems = studentService.timetable.isNotEmpty
        ? studentService.timetable
        : DesignMockData.mockTimetable;

    // Dynamically adjust for Saturday if backend has Saturday classes configured
    final bool hasSaturdayClasses = allItems.any((i) =>
        i.dayOfWeek.toUpperCase() == 'SATURDAY' &&
        i.subjectCode != null &&
        i.subjectCode!.isNotEmpty);

    final palette = HighlightPalette.of(_highlightTone, colors.isDark);

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          AppScaffold.buildLiquidAmbientCanvas(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Section (Only Department Info, Clean Segment Switcher)
                _buildHeader(colors, studentService),

                // Main Content (Aligned Weekly Matrix or Attractive Day Agenda)
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _viewMode == TimetableViewMode.weeklyGrid
                        ? _buildWeeklyMatrixView(allItems, colors, hasSaturdayClasses, palette)
                        : _buildDayAgendaView(allItems, colors, hasSaturdayClasses, palette),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER (CLEANED UP: ONLY DEPARTMENT DETAILS & VIEW SWITCHER)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(AppColors colors, StudentService studentService) {
    final summary = studentService.summary;
    final className = summary?.className ?? 'B.Tech IT - Year III (Sec B)';

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.glassSurfaceStrong.withValues(alpha: 0.85),
        border: Border(bottom: BorderSide(color: colors.glassBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Row with Department Subtitle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Class Schedule',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: colors.isDark ? colors.textPrimary : const Color(0xFF1E3A2E), // Adaptive title tint
                      fontFamily: 'serif',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    className,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Department Chip Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.isDark ? colors.surfaceElevated : const Color(0xFF2B1A13).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colors.isDark ? colors.border : const Color(0xFF2B1A13).withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.school_rounded, size: 14, color: colors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'IT Dept • Sem V',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // View Mode Switcher: Weekly Matrix vs Day Agenda
          Container(
            height: 38,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.glassBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSegmentButton(
                    title: 'Weekly Matrix',
                    icon: Icons.grid_view_rounded,
                    isSelected: _viewMode == TimetableViewMode.weeklyGrid,
                    onTap: () => setState(() => _viewMode = TimetableViewMode.weeklyGrid),
                    colors: colors,
                  ),
                ),
                Expanded(
                  child: _buildSegmentButton(
                    title: 'Day Agenda',
                    icon: Icons.view_agenda_rounded,
                    isSelected: _viewMode == TimetableViewMode.dayAgenda,
                    onTap: () => setState(() => _viewMode = TimetableViewMode.dayAgenda),
                    colors: colors,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required AppColors colors,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? colors.onPrimary : colors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? colors.onPrimary : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WEEKLY MATRIX VIEW (PERFECTLY ALIGNED & DYNAMIC SATURDAY ADJUSTMENT)
  // ─────────────────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────────
  // WEEKLY MATRIX VIEW (PERFECTLY ALIGNED, CAPPED CLOSURE & DYNAMIC HIGHLIGHT)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildWeeklyMatrixView(
    List<TimetableItemModel> allItems,
    AppColors colors,
    bool hasSaturdayClasses,
    HighlightPalette palette,
  ) {
    // Dynamic column list: Monday through Friday, plus Saturday if scheduled
    final List<Map<String, String>> matrixDays = [
      {'code': 'MONDAY', 'label': 'Mon'},
      {'code': 'TUESDAY', 'label': 'Tues'},
      {'code': 'WEDNESDAY', 'label': 'Wed'},
      {'code': 'THURSDAY', 'label': 'Thu'},
      {'code': 'FRIDAY', 'label': 'Fri'},
      if (hasSaturdayClasses) {'code': 'SATURDAY', 'label': 'Sat'},
    ];

    const double timeColWidth = 72.0;
    const double minDayColWidth = 118.0;
    final double totalHeight = _getTotalSlotsHeight();
    const double bottomClosureHeight = 36.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final totalCalculatedWidth = timeColWidth + (matrixDays.length * minDayColWidth);
        final bool needsHorizontalScroll = totalCalculatedWidth > availableWidth;
        final double finalDayColWidth = needsHorizontalScroll
            ? minDayColWidth
            : (availableWidth - timeColWidth) / matrixDays.length;

        final double contentWidth = needsHorizontalScroll ? totalCalculatedWidth : availableWidth;

        Widget gridContent = Column(
          children: [
            // Top Day Headers Row
            Container(
              decoration: BoxDecoration(
                color: colors.isDark ? colors.glassSurfaceStrong : const Color(0xFFF6F1EA),
                border: Border(
                  bottom: BorderSide(color: colors.isDark ? colors.divider : const Color(0xFFE2DAD0), width: 1.2),
                ),
              ),
              child: Row(
                children: [
                  // Corner spacing for time column
                  SizedBox(
                    width: timeColWidth,
                    height: 48,
                    child: Center(
                      child: Text(
                        'PERIOD',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: colors.isDark ? colors.textMuted : const Color(0xFF7A7269),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  // Day Headers (Highlighted if TODAY)
                  ...matrixDays.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final day = entry.value;
                    final isCurrent = _isToday(day['code']!);
                    final isAltColumn = idx % 2 == 1;

                    return Container(
                      width: finalDayColWidth,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? palette.headerBg
                            : (isAltColumn
                                ? (colors.isDark ? const Color(0xFF171524) : const Color(0xFFEFE8DD))
                                : (colors.isDark ? const Color(0xFF12111D) : const Color(0xFFF8F4EC))),
                        border: Border(
                          left: BorderSide(
                            color: isCurrent
                                ? palette.primary
                                : (colors.isDark ? colors.divider : const Color(0xFFE5DDD2)),
                            width: isCurrent ? 2.0 : 0.8,
                          ),
                          right: isCurrent
                              ? BorderSide(color: palette.primary, width: 2.0)
                              : BorderSide.none,
                          top: isCurrent
                              ? BorderSide(color: palette.primary, width: 3.5)
                              : BorderSide.none,
                          bottom: isCurrent
                              ? BorderSide(color: palette.primary, width: 2.5)
                              : BorderSide(color: colors.isDark ? colors.divider : const Color(0xFFE2DAD0), width: 1.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isCurrent) ...[
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: palette.primary,
                                boxShadow: [
                                  BoxShadow(
                                    color: palette.glow,
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            day['label']!,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: isCurrent
                                  ? (colors.isDark ? palette.accentLight : Colors.white)
                                  : colors.textPrimary,
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: palette.badgeBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'TODAY',
                                style: TextStyle(
                                  color: palette.badgeFg,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),

            // Grid Body + Schedule Intelligence Dock (Scrollable vertically)
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Matrix Table with Capped Bottom Closure Row
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: colors.isDark ? colors.divider : const Color(0xFFDCD2C4),
                            width: 1.5,
                          ),
                        ),
                      ),
                      child: SizedBox(
                        height: totalHeight + bottomClosureHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Time Y-Axis Column (Strictly aligned with rows, no clipping)
                            SizedBox(
                              width: timeColWidth,
                              child: Column(
                                children: [
                                  ..._slots.map((slot) {
                                    if (slot.isBreak) {
                                      return Container(
                                        height: slot.height,
                                        alignment: Alignment.center,
                                        child: Text(
                                          slot.periodNumber == -1 ? 'BREAK' : 'LUNCH',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                            color: colors.textMuted,
                                          ),
                                        ),
                                      );
                                    }

                                    final startM = _parseTimeToMinutes(slot.startTime);
                                    final endM = _parseTimeToMinutes(slot.endTime);
                                    final now = DateTime.now();
                                    final nowM = now.hour * 60 + now.minute;
                                    final isRealLive = nowM >= startM && nowM <= endM;
                                    final hasAnyRealLive = _hasAnyRealActivePeriod();
                                    final isSlotLive = isRealLive || (_simulateLiveClass && !hasAnyRealLive && slot.periodNumber == 2);

                                    return Container(
                                      height: slot.height,
                                      padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
                                      alignment: Alignment.centerRight,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: (colors.isDark ? colors.divider : const Color(0xFFE5DDD2)).withValues(alpha: 0.6),
                                            width: 0.8,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: isSlotLive
                                                  ? palette.badgeBg
                                                  : (colors.isDark ? colors.surfaceElevated : const Color(0xFF2B1A13).withValues(alpha: 0.08)),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              slot.label,
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: isSlotLive ? palette.badgeFg : colors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            slot.startTime,
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: isSlotLive ? FontWeight.w800 : FontWeight.w600,
                                              color: isSlotLive ? palette.primary : colors.textSecondary,
                                            ),
                                          ),
                                          Text(
                                            slot.endTime,
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w500,
                                              color: colors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),

                                  // Bottom Closure Cell for Time Column
                                  Container(
                                    height: bottomClosureHeight,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: colors.isDark ? colors.surfaceElevated : const Color(0xFFE8DFD2),
                                      border: Border(
                                        bottom: BorderSide(color: colors.isDark ? colors.divider : const Color(0xFFDCD2C4), width: 1.2),
                                        right: BorderSide(color: colors.isDark ? colors.divider : const Color(0xFFE5DDD2), width: 0.8),
                                      ),
                                    ),
                                    child: Text(
                                      'LOAD',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: colors.textMuted,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Day Columns
                            ...matrixDays.asMap().entries.map((entry) {
                              final colIdx = entry.key;
                              final day = entry.value;
                              final dayCode = day['code']!;
                              final isAltColumn = colIdx % 2 == 1;
                              final isCurrentDay = _isToday(dayCode);

                              // Items for this day
                              final dayItems = allItems.where((i) {
                                return i.dayOfWeek.toUpperCase() == dayCode.toUpperCase();
                              }).toList();

                              return Container(
                                width: finalDayColWidth,
                                height: totalHeight + bottomClosureHeight,
                                decoration: BoxDecoration(
                                  color: isCurrentDay
                                      ? palette.columnBg
                                      : (isAltColumn
                                          ? (colors.isDark ? const Color(0xFF171524) : const Color(0xFFEFE8DD))
                                          : (colors.isDark ? const Color(0xFF12111D) : const Color(0xFFF8F4EC))),
                                  border: Border(
                                    left: BorderSide(
                                      color: isCurrentDay
                                          ? palette.primary.withValues(alpha: 0.6)
                                          : (colors.isDark ? colors.divider : const Color(0xFFE5DDD2)),
                                      width: isCurrentDay ? 1.8 : 0.8,
                                    ),
                                    right: isCurrentDay
                                        ? BorderSide(color: palette.primary.withValues(alpha: 0.6), width: 1.8)
                                        : BorderSide.none,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    // Background Break Bars & Grid Dividers
                                    ..._slots.asMap().entries.map((slotEntry) {
                                      final sIdx = slotEntry.key;
                                      final slot = slotEntry.value;
                                      final slotTop = _getSlotTop(sIdx);

                                      if (slot.isBreak) {
                                        return Positioned(
                                          top: slotTop,
                                          left: 0,
                                          right: 0,
                                          height: slot.height,
                                          child: Container(
                                            color: colors.isDark ? const Color(0xFF232032) : const Color(0xFFE8DFD2),
                                            alignment: Alignment.center,
                                            child: Text(
                                              slot.periodNumber == -1 ? '☕ TEA BREAK' : '🍽️ LUNCH BREAK',
                                              style: TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.6,
                                                color: colors.isDark ? colors.textSecondary : const Color(0xFF7A7065).withValues(alpha: 0.85),
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      return Positioned(
                                        top: slotTop + slot.height,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          height: 0.8,
                                          color: (colors.isDark ? colors.divider : const Color(0xFFE5DDD2)).withValues(alpha: 0.7),
                                        ),
                                      );
                                    }).toList(),

                                    // Class Cards (Strictly Aligned with Period Slots)
                                    ...dayItems.map((item) {
                                      return _buildMatrixCard(
                                        item: item,
                                        dayCode: dayCode,
                                        palette: palette,
                                      );
                                    }).toList(),

                                    // Bottom Closure Row Cell for this Day Column
                                    Positioned(
                                      top: totalHeight,
                                      left: 0,
                                      right: 0,
                                      height: bottomClosureHeight,
                                      child: Container(
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isCurrentDay
                                              ? palette.primary.withValues(alpha: 0.12)
                                              : (colors.isDark ? const Color(0xFF171524) : const Color(0xFFEAE2D6)),
                                          border: Border(
                                            top: BorderSide(color: colors.isDark ? colors.divider : const Color(0xFFE5DDD2), width: 0.8),
                                            bottom: BorderSide(
                                              color: isCurrentDay ? palette.primary : (colors.isDark ? colors.divider : const Color(0xFFDCD2C4)),
                                              width: isCurrentDay ? 2.2 : 1.2,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          isCurrentDay
                                              ? '● ${dayItems.length} Classes'
                                              : '${dayItems.length} Classes',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: isCurrentDay ? FontWeight.w900 : FontWeight.w700,
                                            color: isCurrentDay ? palette.primary : colors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),

                    // 2. The Unique "Schedule Intelligence & Live Rhythm Dock"
                    _buildScheduleIntelligenceDock(
                      allItems: allItems,
                      colors: colors,
                      hasSaturdayClasses: hasSaturdayClasses,
                      contentWidth: contentWidth,
                      palette: palette,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

        if (needsHorizontalScroll) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: totalCalculatedWidth,
              child: gridContent,
            ),
          );
        }

        return gridContent;
      },
    );
  }

  Widget _buildMatrixCard({
    required TimetableItemModel item,
    required String dayCode,
    required HighlightPalette palette,
  }) {
    final periodNum = item.periodNumber ?? 1;
    final slotIdx = _mapPeriodToSlotIndex(periodNum);
    final double topOffset = _getSlotTop(slotIdx) + 3.0;

    // Multi-period lab or single lecture calculation
    final int span = item.span.clamp(1, 3);
    double cardHeight = 0;
    for (int i = 0; i < span; i++) {
      final currentSlotIdx = slotIdx + i;
      if (currentSlotIdx < _slots.length) {
        cardHeight += _slots[currentSlotIdx].height;
      }
    }
    cardHeight = cardHeight - 6.0;

    final cardColor = _getCardColor(item);
    final isCurrentPeriod = _isItemActiveNow(item);
    final isTodayColumn = _isToday(dayCode);

    return Positioned(
      top: topOffset,
      left: 3.5,
      right: 3.5,
      height: cardHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showClassDetailsModal(item),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCurrentPeriod
                    ? palette.cardBorder
                    : (isTodayColumn
                        ? palette.primary.withValues(alpha: 0.28)
                        : Colors.white.withValues(alpha: 0.14)),
                width: isCurrentPeriod ? 2.2 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isCurrentPeriod
                      ? palette.glow
                      : (isTodayColumn
                          ? Colors.black.withValues(alpha: 0.20)
                          : Colors.black.withValues(alpha: 0.16)),
                  blurRadius: isCurrentPeriod ? 12 : 4,
                  spreadRadius: isCurrentPeriod ? 1.5 : 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCurrentPeriod) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: palette.badgeBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded, color: palette.badgeFg, size: 10),
                              const SizedBox(width: 2),
                              Text(
                                'LIVE NOW',
                                style: TextStyle(
                                  color: palette.badgeFg,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        item.subjectName ?? 'Class',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: span > 1 ? 11.5 : 10.5,
                          fontWeight: FontWeight.bold,
                          height: 1.15,
                        ),
                        maxLines: span > 1 ? 4 : 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (span > 1 && item.roomNo != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.roomNo!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleIntelligenceDock({
    required List<TimetableItemModel> allItems,
    required AppColors colors,
    required bool hasSaturdayClasses,
    required double contentWidth,
    required HighlightPalette palette,
  }) {
    final todayName = _getCurrentWeekdayName();
    final todayItems = allItems.where((i) => i.dayOfWeek.toUpperCase() == todayName).toList();

    TimetableItemModel? activeItem;
    for (final item in todayItems) {
      if (_isItemActiveNow(item)) {
        activeItem = item;
        break;
      }
    }
    activeItem ??= todayItems.isNotEmpty ? todayItems.first : null;

    return Container(
      width: contentWidth,
      margin: const EdgeInsets.fromLTRB(10, 14, 10, 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.glassSurfaceStrong,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.glassBorderStrong,
          width: 1.2,
        ),
        boxShadow: AppGlass.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Academic Pulse & Palette Switcher & Simulation Switch
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.primary,
                      boxShadow: [
                        BoxShadow(color: palette.glow, blurRadius: 6, spreadRadius: 1),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'DAILY SCHEDULE INTELLIGENCE',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Simulation Switch
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _simulateLiveClass = !_simulateLiveClass;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: _simulateLiveClass
                            ? palette.primary.withValues(alpha: 0.15)
                            : colors.glassSurfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _simulateLiveClass ? palette.primary : colors.glassBorderStrong,
                          width: 1.1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 13,
                            color: _simulateLiveClass ? palette.primary : colors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _simulateLiveClass ? 'Live Highlight ON' : 'Live Highlight Auto',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _simulateLiveClass ? palette.primary : colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Hero Live / Next Period Card
          if (activeItem != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: palette.dockGradient,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.isDark ? palette.primary.withValues(alpha: 0.45) : palette.cardBorder,
                  width: 1.3,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: palette.badgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_circle_fill_rounded, size: 12, color: palette.badgeFg),
                            const SizedBox(width: 4),
                            Text(
                              'PERIOD ${activeItem.periodNumber ?? 2} • LIVE NOW',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: palette.badgeFg,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${activeItem.startTime ?? "09:40 AM"} – ${activeItem.endTime ?? "10:35 AM"}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: palette.accentLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    activeItem.subjectName ?? 'Computer Networks',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 14, color: colors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        activeItem.facultyName ?? 'Dr. K. Senthil Kumar',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.room_outlined, size: 14, color: colors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        activeItem.roomNo ?? 'Hall 301',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      height: 4,
                      color: colors.isDark ? Colors.white10 : Colors.black12,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.65,
                        child: Container(color: palette.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),

          // Academic Matrix Color Guide
          Text(
            'ACADEMIC MATRIX COLOR GUIDE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: colors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildRhythmTag('Core Lectures', const Color(0xFF2E2724), colors),
              _buildRhythmTag('Practical & Labs', const Color(0xFF0B6A4E), colors),
              _buildRhythmTag('Seminars & Ethics', const Color(0xFF284638), colors),
              _buildRhythmTag('Mentoring & Advisory', const Color(0xFF535D6C), colors),
              _buildRhythmTag('Tea / Lunch Break', const Color(0xFF8A6D3B), colors),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.calendar_today_rounded,
                  label: 'Jump to Today',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Today is ${_getCurrentWeekdayName()} • Wednesday column highlighted'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  colors: colors,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.file_download_outlined,
                  label: 'Export Timetable',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Timetable exported as PDF successfully!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  colors: colors,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRhythmTag(String label, Color color, AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.glassSurfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.glassBorderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required AppColors colors,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.glassSurfaceSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.glassBorderStrong),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: colors.textPrimary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DAY AGENDA VIEW (HIGHLY ATTRACTIVE, MODERNIZED & ENHANCED)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDayAgendaView(
    List<TimetableItemModel> allItems,
    AppColors colors,
    bool hasSaturdayClasses,
    HighlightPalette palette,
  ) {
    // Filter items for the selected day
    final dayItems = allItems.where((item) {
      return item.dayOfWeek.toUpperCase() == _selectedDay.toUpperCase();
    }).toList();

    dayItems.sort((a, b) {
      if (a.periodNumber != null && b.periodNumber != null) {
        return a.periodNumber!.compareTo(b.periodNumber!);
      }
      final aStart = _parseTimeToMinutes(a.startTime);
      final bStart = _parseTimeToMinutes(b.startTime);
      return aStart.compareTo(bStart);
    });

    final isTodaySelected = _isToday(_selectedDay);

    return Column(
      children: [
        // Day Tabs Switcher (Sleek Apple Liquid Glass Bar)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.glassSurfaceStrong,
            border: Border(bottom: BorderSide(color: colors.glassBorder)),
          ),
          child: Row(
            children: List.generate(_weekdays.length, (idx) {
              final dayCode = _weekdays[idx];
              final label = _dayLabels[idx];
              final isSelected = dayCode.toUpperCase() == _selectedDay.toUpperCase();
              final isCurrentDay = _isToday(dayCode);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () => setState(() => _selectedDay = dayCode),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.primary
                            : (isCurrentDay ? colors.heroChip : colors.glassSurfaceSubtle),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? colors.primary
                              : (isCurrentDay ? colors.primary : colors.glassBorder),
                          width: isCurrentDay ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? colors.onPrimary
                                  : (isCurrentDay ? colors.primary : colors.textSecondary),
                            ),
                          ),
                          if (isCurrentDay) ...[
                            const SizedBox(height: 2),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? colors.onPrimary : palette.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        // Day Banner Overview Card (Attractive Editorial Hero Pill)
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.glassSurfaceStrong,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      _selectedDay,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (isTodaySelected) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: palette.badgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'TODAY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: palette.badgeFg,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${dayItems.length} Period${dayItems.length == 1 ? "" : "s"} Scheduled',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Period Cards Stream (with Interleaved Break Cards)
        Expanded(
          child: dayItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedDay.toUpperCase() == 'SUNDAY'
                              ? Icons.weekend_rounded
                              : Icons.event_busy_outlined,
                          size: 48,
                          color: colors.textMuted,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _selectedDay.toUpperCase() == 'SUNDAY'
                              ? 'Sunday • Weekend Rest'
                              : (_selectedDay.toUpperCase() == 'SATURDAY' && !hasSaturdayClasses
                                  ? 'Saturday Off • No Academic Classes'
                                  : 'No Classes Scheduled for $_selectedDay'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedDay.toUpperCase() == 'SUNDAY'
                              ? 'Enjoy your weekend! Regular lectures resume on Monday morning.'
                              : (_selectedDay.toUpperCase() == 'SATURDAY' && !hasSaturdayClasses
                                  ? 'This Saturday is a non-working weekend according to the college calendar.'
                                  : 'No periods are configured for this day in your timetable.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  itemCount: dayItems.length,
                  itemBuilder: (context, index) {
                    final item = dayItems[index];
                    final status = _determinePeriodStatus(item, dayItems);

                    final bool showTeaBreakBefore = item.periodNumber == 3;
                    final bool showLunchBreakBefore = item.periodNumber == 5;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showTeaBreakBefore)
                          _buildAgendaBreakBanner(
                            icon: Icons.coffee_rounded,
                            title: 'TEA BREAK (10:35 AM - 10:55 AM)',
                            subtitle: '20 Mins Short Recess',
                            colors: colors,
                          ),
                        if (showLunchBreakBefore)
                          _buildAgendaBreakBanner(
                            icon: Icons.restaurant_rounded,
                            title: 'LUNCH BREAK (12:45 PM - 01:45 PM)',
                            subtitle: '60 Mins Dining Recess',
                            colors: colors,
                          ),
                        _buildPeriodAgendaCard(item, status, colors, palette),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAgendaBreakBanner({
    required IconData icon,
    required String title,
    required String subtitle,
    required AppColors colors,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.isDark ? colors.surfaceElevated : const Color(0xFFEBE4D8).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.isDark ? colors.glassBorderStrong : const Color(0xFFDDD3C4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.isDark ? colors.accent : const Color(0xFF6B5F50)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodAgendaCard(
    TimetableItemModel item,
    PeriodClassStatus status,
    AppColors colors,
    HighlightPalette palette,
  ) {
    Color cardBorderColor = colors.glassBorder;
    Color periodBadgeBg = _getCardColor(item);
    final isLive = status == PeriodClassStatus.activeNow;
    Widget? statusBadge;

    if (isLive) {
      cardBorderColor = palette.cardBorder;
      periodBadgeBg = palette.primary;
      statusBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: palette.badgeBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded, color: palette.badgeFg, size: 14),
            const SizedBox(width: 2),
            Text(
              'CURRENT CLASS',
              style: TextStyle(color: palette.badgeFg, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    } else if (status == PeriodClassStatus.upcoming) {
      cardBorderColor = colors.warning;
      statusBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colors.warningBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.warning),
        ),
        child: Text(
          'UPCOMING',
          style: TextStyle(color: colors.warning, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    } else if (status == PeriodClassStatus.completed) {
      statusBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          'COMPLETED ✓',
          style: TextStyle(color: colors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    }

    final timeDisplay = (item.startTime != null && item.endTime != null)
        ? '${item.startTime} - ${item.endTime}'
        : 'Timing not specified';

    return GlassCard(
      variant: isLive ? GlassCardVariant.elevated : GlassCardVariant.standard,
      enableBlur: true,
      blur: 16,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      borderColor: cardBorderColor,
      borderWidth: isLive ? 2.0 : 1.0,
      padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
      child: InkWell(
        onTap: () => _showClassDetailsModal(item),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period Number Badge
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: periodBadgeBg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: isLive
                        ? palette.glow
                        : periodBadgeBg.withValues(alpha: 0.3),
                    blurRadius: isLive ? 10 : 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  item.periodNumber != null ? 'P${item.periodNumber}' : '•',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Period Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.subjectName ?? 'Class Session',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (statusBadge != null) statusBadge,
                    ],
                  ),
                  const SizedBox(height: 5),

                  if (item.subjectCode != null && item.subjectCode!.isNotEmpty) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.subjectCode!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: colors.primary,
                            ),
                          ),
                        ),
                        if (item.roomNo != null) ...[
                          const SizedBox(width: 8),
                          Row(
                            children: [
                              Icon(Icons.meeting_room_outlined, size: 13, color: colors.textMuted),
                              const SizedBox(width: 3),
                              Text(
                                item.roomNo!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],

                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 14, color: colors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        timeDisplay,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isLive ? FontWeight.w700 : FontWeight.w500,
                          color: isLive ? palette.primary : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 14, color: colors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.facultyName ?? 'Faculty Assignment Pending',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
