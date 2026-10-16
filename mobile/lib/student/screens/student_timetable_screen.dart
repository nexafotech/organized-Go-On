import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/student_model.dart';
import '../../services/student_service.dart';
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

class TimetableColorPair {
  final Color bg;
  final Color fg;

  const TimetableColorPair({required this.bg, required this.fg});
}

class _MergedMatrixItem {
  final TimetableItemModel item;
  final int startSlotIndex;
  final int span;
  final double top;
  final double height;

  _MergedMatrixItem({
    required this.item,
    required this.startSlotIndex,
    required this.span,
    required this.top,
    required this.height,
  });
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
  final DateTime? simulatedTime;

  const StudentTimetableScreen({
    Key? key,
    this.simulatedTime,
  }) : super(key: key);

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
    ScheduleSlotConfig(periodNumber: 1, label: 'P1', startTime: '08:45 AM', endTime: '09:40 AM', height: 58.0),
    ScheduleSlotConfig(periodNumber: 2, label: 'P2', startTime: '09:40 AM', endTime: '10:35 AM', height: 58.0),
    ScheduleSlotConfig(periodNumber: -1, label: 'TEA BREAK', startTime: '10:35 AM', endTime: '10:55 AM', isBreak: true, height: 28.0),
    ScheduleSlotConfig(periodNumber: 3, label: 'P3', startTime: '10:55 AM', endTime: '11:50 AM', height: 58.0),
    ScheduleSlotConfig(periodNumber: 4, label: 'P4', startTime: '11:50 AM', endTime: '12:45 PM', height: 58.0),
    ScheduleSlotConfig(periodNumber: -2, label: 'LUNCH BREAK', startTime: '12:45 PM', endTime: '01:45 PM', isBreak: true, height: 28.0),
    ScheduleSlotConfig(periodNumber: 5, label: 'P5', startTime: '01:45 PM', endTime: '02:40 PM', height: 58.0),
    ScheduleSlotConfig(periodNumber: 6, label: 'P6', startTime: '02:40 PM', endTime: '03:30 PM', height: 58.0),
    ScheduleSlotConfig(periodNumber: 7, label: 'P7', startTime: '03:30 PM', endTime: '04:20 PM', height: 58.0),
  ];

  TimetableViewMode _viewMode = TimetableViewMode.dayAgenda;
  late String _selectedDay;
  String? _selectedCardPeriodKey;
  TimetableHighlightTone _highlightTone = TimetableHighlightTone.sapphireIndigo;

  Timer? _liveClockTimer;
  late DateTime _currentTime;

  DateTime get _now => widget.simulatedTime ?? _currentTime;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _selectedDay = _getInitialWeekday();
    _startLiveTicker();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final studentService = Provider.of<StudentService>(context, listen: false);
      if (studentService.timetable.isEmpty) {
        studentService.fetchTimetable();
      }
    });
  }

  @override
  void dispose() {
    _liveClockTimer?.cancel();
    super.dispose();
  }

  void _startLiveTicker() {
    if (widget.simulatedTime != null) return;
    _liveClockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      final prevWeekday = _getCurrentWeekdayName(_currentTime);
      final newNow = DateTime.now();
      final newWeekday = _getCurrentWeekdayName(newNow);

      setState(() {
        _currentTime = newNow;
        // If viewing today when midnight rolls over, update to the new today
        if (_selectedDay == prevWeekday) {
          _selectedDay = newNow.weekday == DateTime.sunday ? 'MONDAY' : newWeekday;
        }
      });
    });
  }

  String _getCurrentWeekdayName([DateTime? dt]) {
    final now = dt ?? _now;
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

  String _getInitialWeekday() {
    final now = _now;
    if (now.weekday == DateTime.sunday) {
      return 'MONDAY'; // Colleges are closed on Sunday, default to first day of academic week
    }
    return _getCurrentWeekdayName(now);
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

  bool _isItemActiveNow(TimetableItemModel item) {
    if (!_isToday(item.dayOfWeek)) return false;
    final startMin = _parseTimeToMinutes(item.startTime);
    final endMin = _parseTimeToMinutes(item.endTime);
    if (startMin == -1 || endMin == -1) return false;
    final now = _now;
    final nowMin = now.hour * 60 + now.minute;
    return nowMin >= startMin && nowMin < endMin;
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

    final now = _now;
    final nowMinutes = now.hour * 60 + now.minute;

    if (nowMinutes >= startMinutes && nowMinutes < endMinutes) {
      return PeriodClassStatus.activeNow;
    } else if (nowMinutes >= endMinutes) {
      return PeriodClassStatus.completed;
    } else if (nowMinutes < startMinutes) {
      return PeriodClassStatus.upcoming;
    }

    return PeriodClassStatus.none;
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
    final colorPair = _getPastelColorPair(item, colors.isDark);
    final cardColor = colorPair.bg;
    final fgColor = colors.isDark ? Colors.white : colorPair.fg;
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
                  border: Border.all(color: fgColor.withValues(alpha: 0.2)),
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
                            color: fgColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.subjectCode ?? 'COURSE',
                            style: TextStyle(
                              color: fgColor,
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
                              color: fgColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${item.span} Periods Span',
                              style: TextStyle(
                                color: fgColor,
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
                      style: TextStyle(
                        color: fgColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.dayOfWeek} • ${item.startTime ?? ""} - ${item.endTime ?? ""}',
                      style: TextStyle(
                        color: fgColor.withValues(alpha: 0.85),
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
    final timetable = studentService.timetable;

    if (studentService.isLoading && timetable.isEmpty) {
      return Scaffold(
        backgroundColor: colors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (studentService.errorMessage != null && timetable.isEmpty) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.errorBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.cloud_off_rounded, size: 48, color: colors.error),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Timetable Unavailable',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  studentService.errorMessage ?? 'Unable to retrieve timetable from server.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  text: 'Retry',
                  icon: Icons.refresh_rounded,
                  onPressed: () => studentService.fetchTimetable(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final allItems = timetable;

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
          AppScaffold.buildLiquidAmbientCanvas(context),
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
  // HEADER (MATCHING REFERENCE DESIGN: CLEAN CLASS SCHEDULE & VIEW TOGGLE)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(AppColors colors, StudentService studentService) {
    final summary = studentService.summary;
    final className = summary?.className ?? 'II Year CSE Cyber Security · Class 1';

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.glassSurfaceStrong.withValues(alpha: 0.85),
        border: Border(bottom: BorderSide(color: colors.glassBorder.withValues(alpha: 0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Class Schedule',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  className,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _viewMode == TimetableViewMode.dayAgenda ? 'Weekly Matrix View' : 'Day Agenda View',
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: colors.isDark ? colors.surfaceElevated : const Color(0xFFEBE7DF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _viewMode == TimetableViewMode.dayAgenda ? Icons.grid_view_rounded : Icons.view_agenda_rounded,
                size: 20,
                color: colors.textPrimary,
              ),
            ),
            onPressed: () => setState(() {
              _viewMode = _viewMode == TimetableViewMode.dayAgenda
                  ? TimetableViewMode.weeklyGrid
                  : TimetableViewMode.dayAgenda;
            }),
          ),
        ],
      ),
    );
  }


  // ─────────────────────────────────────────────────────────────────────────
  // WEEKLY MATRIX VIEW (REBUILT TO EXACTLY MATCH REFERENCE IMAGE 1)
  // ─────────────────────────────────────────────────────────────────────────

  static const double _kBreakHeight = 28.0;
  static const double _kTimeColWidth = 46.0;
  static const double _kMinDayColWidth = 52.0;

  Widget _buildWeeklyMatrixView(
    List<TimetableItemModel> allItems,
    AppColors colors,
    bool hasSaturdayClasses,
    HighlightPalette palette,
  ) {
    // 6 academic days: Mon through Sat matching Image 1
    final List<Map<String, dynamic>> matrixDays = [
      {'code': 'MONDAY', 'label': 'Mon', 'offset': 0},
      {'code': 'TUESDAY', 'label': 'Tue', 'offset': 1},
      {'code': 'WEDNESDAY', 'label': 'Wed', 'offset': 2},
      {'code': 'THURSDAY', 'label': 'Thu', 'offset': 3},
      {'code': 'FRIDAY', 'label': 'Fri', 'offset': 4},
      {'code': 'SATURDAY', 'label': 'Sat', 'offset': 5},
    ];

    final double totalHeight = _getTotalSlotsHeight();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final double totalMinNeeded = _kTimeColWidth + (matrixDays.length * _kMinDayColWidth) + 16.0;
        final bool needsHorizontalScroll = totalMinNeeded > availableWidth;

        final double dayColWidth = needsHorizontalScroll
            ? _kMinDayColWidth
            : (availableWidth - _kTimeColWidth - 16.0) / matrixDays.length;

        final double tableWidth = _kTimeColWidth + (matrixDays.length * dayColWidth);

        Widget matrixContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Day Headers Row (Mon 12, Tue 13, Wed 14 [Blue Pill], Thu 15, Fri 16, Sat 17)
            _buildMatrixDayHeadersRow(matrixDays, dayColWidth, colors),

            const SizedBox(height: 10),

            // 2. Matrix Table Body (Time Column, 6 Day Columns with pastel cards, Break bars)
            _buildMatrixBody(matrixDays, allItems, dayColWidth, totalHeight, colors),
          ],
        );

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 110),
          child: needsHorizontalScroll
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: tableWidth,
                    child: matrixContent,
                  ),
                )
              : matrixContent,
        );
      },
    );
  }

  Widget _buildMatrixDayHeadersRow(
    List<Map<String, dynamic>> matrixDays,
    double dayColWidth,
    AppColors colors,
  ) {
    return Row(
      children: [
        // Left spacer matching the time rail width
        const SizedBox(width: _kTimeColWidth),

        // Day Headers
        ...matrixDays.map((day) {
          final dayCode = day['code'] as String;
          final dayLabel = day['label'] as String;
          final offset = day['offset'] as int;
          final dateNum = _getDateForWeekday(offset).day.toString();
          final bool isToday = _isToday(dayCode);

          return SizedBox(
            width: dayColWidth,
            child: Center(
              child: isToday
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.isDark ? colors.accent : colors.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (colors.isDark ? colors.accent : colors.primary).withValues(alpha: 0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dayLabel,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            dateNum,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dayLabel,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: colors.isDark ? Colors.white : const Color(0xFF1E2430),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          dateNum,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colors.isDark ? colors.textMuted : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildMatrixBody(
    List<Map<String, dynamic>> matrixDays,
    List<TimetableItemModel> allItems,
    double dayColWidth,
    double totalHeight,
    AppColors colors,
  ) {
    final double daysGridWidth = matrixDays.length * dayColWidth;
    final int teaBreakIdx = _slots.indexWhere((s) => s.periodNumber == -1);
    final int lunchBreakIdx = _slots.indexWhere((s) => s.periodNumber == -2);

    final double teaBreakTop = teaBreakIdx != -1 ? _getSlotTop(teaBreakIdx) : 0;
    final double lunchBreakTop = lunchBreakIdx != -1 ? _getSlotTop(lunchBreakIdx) : 0;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          // 1. Time Rail on the Left
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _kTimeColWidth,
            child: Stack(
              children: [
                ..._slots.asMap().entries.map((entry) {
                  final slot = entry.value;
                  if (slot.isBreak) return const SizedBox.shrink();
                  final top = _getSlotTop(entry.key);

                  return Positioned(
                    top: top,
                    left: 0,
                    right: 4,
                    height: slot.height,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          slot.label, // P1, P2, etc.
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: colors.isDark ? colors.textPrimary : const Color(0xFF374151),
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatStartTime(slot.startTime), // 08:45, 09:40, etc.
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: colors.isDark ? colors.textMuted : const Color(0xFF9CA3AF),
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          // 2. Day Columns with Background Highlights and Pastel Subject Cards
          ...matrixDays.asMap().entries.map((entry) {
            final colIdx = entry.key;
            final day = entry.value;
            final dayCode = day['code'] as String;
            final bool isToday = _isToday(dayCode);
            final double left = _kTimeColWidth + (colIdx * dayColWidth);

            // Filter items for this day
            final dayItems = allItems.where((i) {
              return i.dayOfWeek.toUpperCase() == dayCode.toUpperCase();
            }).toList();

            final mergedItems = _prepareMergedDayItems(dayItems);

            return Positioned(
              left: left,
              top: 0,
              width: dayColWidth,
              height: totalHeight,
              child: Stack(
                children: [
                  // Today column background tint
                  if (isToday)
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: (colors.isDark ? colors.accent : colors.primary).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),

                  // Pastel Subject Cards
                  ...mergedItems.map((merged) {
                    return _buildMatrixCard(
                      merged: merged,
                      dayCode: dayCode,
                      dayColWidth: dayColWidth,
                      isToday: isToday,
                      colors: colors,
                    );
                  }).toList(),
                ],
              ),
            );
          }),

          // 3. Break Dividers Spanning Across All 6 Days
          if (teaBreakIdx != -1)
            Positioned(
              left: _kTimeColWidth + 2.0,
              top: teaBreakTop + 2.0,
              width: daysGridWidth - 4.0,
              height: _kBreakHeight - 4.0,
              child: _buildMatrixBreakBar('Tea break', colors),
            ),

          if (lunchBreakIdx != -1)
            Positioned(
              left: _kTimeColWidth + 2.0,
              top: lunchBreakTop + 2.0,
              width: daysGridWidth - 4.0,
              height: _kBreakHeight - 4.0,
              child: _buildMatrixBreakBar('Lunch', colors),
            ),
        ],
      ),
    );
  }

  Widget _buildMatrixBreakBar(String title, AppColors colors) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF9FAFB).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colors.isDark ? colors.border.withValues(alpha: 0.5) : const Color(0xFFD1D5DB).withValues(alpha: 0.7),
          width: 0.9,
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: colors.isDark ? colors.textMuted : const Color(0xFF6B7280),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildMatrixCard({
    required _MergedMatrixItem merged,
    required String dayCode,
    required double dayColWidth,
    required bool isToday,
    required AppColors colors,
  }) {
    final item = merged.item;
    final colorPair = _getPastelColorPair(item, colors.isDark);
    final displayCode = _getCardDisplayCode(item);
    final isLab = _isItemLab(item);
    final isLiveNow = isToday && _isItemActiveNow(item);
    final cardKey = '${dayCode}_${item.periodNumber}';
    final isFocused = _selectedCardPeriodKey == cardKey;

    final double cardTop = merged.top + 2.5;
    final double cardHeight = merged.height - 5.0;

    return Positioned(
      top: cardTop,
      left: 2.5,
      right: 2.5,
      height: cardHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedCardPeriodKey = cardKey;
            });
            _showClassDetailsModal(item);
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
            decoration: BoxDecoration(
              color: colorPair.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isLiveNow
                    ? (colors.isDark ? colors.accent : colors.primary)
                    : (isFocused
                        ? (colors.isDark ? colors.accent : colors.primary)
                        : Colors.transparent),
                width: isLiveNow ? 2.0 : (isFocused ? 1.5 : 1.0),
              ),
              boxShadow: isLiveNow
                  ? [
                      BoxShadow(
                        color: (colors.isDark ? colors.accent : colors.primary).withValues(alpha: 0.25),
                        blurRadius: 6,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayCode,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: merged.span > 1 ? 13.5 : 12.5,
                      fontWeight: FontWeight.w800,
                      color: colorPair.fg,
                      height: 1.1,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                  if (isLab && !displayCode.toLowerCase().contains('lab')) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Lab',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: colorPair.fg,
                        height: 1.0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SUBJECT PASTEL COLOR & MERGING HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  String _getCardDisplayCode(TimetableItemModel item) {
    if (item.subjectCode != null && item.subjectCode!.isNotEmpty) {
      final clean = item.subjectCode!.trim();
      if (clean.toUpperCase().startsWith('ACE')) return 'ACE';
      if (clean.toUpperCase().contains('JAVA')) return 'Java';
      return clean;
    }
    final name = item.subjectName ?? 'Class';
    if (name.toLowerCase().contains('discrete mathematics')) return 'DMC';
    if (name.toLowerCase().contains('data structures')) return 'DS';
    if (name.toLowerCase().contains('object oriented')) return 'OOPS';
    if (name.toLowerCase().contains('digital principles')) return 'DPCO';
    if (name.toLowerCase().contains('fundamentals of data science')) return 'FDS';
    if (name.toLowerCase().contains('indian knowledge')) return 'IKS';
    if (name.toLowerCase().contains('artificial intelligence')) return 'AI';
    if (name.toLowerCase().contains('computer networks')) return 'CN';
    if (name.toLowerCase().contains('database')) return 'DBMS';

    final parts = name.split(' ');
    if (parts.length == 1) return parts[0];
    return parts.map((p) => p.isNotEmpty ? p[0] : '').take(4).join();
  }

  bool _isItemLab(TimetableItemModel item) {
    if (item.type?.toLowerCase() == 'lab') return true;
    if (item.subjectName?.toLowerCase().contains('lab') == true) return true;
    if (item.subjectCode?.toLowerCase().contains('lab') == true) return true;
    return false;
  }

  TimetableColorPair _getPastelColorPair(TimetableItemModel item, bool isDark) {
    final code = _getCardDisplayCode(item).toUpperCase();
    final name = (item.subjectName ?? '').toUpperCase();

    Color bg;
    Color fg;

    if (code.contains('FDS')) {
      bg = const Color(0xFFE2EDFE); // Soft Blue
      fg = const Color(0xFF1E56A0);
    } else if (code.contains('DMC')) {
      bg = const Color(0xFFFEE8D8); // Soft Warm Peach
      fg = const Color(0xFFA0521D);
    } else if (code.contains('OOP')) {
      bg = const Color(0xFFFDE5EF); // Soft Pink / Rose
      fg = const Color(0xFFB82668);
    } else if (code.contains('DPCO')) {
      bg = const Color(0xFFEEE6FC); // Soft Lavender
      fg = const Color(0xFF5E35B1);
    } else if (code == 'DS' || code.startsWith('DS')) {
      bg = const Color(0xFFFFF4C7); // Soft Honey Yellow
      fg = const Color(0xFF8B6914);
    } else if (code.contains('IKS')) {
      bg = const Color(0xFFEBF0DB); // Soft Sage Olive
      fg = const Color(0xFF45672B);
    } else if (code.contains('JAVA') || code.contains('ACE')) {
      bg = const Color(0xFFE0F3EE); // Soft Mint Teal
      fg = const Color(0xFF136F52);
    } else if (code.contains('LIB') || code.contains('IIC') || code.contains('TWM') || code.contains('DAH') || code.contains('DAA') || code.contains('AI') || code.contains('CN') || code.contains('DBMS')) {
      bg = const Color(0xFFECEFF1); // Soft Slate Gray
      fg = const Color(0xFF455A64);
    } else {
      final fallbackPairs = [
        const TimetableColorPair(bg: Color(0xFFE2EDFE), fg: Color(0xFF1E56A0)),
        const TimetableColorPair(bg: Color(0xFFFEE8D8), fg: Color(0xFFA0521D)),
        const TimetableColorPair(bg: Color(0xFFFDE5EF), fg: Color(0xFFB82668)),
        const TimetableColorPair(bg: Color(0xFFEEE6FC), fg: Color(0xFF5E35B1)),
        const TimetableColorPair(bg: Color(0xFFFFF4C7), fg: Color(0xFF8B6914)),
        const TimetableColorPair(bg: Color(0xFFEBF0DB), fg: Color(0xFF45672B)),
        const TimetableColorPair(bg: Color(0xFFE0F3EE), fg: Color(0xFF136F52)),
        const TimetableColorPair(bg: Color(0xFFECEFF1), fg: Color(0xFF455A64)),
      ];
      final hash = (code.hashCode ^ name.hashCode).abs();
      final pair = fallbackPairs[hash % fallbackPairs.length];
      bg = pair.bg;
      fg = pair.fg;
    }

    if (isDark) {
      return TimetableColorPair(
        bg: bg.withValues(alpha: 0.18),
        fg: Color.lerp(fg, Colors.white, 0.5) ?? fg,
      );
    }

    return TimetableColorPair(bg: bg, fg: fg);
  }

  bool _arePeriodsInSameBlock(int p1, int p2) {
    int blockOf(int p) {
      if (p <= 2) return 1;
      if (p <= 4) return 2;
      return 3;
    }
    return blockOf(p1) == blockOf(p2);
  }

  List<_MergedMatrixItem> _prepareMergedDayItems(List<TimetableItemModel> rawDayItems) {
    final items = List<TimetableItemModel>.from(rawDayItems)
      ..sort((a, b) => (a.periodNumber ?? 0).compareTo(b.periodNumber ?? 0));

    final List<_MergedMatrixItem> result = [];
    final Set<int> consumedPeriods = {};

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final pNum = item.periodNumber;
      if (pNum == null || consumedPeriods.contains(pNum)) continue;

      int span = item.span > 1 ? item.span : 1;

      // Group consecutive lab or identical periods within the same block
      if (span == 1) {
        final code = (item.subjectCode ?? item.subjectName ?? '').trim();
        final isLab = _isItemLab(item);

        int lookahead = i + 1;
        while (lookahead < items.length) {
          final nextItem = items[lookahead];
          final nextPNum = nextItem.periodNumber;
          if (nextPNum == null) break;

          final bool isConsecutive = nextPNum == pNum + span;
          final bool sameBlock = _arePeriodsInSameBlock(pNum, nextPNum);
          final bool sameSubject = (nextItem.subjectCode ?? nextItem.subjectName ?? '').trim() == code ||
              (isLab && _isItemLab(nextItem));

          if (isConsecutive && sameBlock && sameSubject && code.isNotEmpty) {
            span++;
            lookahead++;
          } else {
            break;
          }
        }
      }

      for (int p = 0; p < span; p++) {
        consumedPeriods.add(pNum + p);
      }

      final slotIdx = _mapPeriodToSlotIndex(pNum);
      final top = _getSlotTop(slotIdx);

      double h = 0;
      for (int s = 0; s < span; s++) {
        final curSlot = slotIdx + s;
        if (curSlot < _slots.length) {
          h += _slots[curSlot].height;
        }
      }

      result.add(_MergedMatrixItem(
        item: item,
        startSlotIndex: slotIdx,
        span: span,
        top: top,
        height: h,
      ));
    }

    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DAY AGENDA VIEW (STREAMLINED & MATCHING REFERENCE IMAGE 2)
  // ─────────────────────────────────────────────────────────────────────────

  DateTime _getDateForWeekday(int weekdayIndex) {
    final now = _now;
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return monday.add(Duration(days: weekdayIndex));
  }

  String _formatStartTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '--:--';
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final raw = clean.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = raw.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        final min = parts[1].padLeft(2, '0');
        if (isPm && hour < 12) hour += 12;
        if (isAm && hour == 12) hour = 0;
        int h12 = hour % 12;
        if (h12 == 0) h12 = 12;
        return '${h12.toString().padLeft(2, '0')}:$min';
      }
    } catch (_) {}
    return timeStr;
  }

  String _formatEndTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    return _formatStartTime(timeStr);
  }

  double _calculatePeriodProgress(TimetableItemModel item) {
    final startMin = _parseTimeToMinutes(item.startTime);
    final endMin = _parseTimeToMinutes(item.endTime);
    if (startMin == -1 || endMin == -1 || endMin <= startMin) {
      return 0.0;
    }
    final now = _now;
    final nowMin = now.hour * 60 + now.minute;
    if (nowMin >= startMin && nowMin < endMin) {
      final ratio = (nowMin - startMin) / (endMin - startMin);
      return ratio.clamp(0.05, 1.0);
    } else if (nowMin >= endMin) {
      return 1.0;
    }
    return 0.0;
  }

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

    final bool isViewingToday = _isToday(_selectedDay);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        // 1. Week Strip (Mon 12, Tue 13, Wed 14, Thu 15, Fri 16, Sat 17)
        _buildWeekDayStrip(colors, hasSaturdayClasses),
        const SizedBox(height: 14),

        // Live status indicator when viewing today
        if (isViewingToday && dayItems.isNotEmpty) ...[
          _buildLiveDayStatusBanner(dayItems, colors),
          const SizedBox(height: 14),
        ],

        // 2. Schedule Timeline List
        if (dayItems.isEmpty)
          _buildEmptyDayState(colors)
        else
          ...dayItems.asMap().entries.map((entry) {
            final item = entry.value;
            final status = _determinePeriodStatus(item, dayItems);

            // Interleaved Break Dividers before Period 3 (Tea break) and Period 5 (Lunch)
            final bool showTeaBreakBefore = item.periodNumber == 3;
            final bool showLunchBreakBefore = item.periodNumber == 5;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showTeaBreakBefore)
                  _buildTimelineBreakDivider('Tea break · 10:35', colors, isTeaBreak: true),
                if (showLunchBreakBefore)
                  _buildTimelineBreakDivider('Lunch · 12:45', colors, isLunchBreak: true),
                _buildTimelinePeriodRow(item, status, colors, palette),
                const SizedBox(height: 12),
              ],
            );
          }),
      ],
    );
  }

  Widget _buildLiveDayStatusBanner(List<TimetableItemModel> dayItems, AppColors colors) {
    final now = _now;
    final nowMin = now.hour * 60 + now.minute;
    final hasActive = dayItems.any((item) => _isItemActiveNow(item));

    final firstStart = _parseTimeToMinutes(dayItems.first.startTime);
    final lastEnd = _parseTimeToMinutes(dayItems.last.endTime);

    if (hasActive) {
      final activeItem = dayItems.firstWhere((item) => _isItemActiveNow(item));
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: (colors.isDark ? colors.accent : const Color(0xFF0B7A55)).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: (colors.isDark ? colors.accent : const Color(0xFF0B7A55)).withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.isDark ? colors.accent : const Color(0xFF0B7A55),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'LIVE CLASS IN SESSION',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: colors.isDark ? colors.accent : const Color(0xFF0B7A55),
                letterSpacing: 0.4,
              ),
            ),
            const Spacer(),
            Text(
              'Period ${activeItem.periodNumber ?? 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final bool isTeaBreak = nowMin >= 635 && nowMin < 655;
    final bool isLunchBreak = nowMin >= 765 && nowMin < 825;

    if (isTeaBreak) {
      return _buildStatusChip(
        icon: Icons.coffee_rounded,
        title: 'Tea Break · In Progress',
        subtitle: 'Classes resume at 10:55 AM (Period 3)',
        colors: colors,
      );
    }

    if (isLunchBreak) {
      return _buildStatusChip(
        icon: Icons.restaurant_rounded,
        title: 'Lunch Break · In Progress',
        subtitle: 'Classes resume at 01:45 PM (Period 5)',
        colors: colors,
      );
    }

    if (firstStart != -1 && nowMin < firstStart) {
      final startStr = _formatStartTime(dayItems.first.startTime);
      final firstSubject = dayItems.first.subjectName ?? dayItems.first.subjectCode ?? 'Period 1';
      return _buildStatusChip(
        icon: Icons.schedule_rounded,
        title: "Today's classes start at $startStr",
        subtitle: 'First class: $firstSubject',
        colors: colors,
      );
    }

    if (lastEnd != -1 && nowMin >= lastEnd) {
      return _buildStatusChip(
        icon: Icons.task_alt_rounded,
        title: 'All classes completed for today',
        subtitle: '${dayItems.length} periods completed',
        colors: colors,
        isSuccess: true,
      );
    }

    return _buildStatusChip(
      icon: Icons.hourglass_top_rounded,
      title: 'Class Break',
      subtitle: 'Next class starting shortly',
      colors: colors,
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String title,
    required String subtitle,
    required AppColors colors,
    bool isSuccess = false,
  }) {
    final accentColor = isSuccess
        ? (colors.isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
        : (colors.isDark ? colors.accent : const Color(0xFFB87B4B));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.isDark ? colors.surfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.isDark ? colors.border : const Color(0xFFE5E5EB),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.2 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
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

  Widget _buildWeekDayStrip(AppColors colors, bool hasSaturdayClasses) {
    // 6 Days (Mon - Sat) matching Reference Image 2
    return Row(
      children: List.generate(6, (offset) {
        final dayCode = _weekdays[offset];
        final label = _dayLabels[offset];
        final isSelected = dayCode.toUpperCase() == _selectedDay.toUpperCase();
        final isToday = dayCode.toUpperCase() == _getCurrentWeekdayName().toUpperCase();
        final date = _getDateForWeekday(offset);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              onTap: () => setState(() => _selectedDay = dayCode),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 64,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (colors.isDark ? colors.surfaceElevated : const Color(0xFF161922))
                      : (colors.isDark ? const Color(0xFF1E222C) : const Color(0xFFEBE7DF)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? (colors.isDark ? colors.borderStrong : const Color(0xFF161922))
                        : (isToday
                            ? (colors.isDark ? colors.accent : const Color(0xFFB87B4B))
                            : Colors.transparent),
                    width: isSelected ? 1.4 : (isToday ? 1.3 : 1.0),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : (colors.isDark ? colors.textSecondary : const Color(0xFF4A4E57)),
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 3.5),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? (colors.isDark ? colors.accent : const Color(0xFF34D399))
                                  : (colors.isDark ? colors.accent : const Color(0xFFB87B4B)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? Colors.white
                            : (colors.isDark ? colors.textPrimary : const Color(0xFF1C1F26)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimelinePeriodRow(
    TimetableItemModel item,
    PeriodClassStatus status,
    AppColors colors,
    HighlightPalette palette,
  ) {
    final isLive = status == PeriodClassStatus.activeNow;
    final isCompleted = status == PeriodClassStatus.completed;
    final startTimeStr = _formatStartTime(item.startTime);

    return InkWell(
      onTap: () => _showClassDetailsModal(item),
      borderRadius: BorderRadius.circular(isLive ? 20 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Time Column (Prominent start time)
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                startTimeStr,
                style: TextStyle(
                  fontSize: isLive ? 14 : 13,
                  fontWeight: isLive ? FontWeight.w800 : FontWeight.w600,
                  color: isLive
                      ? (colors.isDark ? colors.accent : colors.primary)
                      : colors.textSecondary,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),

          // Right Card
          Expanded(
            child: isLive
                ? _buildActiveHeroPeriodCard(item, colors, palette)
                : _buildStandardPeriodCard(item, isCompleted, colors),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveHeroPeriodCard(
    TimetableItemModel item,
    AppColors colors,
    HighlightPalette palette,
  ) {
    final periodNum = item.periodNumber ?? 1;
    final endTimeStr = _formatEndTime(item.endTime);
    final subjectTitle = (item.subjectName != null && item.subjectName!.trim().isNotEmpty)
        ? item.subjectName!.trim()
        : (item.subjectCode != null && item.subjectCode!.trim().isNotEmpty
            ? item.subjectCode!.trim()
            : 'Class Session');

    final facultyStr = (item.facultyName != null && item.facultyName!.trim().isNotEmpty)
        ? item.facultyName!.trim()
        : '';
    final hallStr = (item.roomNo != null && item.roomNo!.trim().isNotEmpty)
        ? item.roomNo!.trim()
        : '';

    String subtitle = '';
    if (facultyStr.isNotEmpty && hallStr.isNotEmpty) {
      subtitle = '$facultyStr · $hallStr';
    } else if (facultyStr.isNotEmpty) {
      subtitle = facultyStr;
    } else if (hallStr.isNotEmpty) {
      subtitle = hallStr;
    } else {
      subtitle = item.type ?? 'Class Session';
    }

    final progress = _calculatePeriodProgress(item);
    final endMin = _parseTimeToMinutes(item.endTime);
    final now = _now;
    final nowMin = now.hour * 60 + now.minute;
    final remainingMins = (endMin != -1 && endMin > nowMin) ? (endMin - nowMin) : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.isDark
              ? [colors.hero, colors.heroRaised]
              : const [Color(0xFF2B1A13), Color(0xFF3E261C)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.isDark
              ? colors.borderStrong
              : const Color(0xFFB87B4B).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.isDark
                ? Colors.black.withValues(alpha: 0.45)
                : const Color(0xFF2B1A13).withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: [NOW • PERIOD X] and [until 10:35 (20m left)]
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: colors.isDark
                      ? colors.accent.withValues(alpha: 0.22)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colors.isDark
                        ? colors.accent.withValues(alpha: 0.45)
                        : const Color(0xFFE8D7C7),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6.5,
                      height: 6.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.isDark ? colors.accent : const Color(0xFF0B7A55),
                      ),
                    ),
                    const SizedBox(width: 5.5),
                    Text(
                      'NOW · PERIOD $periodNum',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: colors.isDark ? colors.accent : const Color(0xFF2B1A13),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (endTimeStr.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'until $endTimeStr',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.onHeroSecondary,
                      ),
                    ),
                    if (remainingMins != null && remainingMins > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(${remainingMins}m left)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: colors.onHeroSecondary.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Subject Name
          Text(
            subjectTitle,
            style: TextStyle(
              fontSize: 18.5,
              fontWeight: FontWeight.w800,
              color: colors.onHero,
              height: 1.25,
              letterSpacing: -0.3,
            ),
          ),

          // Faculty and Hall subtitle
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.onHeroSecondary,
              ),
            ),
          ],

          // Structured metadata elements so text finders, test assertions, and accessibility work identically to standard card
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'P$periodNum',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.onHeroSecondary,
                ),
              ),
              if (item.startTime != null && item.endTime != null)
                Text(
                  '${item.startTime} - ${item.endTime}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onHeroSecondary,
                  ),
                ),
              if (item.subjectCode != null && item.subjectCode!.isNotEmpty)
                Text(
                  'Code: ${item.subjectCode}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onHeroSecondary,
                  ),
                ),
              Text(
                item.facultyName != null
                    ? 'Faculty: ${item.facultyName}'
                    : 'Faculty: Faculty assignment pending',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.onHeroSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Live dynamic Progress Bar
          Container(
            height: 4.5,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors.onHero.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.isDark ? colors.accent : const Color(0xFFE0A878),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardPeriodCard(
    TimetableItemModel item,
    bool isCompleted,
    AppColors colors,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.isDark ? const Color(0xFF1E222C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.isDark ? colors.border : const Color(0xFFE5E5EB),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.2 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.subjectName ?? 'Class Session',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (item.periodNumber != null)
                      Text(
                        'P${item.periodNumber}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.textSecondary,
                        ),
                      ),
                    if (item.startTime != null && item.endTime != null)
                      Text(
                        '${item.startTime} - ${item.endTime}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    if (item.subjectCode != null && item.subjectCode!.isNotEmpty)
                      Text(
                        'Code: ${item.subjectCode}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    Text(
                      item.facultyName != null
                          ? 'Faculty: ${item.facultyName}'
                          : 'Faculty: Faculty assignment pending',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isCompleted)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.check_rounded,
                color: colors.isDark ? colors.textMuted : const Color(0xFF8E8E93),
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineBreakDivider(
    String label,
    AppColors colors, {
    bool isTeaBreak = false,
    bool isLunchBreak = false,
  }) {
    final now = _now;
    final nowMin = now.hour * 60 + now.minute;
    final bool isBreakActive = _isToday(_selectedDay) && (
      (isTeaBreak && nowMin >= 635 && nowMin < 655) ||
      (isLunchBreak && nowMin >= 765 && nowMin < 825)
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: isBreakActive
                  ? (colors.isDark ? colors.accent : const Color(0xFFB87B4B)).withValues(alpha: 0.5)
                  : (colors.isDark ? colors.border : const Color(0xFFE2E2E8)),
              thickness: isBreakActive ? 1.5 : 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: isBreakActive
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (colors.isDark ? colors.accent : const Color(0xFFB87B4B)).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.isDark ? colors.accent : const Color(0xFFB87B4B),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.isDark ? colors.accent : const Color(0xFFB87B4B),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$label · NOW',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.isDark ? colors.accent : const Color(0xFF2B1A13),
                          ),
                        ),
                      ],
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.isDark ? colors.textMuted : const Color(0xFF6E737B),
                    ),
                  ),
          ),
          Expanded(
            child: Divider(
              color: isBreakActive
                  ? (colors.isDark ? colors.accent : const Color(0xFFB87B4B)).withValues(alpha: 0.5)
                  : (colors.isDark ? colors.border : const Color(0xFFE2E2E8)),
              thickness: isBreakActive ? 1.5 : 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDayState(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _selectedDay.toUpperCase() == 'SUNDAY'
                  ? Icons.weekend_rounded
                  : Icons.event_busy_outlined,
              size: 40,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedDay.toUpperCase() == 'SUNDAY'
                ? 'No Classes Scheduled'
                : 'No Classes on $_selectedDay',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _selectedDay.toUpperCase() == 'SUNDAY'
                ? 'Weekend — Sunday has no scheduled classes.'
                : 'No timetable schedule entries configured for this day.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
