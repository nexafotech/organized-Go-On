import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/student_model.dart';
import '../common/app_card.dart';
import 'full_day_breakdown_card.dart';

/// Interactive Attendance Overview Card that supports:
/// 1. Glassmorphic Centered Multi-Ring Concentric Activity Rings Graph
/// 2. Mode Switch between "Overall Attendance" and "Day-wise"
/// 3. Static Color Day Matrix Calendar (Flat, high-contrast, clean status highlights)
/// 4. Year/Month navigation from January onwards
/// 5. Clean Palette and Subject Breakdown (Petal Chart) section
class InteractiveAttendanceOverviewCard extends StatefulWidget {
  final StudentSummaryModel summary;
  final List<DateWiseEntryModel>? dateWiseEntries;
  final List<SubjectAttendanceModel>? subjects;
  final List<TimetableItemModel>? timetable;
  final ValueChanged<DateWiseEntryModel>? onDateSelected;

  const InteractiveAttendanceOverviewCard({
    Key? key,
    required this.summary,
    this.dateWiseEntries,
    this.subjects,
    this.timetable,
    this.onDateSelected,
  }) : super(key: key);

  @override
  State<InteractiveAttendanceOverviewCard> createState() =>
      _InteractiveAttendanceOverviewCardState();
}

class _InteractiveAttendanceOverviewCardState
    extends State<InteractiveAttendanceOverviewCard>
    with SingleTickerProviderStateMixin {
  bool _showCalendarView = false;
  int _selectedYear = 2025;
  int _selectedMonth = 3; // Default to March 2025 as in reference image
  int _selectedDayNumber = 5; // Default to 5th as in reference image

  late AnimationController _animController;
  late Animation<double> _anim;

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _monthShortNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _selectedDayNumber = now.day;
    if (widget.dateWiseEntries != null && widget.dateWiseEntries!.isNotEmpty) {
      final latest = widget.dateWiseEntries!.last;
      final parsed = DateTime.tryParse(latest.date);
      if (parsed != null) {
        _selectedYear = parsed.year;
        _selectedMonth = parsed.month;
        _selectedDayNumber = parsed.day;
      }
    }
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status, AppColors colors) {
    switch (status.toUpperCase()) {
      case 'CRITICAL':
        return colors.absent;
      case 'WARNING':
        return colors.warning;
      case 'OK':
      default:
        return colors.accentStrong;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final summary = widget.summary;
    final statusColor = _getStatusColor(summary.attendanceStatus, colors);

    // Calculate percentages
    final total = summary.total > 0 ? summary.total : 1;
    final presentPct = summary.total > 0
        ? (summary.present / total) * 100.0
        : (summary.percentage > 0 ? summary.percentage : 0.0);
    final absentPct = (summary.absent / total) * 100.0;
    final odPct = (summary.od / total) * 100.0;

    return GlassCard(
      variant: GlassCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Row: Segmented Switch ("Overall Attendance" <-> "Day-wise") & Status Badge ──
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Mode Switcher between "Overall Attendance" and "Day-wise"
                Container(
                  decoration: BoxDecoration(
                    color: colors.glassSurfaceSubtle,
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(color: colors.glassBorder),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSwitchPill(
                        label: 'Overall Attendance',
                        icon: Icons.donut_large_rounded,
                        isActive: !_showCalendarView,
                        colors: colors,
                        onTap: () {
                          if (_showCalendarView) {
                            setState(() => _showCalendarView = false);
                            _animController.forward(from: 0.0);
                          }
                        },
                      ),
                      _buildSwitchPill(
                        label: 'Day-wise',
                        icon: Icons.calendar_month_rounded,
                        isActive: _showCalendarView,
                        colors: colors,
                        onTap: () {
                          if (!_showCalendarView) {
                            setState(() => _showCalendarView = true);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Status Pill (OK / On track)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(color: statusColor, width: 1.1),
                  ),
                  child: Text(
                    summary.attendanceStatus,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Animated View Switcher ──
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _showCalendarView
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: _buildCenteredGlassmorphicGraphView(
              colors: colors,
              summary: summary,
              presentPct: presentPct,
              absentPct: absentPct,
              odPct: odPct,
            ),
            secondChild: _buildAppleGlassCalendarView(
              colors: colors,
              summary: summary,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. CENTERED GLASSMORPHIC CONCENTRIC MULTI-RING GRAPH VIEW
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildCenteredGlassmorphicGraphView({
    required AppColors colors,
    required StudentSummaryModel summary,
    required double presentPct,
    required double absentPct,
    required double odPct,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 14),

        // Outer Frosted Glass Disc Container (Glassmorphic Lens)
        Center(
          child: Container(
            width: 236,
            height: 236,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.glassSurfaceSubtle,
              border: Border.all(
                color: colors.glassBorderStrong,
                width: 1.5,
              ),
              boxShadow: AppGlass.shadow,
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (context, child) {
                    final curPresent = presentPct * _anim.value;
                    final curAbsent = absentPct * _anim.value;
                    final curOd = odPct * _anim.value;
                    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
                    final activePresent = disableAnimations ? presentPct : curPresent;
                    final displayPercentage = (presentPct % 1 == 0)
                        ? '${activePresent.round()}%'
                        : '${activePresent.toStringAsFixed(1)}%';

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Concentric Glass Rings CustomPaint
                        CustomPaint(
                          size: const Size(204, 204),
                          painter: ConcentricGlassRingsPainter(
                            presentPct: curPresent,
                            absentPct: curAbsent,
                            odPct: curOd,
                            presentStartColor: colors.present,
                            presentEndColor: colors.present,
                            absentStartColor: colors.absent,
                            absentEndColor: colors.absent,
                            odStartColor: colors.od,
                            odEndColor: colors.od,
                            trackColor: colors.border.withValues(alpha: 0.35),
                            strokeWidth: 10.5,
                          ),
                        ),

                        // Center Floating Frosted Glass Puck
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.glassSurfaceStrong,
                            border: Border.all(
                              color: colors.glassBorderStrong,
                              width: 1.2,
                            ),
                            boxShadow: AppGlass.shadow,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    displayPercentage,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: colors.textPrimary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'ATTENDANCE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: colors.textMuted,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 22),

        // Centered Frosted Glass Legend Pills
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            _buildGlassLegendPill(
              color: colors.present,
              percentage: presentPct,
              label: 'Present',
              count: '${summary.present} / ${summary.total}',
              colors: colors,
            ),
            _buildGlassLegendPill(
              color: colors.absent,
              percentage: absentPct,
              label: 'Absent',
              count: '${summary.absent} / ${summary.total}',
              colors: colors,
            ),
            _buildGlassLegendPill(
              color: colors.od,
              percentage: odPct,
              label: 'On-Duty (OD)',
              count: '${summary.od} / ${summary.total}',
              colors: colors,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Centered Status Badge: On track • Min: 75%
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: AppRadius.pillBorder,
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    summary.percentage >= summary.minimumRequired
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    size: 14,
                    color: summary.percentage >= summary.minimumRequired
                        ? colors.primary
                        : colors.absent,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    summary.percentage >= summary.minimumRequired
                        ? 'On track'
                        : 'Action required',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: summary.percentage >= summary.minimumRequired
                          ? colors.primary
                          : colors.absent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Min: ${summary.minimumRequired.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                color: colors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Total Sessions Frosted Glass Capsule (Matching reference layout)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: colors.glassSurfaceSubtle,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.glassBorderStrong),
            boxShadow: AppGlass.shadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${summary.total}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Bottom Right: Half-Day Present indicator (as in reference image)
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wb_sunny_outlined, size: 14, color: colors.accentStrong),
              const SizedBox(width: 5),
              Text(
                'Half-Day Present: ${summary.halfDayPresent}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.accentStrong,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildGlassLegendPill({
    required Color color,
    required double percentage,
    required String label,
    required String count,
    required AppColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.glassSurfaceSubtle,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: colors.glassBorder.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 11,
              color: colors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. APPLE-STYLE LIQUID GLASS MINIMALIST CALENDAR (Reference Image)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildAppleGlassCalendarView({
    required AppColors colors,
    required StudentSummaryModel summary,
  }) {
    // Generate days data for the selected month and year
    final daysData = _generateMonthDays(_selectedYear, _selectedMonth);

    // Ensure selected day is within range
    final maxDays = daysData.length;
    if (_selectedDayNumber > maxDays) {
      _selectedDayNumber = maxDays;
    }

    final selectedDayData = daysData.firstWhere(
      (d) => d.dayNumber == _selectedDayNumber,
      orElse: () => daysData.first,
    );

    // Count statistics for the selected month
    int monthWorkingDays = 0;
    int monthPresentDays = 0;
    int monthAbsentDays = 0;
    int monthOdDays = 0;

    for (final d in daysData) {
      if (d.status != 'WEEKEND') {
        monthWorkingDays++;
        if (d.status == 'PRESENT') monthPresentDays++;
        if (d.status == 'ABSENT') monthAbsentDays++;
        if (d.status == 'OD') monthOdDays++;
      }
    }

    final monthPct = monthWorkingDays > 0
        ? ((monthPresentDays / monthWorkingDays) * 100).toStringAsFixed(1)
        : '0.0';

    final selectedDate = DateTime(_selectedYear, _selectedMonth, _selectedDayNumber);
    // 0 = Monday, 6 = Sunday
    final selectedWeekdayIndex = selectedDate.weekday - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Apple Frosted Glass Month Navigation Header ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.glassSurfaceSubtle,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.glassBorderStrong,
              width: 1.0,
            ),
            boxShadow: AppGlass.shadow,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 350;

              final monthNavControls = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    iconSize: 22,
                    tooltip: 'Previous Month',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    color: _selectedMonth > 1
                        ? colors.textPrimary
                        : colors.textMuted.withValues(alpha: 0.25),
                    onPressed: _selectedMonth > 1
                        ? () {
                            setState(() {
                              _selectedMonth--;
                              final maxD = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
                              if (_selectedDayNumber > maxD) _selectedDayNumber = maxD;
                            });
                          }
                        : null,
                  ),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedMonth,
                      isDense: true,
                      dropdownColor: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: colors.accent, size: 16),
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                      items: List.generate(12, (index) {
                        final m = index + 1;
                        return DropdownMenuItem<int>(
                          value: m,
                          child: Text('${_monthNames[index]} $_selectedYear'),
                        );
                      }),
                      onChanged: (newMonth) {
                        if (newMonth != null && newMonth != _selectedMonth) {
                          setState(() {
                            _selectedMonth = newMonth;
                            final maxD = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
                            if (_selectedDayNumber > maxD) _selectedDayNumber = maxD;
                          });
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    iconSize: 22,
                    tooltip: 'Next Month',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    color: _selectedMonth < 12
                        ? colors.textPrimary
                        : colors.textMuted.withValues(alpha: 0.25),
                    onPressed: _selectedMonth < 12
                        ? () {
                            setState(() {
                              _selectedMonth++;
                              final maxD = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
                              if (_selectedDayNumber > maxD) _selectedDayNumber = maxD;
                            });
                          }
                        : null,
                  ),
                ],
              );

              final summaryCapsule = Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.22),
                    width: 1.0,
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
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$monthPresentDays/$monthWorkingDays Days ($monthPct%)',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: colors.primary,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    monthNavControls,
                    const SizedBox(height: 6),
                    summaryCapsule,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  monthNavControls,
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: summaryCapsule,
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // ── Responsive Layout: Left Hero & Glass Bubble Grid, Right Apple Glass Panels ──
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 820;

            final calendarLeftHeroAndGrid = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Giant Bold Hero Date Number (e.g. "5" or "11")
                Text(
                  '$_selectedDayNumber',
                  style: TextStyle(
                    fontSize: 66,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                    letterSpacing: -3.0,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),

                // 2. Month Name & Year on left, Weekday on right (e.g. "MARCH 2025" and "Wed")
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _monthNames[_selectedMonth - 1].toUpperCase(),
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            '$_selectedYear',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _getWeekdayShort(selectedDate.weekday),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // 3. Weekday Row (M T W T F S S) with active column highlighted in radiant orange
                _buildAppleWeekdayHeader(
                  selectedWeekdayIndex: selectedWeekdayIndex,
                  colors: colors,
                ),

                const SizedBox(height: 12),

                // 4. Apple Liquid Glass Circular Bubble/Dot Matrix Grid
                _buildAppleGlassBubbleGrid(
                  daysData: daysData,
                  year: _selectedYear,
                  month: _selectedMonth,
                  colors: colors,
                ),
              ],
            );

            final rightSidePanel = _buildAppleGlassRightPanel(
              selectedDay: selectedDayData,
              monthPresentDays: monthPresentDays,
              monthAbsentDays: monthAbsentDays,
              monthOdDays: monthOdDays,
              colors: colors,
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: calendarLeftHeroAndGrid),
                  const SizedBox(width: 20),
                  Expanded(flex: 5, child: rightSidePanel),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                calendarLeftHeroAndGrid,
                const SizedBox(height: 22),
                rightSidePanel,
              ],
            );
          },
        ),
      ],
    );
  }

  // Weekday row with active column highlighted in radiant amber-orange
  Widget _buildAppleWeekdayHeader({
    required int selectedWeekdayIndex,
    required AppColors colors,
  }) {
    final weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (i) {
          final isSelectedCol = (i == selectedWeekdayIndex);
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  weekdays[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelectedCol ? FontWeight.w900 : FontWeight.w700,
                    color: isSelectedCol
                        ? colors.accentStrong
                        : colors.textMuted.withValues(alpha: 0.70),
                  ),
                ),
                const SizedBox(height: 3),
                if (isSelectedCol)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.accentStrong,
                      boxShadow: [
                        BoxShadow(
                          color: colors.accent.withValues(alpha: 0.45),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 5),
              ],
            ),
          );
        }),
      ),
    );
  }

  // Apple Frosted Glass Bubble Grid Canvas
  Widget _buildAppleGlassBubbleGrid({
    required List<_DayAttendanceData> daysData,
    required int year,
    required int month,
    required AppColors colors,
  }) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // 1 = Monday, 7 = Sunday
    final firstDayWeekday = DateTime(year, month, 1).weekday;
    final offset = firstDayWeekday - 1; // 0 for Monday, 6 for Sunday
    final totalSlots = ((offset + daysInMonth + 6) ~/ 7) * 7;
    final prevMonthDaysCount = DateTime(year, month, 0).day;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: colors.glassSurfaceSubtle,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.glassBorderStrong,
          width: 1.1,
        ),
        boxShadow: AppGlass.shadow,
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: totalSlots,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.0,
        ),
        itemBuilder: (context, index) {
          final dayNumber = index - offset + 1;

          // Preceding month trailing days
          if (dayNumber < 1) {
            final ghostDay = prevMonthDaysCount - offset + index + 1;
            return _buildAppleLiquidGlassGhostBubble(
              dayNumber: ghostDay,
              colors: colors,
            );
          }

          // Succeeding month leading days
          if (dayNumber > daysInMonth) {
            final ghostDay = dayNumber - daysInMonth;
            return _buildAppleLiquidGlassGhostBubble(
              dayNumber: ghostDay,
              colors: colors,
            );
          }

          final dayData = daysData[dayNumber - 1];
          final isSelected = (dayData.dayNumber == _selectedDayNumber);

          return _buildAppleLiquidGlassBubbleTile(
            data: dayData,
            isSelected: isSelected,
            colors: colors,
            onTap: () {
              setState(() => _selectedDayNumber = dayData.dayNumber);
              widget.onDateSelected?.call(dayData.entry);
            },
          );
        },
      ),
    );
  }

  // Ghosted Bubble for trailing and leading offset days
  Widget _buildAppleLiquidGlassGhostBubble({
    required int dayNumber,
    required AppColors colors,
  }) {
    return Center(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surfaceMuted.withValues(alpha: 0.15),
          border: Border.all(
            color: colors.border.withValues(alpha: 0.30),
            width: 0.8,
          ),
        ),
        child: Center(
          child: Text(
            '$dayNumber',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: colors.textMuted.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }

  // Individual Apple Liquid Glass Sphere / Pebble Tile
  // Individual Static Color Day Tile (Flat, solid, static colors without glossy 3D bubbles or glares)
  Widget _buildAppleLiquidGlassBubbleTile({
    required _DayAttendanceData data,
    required bool isSelected,
    required AppColors colors,
    required VoidCallback onTap,
  }) {
    Color staticColor;
    Color textColor;
    List<BoxShadow> boxShadow;
    Border border;

    if (isSelected) {
      // Selected Day: Radiant Caramel Amber with crisp pure white ring
      staticColor = const Color(0xFFD4833B);
      textColor = Colors.white;
      border = Border.all(color: Colors.white, width: 2.2);
      boxShadow = [
        BoxShadow(
          color: const Color(0xFFD4833B).withValues(alpha: 0.45),
          blurRadius: 7,
          offset: const Offset(0, 2),
        ),
      ];
    } else {
      switch (data.status) {
        case 'PRESENT':
          // Present days: Theme Deep Roasted Espresso (#2B1A13)
          staticColor = colors.present;
          textColor = Colors.white;
          border = Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1.0,
          );
          boxShadow = [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.22),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ];
          break;
        case 'ABSENT':
          // Absent days: Warm Spiced Terracotta / Burnt Clay (#BA5A31)
          staticColor = colors.absent;
          textColor = Colors.white;
          border = Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1.0,
          );
          boxShadow = [
            BoxShadow(
              color: colors.absent.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ];
          break;
        case 'OD':
          // OD days: Muted Slate Denim (#4A607A)
          staticColor = colors.od;
          textColor = Colors.white;
          border = Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1.0,
          );
          boxShadow = [
            BoxShadow(
              color: colors.od.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ];
          break;
        case 'PARTIAL':
          staticColor = colors.warning;
          textColor = Colors.white;
          border = Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1.0,
          );
          boxShadow = [
            BoxShadow(
              color: colors.warning.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ];
          break;
        case 'NO_DATA':
        case 'FUTURE':
          staticColor = Colors.transparent;
          textColor = colors.textMuted;
          border = Border.all(
            color: colors.isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
            width: 1.2,
          );
          boxShadow = [];
          break;
        case 'WEEKEND':
        default:
          // Weekend / Off days: Warm Oat Linen from the theme (#EDE5DB)
          staticColor = colors.surfaceMuted;
          textColor = colors.textSecondary;
          border = Border.all(
            color: colors.border.withValues(alpha: 0.60),
            width: 1.0,
          );
          boxShadow = [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ];
          break;
      }
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Center(
          child: AnimatedScale(
            scale: isSelected ? 1.06 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: staticColor,
                border: border,
                boxShadow: boxShadow,
              ),
              child: Center(
                child: Text(
                  '${data.dayNumber}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. RIGHT SIDE PANEL OF THE CALENDAR (Apple Frosted Glass Panels)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildAppleGlassRightPanel({
    required _DayAttendanceData selectedDay,
    required int monthPresentDays,
    required int monthAbsentDays,
    required int monthOdDays,
    required AppColors colors,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Apple Frosted Glass Palette Legend ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.glassSurfaceSubtle,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colors.glassBorderStrong,
              width: 1.1,
            ),
            boxShadow: AppGlass.shadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.palette_outlined, size: 14, color: colors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'ATTENDANCE PALETTE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildApplePaletteRow(
                label: 'Present',
                color: colors.present,
                textColor: colors.present,
                pillBg: colors.presentBg,
                pillBorder: colors.present.withValues(alpha: 0.35),
                count: '$monthPresentDays Days',
                colors: colors,
              ),
              const SizedBox(height: 11),
              _buildApplePaletteRow(
                label: 'Absent',
                color: colors.absent,
                textColor: colors.absent,
                pillBg: colors.absentBg,
                pillBorder: colors.absent.withValues(alpha: 0.35),
                count: '$monthAbsentDays Days',
                colors: colors,
              ),
              const SizedBox(height: 11),
              _buildApplePaletteRow(
                label: 'On-Duty (OD)',
                color: colors.od,
                textColor: colors.od,
                pillBg: colors.odBg,
                pillBorder: colors.od.withValues(alpha: 0.35),
                count: '$monthOdDays ${monthOdDays == 1 ? "Day" : "Days"}',
                colors: colors,
              ),
              const SizedBox(height: 11),
              _buildApplePaletteRow(
                label: 'Weekend / Off',
                color: colors.surfaceMuted,
                textColor: colors.textSecondary,
                pillBg: colors.surfaceMuted,
                pillBorder: colors.border,
                count: 'Days Off',
                colors: colors,
              ),
              const SizedBox(height: 11),
              _buildApplePaletteRow(
                label: 'Selected Day',
                color: const Color(0xFFD4833B),
                textColor: colors.accentStrong,
                pillBg: const Color(0xFFD4833B).withValues(alpha: 0.14),
                pillBorder: const Color(0xFFD4833B).withValues(alpha: 0.40),
                count: 'Active Date',
                colors: colors,
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ── Full Day Attendance Breakdown for the selected calendar date ──
        FullDayBreakdownCard(
          entry: selectedDay.entry,
          subjects: widget.subjects,
          timetable: widget.timetable,
        ),
      ],
    );
  }

  Widget _buildApplePaletteRow({
    required String label,
    required Color color,
    required Color textColor,
    required Color pillBg,
    required Color pillBorder,
    required String count,
    required AppColors colors,
  }) {
    return Row(
      children: [
        // Static Color Dot (Clean flat static circular disc)
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: color == colors.surfaceMuted
                  ? colors.borderStrong.withValues(alpha: 0.60)
                  : Colors.white.withValues(alpha: 0.90),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.30),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const Spacer(),
        // Frosted Glass Pill Tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: AppRadius.pillBorder,
            border: Border.all(
              color: pillBorder,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: textColor.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            count,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchPill({
    required String label,
    required IconData icon,
    required bool isActive,
    required AppColors colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? colors.primary : Colors.transparent,
          borderRadius: AppRadius.pillBorder,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? colors.onPrimary : colors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? colors.onPrimary : colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Data Generator from January onwards
  // ─────────────────────────────────────────────────────────────────────────────
  static const Map<String, List<Map<String, String>>> _fallbackCurriculum = {
    'Monday': [
      {'num': '1', 'time': '09:10 AM - 10:00 AM', 'code': 'FDS', 'name': 'Foundations of Data Science'},
      {'num': '2', 'time': '10:00 AM - 10:50 AM', 'code': 'DMC', 'name': 'Discrete Mathematics for Computing'},
      {'num': '3', 'time': '11:10 AM - 12:00 PM', 'code': 'FDS LAB', 'name': 'Foundations of Data Science Laboratory'},
      {'num': '4', 'time': '12:00 PM - 12:50 PM', 'code': 'FDS LAB', 'name': 'Foundations of Data Science Laboratory'},
      {'num': '5', 'time': '01:40 PM - 02:30 PM', 'code': 'DPCO', 'name': 'Digital Principles & Computer Organization'},
      {'num': '6', 'time': '02:30 PM - 03:20 PM', 'code': 'OOPS', 'name': 'Object Oriented Programming Systems'},
      {'num': '7', 'time': '03:20 PM - 04:10 PM', 'code': 'DS', 'name': 'Data Structures'},
    ],
    'Tuesday': [
      {'num': '1', 'time': '09:10 AM - 10:00 AM', 'code': 'DMC', 'name': 'Discrete Mathematics for Computing'},
      {'num': '2', 'time': '10:00 AM - 10:50 AM', 'code': 'FDS', 'name': 'Foundations of Data Science'},
      {'num': '3', 'time': '11:10 AM - 12:00 PM', 'code': 'DPCO', 'name': 'Digital Principles & Computer Organization'},
      {'num': '4', 'time': '12:00 PM - 12:50 PM', 'code': 'DMC', 'name': 'Discrete Mathematics for Computing'},
      {'num': '5', 'time': '01:40 PM - 02:30 PM', 'code': 'OOPS', 'name': 'Object Oriented Programming Systems'},
      {'num': '6', 'time': '02:30 PM - 03:20 PM', 'code': 'LIB', 'name': 'Library Hour'},
      {'num': '7', 'time': '03:20 PM - 04:10 PM', 'code': 'DPCO', 'name': 'Digital Principles & Computer Organization'},
    ],
    'Wednesday': [
      {'num': '1', 'time': '09:10 AM - 10:00 AM', 'code': 'OOPS', 'name': 'Object Oriented Programming Systems'},
      {'num': '2', 'time': '10:00 AM - 10:50 AM', 'code': 'DMC', 'name': 'Discrete Mathematics for Computing'},
      {'num': '3', 'time': '11:10 AM - 12:00 PM', 'code': 'DPCO', 'name': 'Digital Principles & Computer Organization'},
      {'num': '4', 'time': '12:00 PM - 12:50 PM', 'code': 'DS', 'name': 'Data Structures'},
      {'num': '5', 'time': '01:40 PM - 02:30 PM', 'code': 'ACE-I', 'name': 'Aptitude & Communication Enhancement I'},
      {'num': '6', 'time': '02:30 PM - 03:20 PM', 'code': 'ACE-I', 'name': 'Aptitude & Communication Enhancement I'},
      {'num': '7', 'time': '03:20 PM - 04:10 PM', 'code': 'ACE-I', 'name': 'Aptitude & Communication Enhancement I'},
    ],
    'Thursday': [
      {'num': '1', 'time': '09:10 AM - 10:00 AM', 'code': 'DPCO', 'name': 'Digital Principles & Computer Organization'},
      {'num': '2', 'time': '10:00 AM - 10:50 AM', 'code': 'IKS', 'name': 'Indian Knowledge System'},
      {'num': '3', 'time': '11:10 AM - 12:00 PM', 'code': 'DS LAB', 'name': 'Data Structures Laboratory'},
      {'num': '4', 'time': '12:00 PM - 12:50 PM', 'code': 'DS LAB', 'name': 'Data Structures Laboratory'},
      {'num': '5', 'time': '01:40 PM - 02:30 PM', 'code': 'IIC', 'name': 'Innovation & Incubation Cell'},
      {'num': '6', 'time': '02:30 PM - 03:20 PM', 'code': 'DS', 'name': 'Data Structures'},
      {'num': '7', 'time': '03:20 PM - 04:10 PM', 'code': 'FDS', 'name': 'Foundations of Data Science'},
    ],
    'Friday': [
      {'num': '1', 'time': '09:10 AM - 10:00 AM', 'code': 'DS', 'name': 'Data Structures'},
      {'num': '2', 'time': '10:00 AM - 10:50 AM', 'code': 'FDS', 'name': 'Foundations of Data Science'},
      {'num': '3', 'time': '11:10 AM - 12:00 PM', 'code': 'JAVA LAB', 'name': 'Java Programming Laboratory'},
      {'num': '4', 'time': '12:00 PM - 12:50 PM', 'code': 'JAVA LAB', 'name': 'Java Programming Laboratory'},
      {'num': '5', 'time': '01:40 PM - 02:30 PM', 'code': 'TWM', 'name': 'Tutor Ward Meeting'},
      {'num': '6', 'time': '02:30 PM - 03:20 PM', 'code': 'DMC', 'name': 'Discrete Mathematics for Computing'},
      {'num': '7', 'time': '03:20 PM - 04:10 PM', 'code': 'OOPS', 'name': 'Object Oriented Programming Systems'},
    ],
    'Saturday': [
      {'num': '1', 'time': '09:10 AM - 10:00 AM', 'code': 'IKS', 'name': 'Indian Knowledge System'},
      {'num': '2', 'time': '10:00 AM - 10:50 AM', 'code': 'OOPS', 'name': 'Object Oriented Programming Systems'},
      {'num': '3', 'time': '11:10 AM - 12:00 PM', 'code': 'DMC', 'name': 'Discrete Mathematics for Computing'},
      {'num': '4', 'time': '12:00 PM - 12:50 PM', 'code': 'DS', 'name': 'Data Structures'},
      {'num': '5', 'time': '01:40 PM - 02:30 PM', 'code': 'LIB', 'name': 'Library Hour'},
      {'num': '6', 'time': '02:30 PM - 03:20 PM', 'code': 'ASSOC', 'name': 'Department Association Hour'},
      {'num': '7', 'time': '03:20 PM - 04:10 PM', 'code': 'TWM', 'name': 'Tutor Ward Meeting'},
    ],
  };

  List<_DayAttendanceData> _generateMonthDays(int year, int month) {
    final List<_DayAttendanceData> list = [];
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final existingEntries = widget.dateWiseEntries ?? [];
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final dateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      final isSunday = date.weekday == DateTime.sunday;
      final weekdayName = _getWeekdayShort(date.weekday);
      final targetDayName = dayNames[date.weekday - 1];

      // Check real matching entry
      DateWiseEntryModel? matchingEntry;
      for (final e in existingEntries) {
        if (e.date == dateStr) {
          matchingEntry = e;
          break;
        }
      }

      // Filter timetable for this day of week
      final dayTimetable = (widget.timetable ?? []).where((t) {
        final d = t.dayOfWeek.toLowerCase();
        final td = targetDayName.toLowerCase();
        return d == td || (d.length >= 3 && td.startsWith(d));
      }).toList();

      final int scheduledCount = isSunday ? 0 : (dayTimetable.isNotEmpty ? dayTimetable.length : 7);

      String status;
      String label;
      String details;
      List<PeriodEntryModel> periods = [];
      int attended = 0;

      if (isSunday) {
        status = 'WEEKEND';
        label = 'WEEKEND';
        details = 'College holiday / Sunday';
        attended = 0;
      } else if (matchingEntry != null) {
        periods = matchingEntry.periods;
        int pPresent = 0;
        int pAbsent = 0;
        int pOd = 0;
        int pRecorded = 0;

        for (final p in periods) {
          final st = p.status.toUpperCase();
          if (st == 'PRESENT' || st == 'P') {
            pPresent++;
            pRecorded++;
          } else if (st == 'ABSENT' || st == 'A') {
            pAbsent++;
            pRecorded++;
          } else if (st == 'OD') {
            pOd++;
            pRecorded++;
          }
        }

        attended = pPresent + pOd;
        final totalEffective = pRecorded > 0 ? pRecorded : scheduledCount;

        if (pRecorded == 0) {
          status = 'NO_DATA';
          label = 'NO RECORD';
          details = 'No attendance recorded';
        } else if (pAbsent == 0 && attended > 0) {
          status = (pOd > 0 && pPresent == 0) ? 'OD' : 'PRESENT';
          label = (pOd > 0 && pPresent == 0) ? 'ON-DUTY (OD)' : 'FULL DAY PRESENT';
          details = '$attended of $totalEffective periods attended (${((attended / totalEffective) * 100).toStringAsFixed(0)}%)';
        } else if (attended == 0 && pAbsent > 0) {
          status = 'ABSENT';
          label = 'FULL DAY ABSENT';
          details = '0 of $totalEffective periods attended (0%)';
        } else {
          status = 'PARTIAL';
          label = 'PARTIAL ATTENDANCE';
          details = '$attended of $totalEffective periods attended ($pAbsent absent)';
        }
      } else {
        // Genuine unrecorded day — NEVER synthesize fake P/A/OD!
        final thisDate = DateTime(year, month, day);
        if (thisDate.isAfter(todayDate)) {
          status = 'FUTURE';
          label = 'UPCOMING';
          details = 'Upcoming schedule - Not yet recorded';
        } else if (thisDate.isAtSameMomentAs(todayDate)) {
          status = 'NO_DATA';
          label = 'TODAY (PENDING)';
          details = 'No attendance recorded yet today';
        } else {
          status = 'NO_DATA';
          label = 'NO RECORD';
          details = 'No attendance recorded for this date';
        }
        attended = 0;

        // Populate genuine timetable slots marked as NOT_ENTERED
        if (dayTimetable.isNotEmpty) {
          for (int i = 0; i < dayTimetable.length; i++) {
            final t = dayTimetable[i];
            periods.add(PeriodEntryModel(
              periodNumber: t.periodNumber ?? (i + 1),
              periodName: t.periodName ?? 'Period ${t.periodNumber ?? (i + 1)}',
              subjectCode: t.subjectCode ?? '',
              subjectName: t.subjectName ?? '',
              status: 'NOT_ENTERED',
            ));
          }
        } else {
          final fallbackSlots = _fallbackCurriculum[targetDayName] ?? [];
          for (final s in fallbackSlots) {
            periods.add(PeriodEntryModel(
              periodNumber: int.tryParse(s['num'] ?? '1') ?? 1,
              periodName: 'Period ${s['num']}',
              subjectCode: s['code'] ?? '',
              subjectName: s['name'] ?? '',
              status: 'NOT_ENTERED',
            ));
          }
        }
      }

      final dateEntry = matchingEntry ?? DateWiseEntryModel(
        date: dateStr,
        dailyResult: label,
        morningStatus: status == 'PRESENT' ? 'PRESENT' : (status == 'ABSENT' ? 'ABSENT' : (status == 'OD' ? 'OD' : 'N/A')),
        morningSummary: status == 'PRESENT' ? 'Full attendance' : (status == 'ABSENT' ? 'Absent' : 'No record'),
        afternoonStatus: status == 'PRESENT' ? 'PRESENT' : (status == 'ABSENT' ? 'ABSENT' : (status == 'OD' ? 'OD' : 'N/A')),
        afternoonSummary: status == 'PRESENT' ? 'Full attendance' : (status == 'ABSENT' ? 'Absent' : 'No record'),
        periods: periods,
      );

      list.add(_DayAttendanceData(
        dayNumber: day,
        dateStr: dateStr,
        status: status,
        statusLabel: label,
        formattedDate: '${_monthShortNames[month - 1]} $day, $year ($weekdayName)',
        details: details,
        entry: dateEntry,
        periodsAttended: attended,
        totalPeriods: isSunday ? 0 : scheduledCount,
      ));
    }

    return list;
  }

  String _getWeekdayShort(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
      default:
        return 'Sun';
    }
  }
}

class _DayAttendanceData {
  final int dayNumber;
  final String dateStr;
  final String status; // PRESENT, ABSENT, OD, WEEKEND
  final String statusLabel;
  final String formattedDate;
  final String details;
  final DateWiseEntryModel entry;
  final int periodsAttended;
  final int totalPeriods;

  _DayAttendanceData({
    required this.dayNumber,
    required this.dateStr,
    required this.status,
    required this.statusLabel,
    required this.formattedDate,
    required this.details,
    required this.entry,
    required this.periodsAttended,
    required this.totalPeriods,
  });

  Color statusColor(AppColors colors) {
    switch (status) {
      case 'PRESENT':
        return colors.present;
      case 'ABSENT':
        return colors.absent;
      case 'OD':
        return colors.od;
      case 'PARTIAL':
        return colors.warning;
      case 'WEEKEND':
      case 'NO_DATA':
      case 'FUTURE':
      default:
        return colors.textMuted;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Concentric Glass Activity Rings Custom Painter with Frosted Glassmorphism
// ─────────────────────────────────────────────────────────────────────────────
class ConcentricGlassRingsPainter extends CustomPainter {
  final double presentPct;
  final double absentPct;
  final double odPct;
  final Color presentStartColor;
  final Color presentEndColor;
  final Color absentStartColor;
  final Color absentEndColor;
  final Color odStartColor;
  final Color odEndColor;
  final Color trackColor;
  final double strokeWidth;

  ConcentricGlassRingsPainter({
    required this.presentPct,
    required this.absentPct,
    required this.odPct,
    required this.presentStartColor,
    required this.presentEndColor,
    required this.absentStartColor,
    required this.absentEndColor,
    required this.odStartColor,
    required this.odEndColor,
    required this.trackColor,
    this.strokeWidth = 10.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2 - (strokeWidth / 2);
    final ringSpacing = strokeWidth + 7.5;

    // Outer Ring: Present (Emerald Jade Glass)
    _drawGlassRing(
      canvas: canvas,
      center: center,
      radius: maxRadius,
      percentage: presentPct,
      startColor: presentStartColor,
      endColor: presentEndColor,
      trackColor: trackColor,
    );

    // Middle Ring: Absent (Coral Crimson Glass)
    _drawGlassRing(
      canvas: canvas,
      center: center,
      radius: maxRadius - ringSpacing,
      percentage: absentPct,
      startColor: absentStartColor,
      endColor: absentEndColor,
      trackColor: trackColor,
    );

    // Inner Ring: OD (Electric Sapphire Glass)
    _drawGlassRing(
      canvas: canvas,
      center: center,
      radius: maxRadius - (ringSpacing * 2),
      percentage: odPct,
      startColor: odStartColor,
      endColor: odEndColor,
      trackColor: trackColor,
    );
  }

  void _drawGlassRing({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double percentage,
    required Color startColor,
    required Color endColor,
    required Color trackColor,
  }) {
    if (radius <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. Frosted Glass Track Background
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Subtle specular glass hairline rim on track
    final trackRimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + (strokeWidth / 2)),
      0,
      2 * math.pi,
      false,
      trackRimPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: math.max(0.1, radius - (strokeWidth / 2))),
      0,
      2 * math.pi,
      false,
      trackRimPaint,
    );

    // 2. Glassmorphic Glow Shadow under Progress Arc
    final sweepAngle = (percentage.clamp(0.0, 100.0) / 100.0) * 2 * math.pi;
    if (sweepAngle > 0.005) {
      final glowPaint = Paint()
        ..color = startColor.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 4.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, glowPaint);

      // 3. Vibrant Gradient Progress Arc
      final progressPaint = Paint()
        ..shader = ui.Gradient.sweep(
          center,
          [startColor, endColor],
          [0.0, 1.0],
          TileMode.clamp,
          -math.pi / 2,
          -math.pi / 2 + math.max(sweepAngle, 0.02),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, progressPaint);

      // 4. Subtle Specular Highlight Sheen on Arc
      final sheenPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius + (strokeWidth / 3)),
        -math.pi / 2,
        math.min(sweepAngle, math.pi * 0.7),
        false,
        sheenPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ConcentricGlassRingsPainter oldDelegate) {
    return oldDelegate.presentPct != presentPct ||
        oldDelegate.absentPct != absentPct ||
        oldDelegate.odPct != odPct ||
        oldDelegate.presentStartColor != presentStartColor ||
        oldDelegate.presentEndColor != presentEndColor ||
        oldDelegate.trackColor != trackColor;
  }
}
