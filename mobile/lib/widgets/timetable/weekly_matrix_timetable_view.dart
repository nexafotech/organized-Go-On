import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/student_model.dart';
import '../../utils/timezone_utils.dart';
import 'timetable_session_pop_up.dart';

enum TimetableViewMode {
  weeklyGrid,
  dayAgenda,
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
    this.height = 58.0,
  });
}

class WeeklyMatrixTimetableView extends StatefulWidget {
  final List<TimetableItemModel> items;
  final String title;
  final String? subtitle;
  final Widget? headerTrailing;
  final Widget? topControl;
  final bool showHeader;
  final DateTime? simulatedTime;
  final ValueChanged<TimetableItemModel>? onCardTap;
  final EdgeInsetsGeometry padding;

  const WeeklyMatrixTimetableView({
    Key? key,
    required this.items,
    this.title = 'Class Schedule',
    this.subtitle,
    this.headerTrailing,
    this.topControl,
    this.showHeader = true,
    this.simulatedTime,
    this.onCardTap,
    this.padding = const EdgeInsets.fromLTRB(8, 4, 8, 110),
  }) : super(key: key);

  static const List<ScheduleSlotConfig> slots = [
    ScheduleSlotConfig(periodNumber: 1, label: 'P1', startTime: '08:45 AM', endTime: '09:40 AM', height: 58.0),
    ScheduleSlotConfig(periodNumber: 2, label: 'P2', startTime: '09:40 AM', endTime: '10:35 AM', height: 58.0),
    ScheduleSlotConfig(periodNumber: 3, label: 'P3', startTime: '10:55 AM', endTime: '11:50 AM', height: 58.0),
    ScheduleSlotConfig(periodNumber: 4, label: 'P4', startTime: '11:50 AM', endTime: '12:45 PM', height: 58.0),
    ScheduleSlotConfig(periodNumber: 5, label: 'P5', startTime: '01:45 PM', endTime: '02:40 PM', height: 58.0),
    ScheduleSlotConfig(periodNumber: 6, label: 'P6', startTime: '02:40 PM', endTime: '03:30 PM', height: 58.0),
    ScheduleSlotConfig(periodNumber: 7, label: 'P7', startTime: '03:30 PM', endTime: '04:20 PM', height: 58.0),
  ];

  static const double kBreakHeight = 28.0;
  static const double kTimeColWidth = 46.0;
  static const double kMinDayColWidth = 55.0;

  static String getCardDisplayCode(TimetableItemModel item) {
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
    if (name.toLowerCase().contains('cyber forensics')) return 'CF';
    if (name.toLowerCase().contains('cloud computing')) return 'CC';

    final parts = name.split(' ');
    if (parts.length == 1) return parts[0];
    return parts.map((p) => p.isNotEmpty ? p[0] : '').take(4).join();
  }

  static bool isItemLab(TimetableItemModel item) {
    if (item.type?.toLowerCase() == 'lab') return true;
    if (item.subjectName?.toLowerCase().contains('lab') == true) return true;
    if (item.subjectCode?.toLowerCase().contains('lab') == true) return true;
    return false;
  }

  static TimetableColorPair getPastelColorPair(TimetableItemModel item, bool isDark) {
    final code = getCardDisplayCode(item).toUpperCase();
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
    } else if (code.contains('LIB') ||
        code.contains('IIC') ||
        code.contains('TWM') ||
        code.contains('DAH') ||
        code.contains('DAA') ||
        code.contains('AI') ||
        code.contains('CN') ||
        code.contains('DBMS') ||
        code.contains('ASSOC') ||
        code.contains('CF') ||
        code.contains('CC')) {
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

  @override
  State<WeeklyMatrixTimetableView> createState() => _WeeklyMatrixTimetableViewState();
}

class _WeeklyMatrixTimetableViewState extends State<WeeklyMatrixTimetableView> {
  String? _selectedCardPeriodKey;
  Timer? _liveClockTimer;
  late DateTime _currentTime;

  DateTime get _now => widget.simulatedTime ?? _currentTime;

  static const List<Map<String, dynamic>> _matrixDays = [
    {'code': 'MONDAY', 'label': 'Mon', 'offset': 0},
    {'code': 'TUESDAY', 'label': 'Tue', 'offset': 1},
    {'code': 'WEDNESDAY', 'label': 'Wed', 'offset': 2},
    {'code': 'THURSDAY', 'label': 'Thu', 'offset': 3},
    {'code': 'FRIDAY', 'label': 'Fri', 'offset': 4},
    {'code': 'SATURDAY', 'label': 'Sat', 'offset': 5},
    {'code': 'SUNDAY', 'label': 'Sun', 'offset': 6},
  ];

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _startLiveTicker();
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
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  String _getCurrentWeekdayName() {
    return TimezoneUtils.istWeekdayName().toUpperCase();
  }

  bool _isToday(String day) {
    return day.toUpperCase() == _getCurrentWeekdayName();
  }

  DateTime _getDateForWeekday(int weekdayIndex) {
    final nowIst = TimezoneUtils.toIst(_now);
    final monday = DateTime(nowIst.year, nowIst.month, nowIst.day)
        .subtract(Duration(days: nowIst.weekday - 1));
    return monday.add(Duration(days: weekdayIndex));
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
    final startMin = _parseTimeToMinutes(item.startTime);
    final endMin = _parseTimeToMinutes(item.endTime);
    if (startMin == -1 || endMin == -1) return false;
    final nowIst = TimezoneUtils.toIst(_now);
    final nowMin = nowIst.hour * 60 + nowIst.minute;
    return nowMin >= startMin && nowMin < endMin;
  }

  double _getTotalSlotsHeight() {
    return WeeklyMatrixTimetableView.slots.fold(0.0, (sum, s) => sum + s.height);
  }

  double _getSlotTop(int slotIndex) {
    double top = 0;
    for (int i = 0; i < slotIndex && i < WeeklyMatrixTimetableView.slots.length; i++) {
      top += WeeklyMatrixTimetableView.slots[i].height;
    }
    return top;
  }

  int _mapPeriodToSlotIndex(int periodNumber) {
    final idx = WeeklyMatrixTimetableView.slots.indexWhere((s) => s.periodNumber == periodNumber);
    return idx != -1 ? idx : 0;
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
        final isLab = WeeklyMatrixTimetableView.isItemLab(item);

        int lookahead = i + 1;
        while (lookahead < items.length) {
          final nextItem = items[lookahead];
          final nextPNum = nextItem.periodNumber;
          if (nextPNum == null) break;

          final bool isConsecutive = nextPNum == pNum + span;
          final bool sameBlock = _arePeriodsInSameBlock(pNum, nextPNum);
          final bool sameSubject = (nextItem.subjectCode ?? nextItem.subjectName ?? '').trim() == code ||
              (isLab && WeeklyMatrixTimetableView.isItemLab(nextItem));

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
        if (curSlot < WeeklyMatrixTimetableView.slots.length) {
          h += WeeklyMatrixTimetableView.slots[curSlot].height;
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

  void _showClassDetailsModal(TimetableItemModel item) {
    TimetableSessionPopUp.showFromItem(context, item);
  }


  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final double totalHeight = _getTotalSlotsHeight();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) _buildHeader(colors),
        if (widget.topControl != null) widget.topControl!,
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final double totalMinNeeded = WeeklyMatrixTimetableView.kTimeColWidth +
                  (_matrixDays.length * WeeklyMatrixTimetableView.kMinDayColWidth) +
                  16.0;
              final bool needsHorizontalScroll = totalMinNeeded > availableWidth;

              final double dayColWidth = needsHorizontalScroll
                  ? WeeklyMatrixTimetableView.kMinDayColWidth
                  : (availableWidth - WeeklyMatrixTimetableView.kTimeColWidth - 16.0) /
                      _matrixDays.length;

              final double tableWidth =
                  WeeklyMatrixTimetableView.kTimeColWidth + (_matrixDays.length * dayColWidth);

              Widget matrixContent = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMatrixDayHeadersRow(_matrixDays, dayColWidth, colors),
                  const SizedBox(height: 10),
                  _buildMatrixBody(_matrixDays, widget.items, dayColWidth, totalHeight, colors),
                ],
              );

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: widget.padding,
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
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(AppColors colors) {
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
                  widget.title,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                    color: colors.textPrimary,
                  ),
                ),
                if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    widget.subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (widget.headerTrailing != null) widget.headerTrailing!,
        ],
      ),
    );
  }

  Widget _buildMatrixDayHeadersRow(
    List<Map<String, dynamic>> matrixDays,
    double dayColWidth,
    AppColors colors,
  ) {
    return Row(
      children: [
        const SizedBox(width: WeeklyMatrixTimetableView.kTimeColWidth),
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
    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          // 1. Time Rail on the Left
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: WeeklyMatrixTimetableView.kTimeColWidth,
            child: Stack(
              children: [
                ...WeeklyMatrixTimetableView.slots.asMap().entries.map((entry) {
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
            final double left = WeeklyMatrixTimetableView.kTimeColWidth + (colIdx * dayColWidth);

            final dayItems = allItems.where((i) {
              return i.dayOfWeek.toUpperCase() == dayCode.toUpperCase();
            }).toList();

            final mergedItems = _prepareMergedDayItems(dayItems);
            final Set<int> occupiedPeriods = {};
            for (final m in mergedItems) {
              final pStart = m.item.periodNumber;
              if (pStart != null) {
                for (int p = 0; p < m.span; p++) {
                  occupiedPeriods.add(pStart + p);
                }
              }
            }

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

                  // Empty slot placeholders for unscheduled / free periods
                  ...WeeklyMatrixTimetableView.slots.asMap().entries.map((slotEntry) {
                    final slot = slotEntry.value;
                    if (slot.isBreak) return const SizedBox.shrink();
                    if (occupiedPeriods.contains(slot.periodNumber)) return const SizedBox.shrink();

                    final top = _getSlotTop(slotEntry.key) + 2.5;
                    final height = slot.height - 5.0;

                    return Positioned(
                      top: top,
                      left: 2.5,
                      right: 2.5,
                      height: height,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.isDark
                              ? Colors.white.withValues(alpha: 0.02)
                              : const Color(0xFFF9FAFB).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.isDark
                                ? colors.border.withValues(alpha: 0.15)
                                : const Color(0xFFE5E7EB).withValues(alpha: 0.6),
                            width: 0.8,
                          ),
                        ),
                      ),
                    );
                  }),

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

        ],
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
    final colorPair = WeeklyMatrixTimetableView.getPastelColorPair(item, colors.isDark);
    final displayCode = WeeklyMatrixTimetableView.getCardDisplayCode(item);
    final isLab = WeeklyMatrixTimetableView.isItemLab(item);
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
            if (widget.onCardTap != null) {
              widget.onCardTap!(item);
            } else {
              _showClassDetailsModal(item);
            }
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
}

/// Matches the reference design's view toggle icon button (two thick rounded horizontal bars)
class TimetableToggleMenuIcon extends StatelessWidget {
  final bool isWeeklyGrid;
  final VoidCallback? onTap;

  const TimetableToggleMenuIcon({
    Key? key,
    this.isWeeklyGrid = true,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 38,
        height: 38,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: colors.isDark ? colors.surfaceElevated : const Color(0xFFEBE7DF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: isWeeklyGrid
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 17,
                      height: 3.5,
                      decoration: BoxDecoration(
                        color: colors.isDark ? Colors.white : const Color(0xFF261E1A),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 3.5),
                    Container(
                      width: 17,
                      height: 3.5,
                      decoration: BoxDecoration(
                        color: colors.isDark ? Colors.white : const Color(0xFF261E1A),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              )
            : Icon(
                Icons.grid_view_rounded,
                size: 20,
                color: colors.textPrimary,
              ),
      ),
    );
  }
}
