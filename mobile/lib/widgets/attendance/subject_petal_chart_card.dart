import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/student_model.dart';
import '../../utils/timezone_utils.dart';

/// Live state of a class period throughout the college day
enum PeriodLiveState {
  upcoming,
  inProgress,
  completed,
}

/// Truthful attendance & schedule status for each period
enum PeriodAttendanceStatus {
  present,       // Attended (Recorded as Present or OD)
  absent,        // Recorded as Absent
  od,            // Recorded as On-Duty
  inProgress,    // Live right now
  upcoming,      // Not yet started
  unrecorded,    // Period time passed, but attendance not yet submitted
}

/// Class item bound with its timetable schedule and calculated chromatic fade
class SubjectClassItem {
  final SubjectAttendanceModel subject;
  final TimetableItemModel? timetable;
  final int index;
  final int totalCount;
  final Color petalColor;
  final Color textColor;
  final double sweepFraction;
  final int startMinutes;
  final int endMinutes;
  final double remainingFraction; // 1.0 (full) down to 0.0 (dark/completed)
  final double elapsedProgress;   // 0.0 to 1.0
  final PeriodLiveState liveState;
  final PeriodAttendanceStatus attendanceStatus;
  final String? statusLabel;

  const SubjectClassItem({
    required this.subject,
    this.timetable,
    required this.index,
    required this.totalCount,
    required this.petalColor,
    required this.textColor,
    required this.sweepFraction,
    required this.startMinutes,
    required this.endMinutes,
    required this.remainingFraction,
    required this.elapsedProgress,
    required this.liveState,
    required this.attendanceStatus,
    this.statusLabel,
  });

  String get displayName => subject.subjectName;
  String get code => subject.subjectCode;

  String get shortName {
    final name = subject.subjectName.trim();
    if (name.toLowerCase().contains('algorithm')) return 'DAA';
    if (name.toLowerCase().contains('network')) return 'Networks';
    if (name.toLowerCase().contains('database') || name.toLowerCase().contains('dbms')) return 'DBMS';
    if (name.toLowerCase().contains('web dev')) return 'Web Dev';
    if (name.toLowerCase().contains('intelligence') || name.toLowerCase().contains('ai')) return 'AI & ML';
    if (name.toLowerCase().contains('cloud') || name.toLowerCase().contains('devops')) return 'Cloud';
    if (name.toLowerCase().contains('mobile')) return 'Mobile App';

    final parts = name.split(' ');
    if (parts.length >= 2 && parts[0].length <= 8) {
      return '${parts[0]} ${parts[1]}';
    }
    return parts.first;
  }

  String get periodLabel => timetable?.periodName ?? 'Class ${index + 1}';

  String? get timeSlot {
    if (timetable?.startTime != null && timetable?.endTime != null) {
      return '${timetable!.startTime} - ${timetable!.endTime}';
    }
    return timetable?.startTime;
  }

  String get simpleStartTime {
    if (timetable?.startTime != null) {
      return timetable!.startTime!.replaceAll(' ', '');
    }
    return 'Period ${index + 1}';
  }

  int get durationMinutes => endMinutes - startMinutes;
}

/// Subject Petal Chart Card (Nightingale Rose / Period Progression Polar Area Chart)
/// Features:
/// 1. Period Completion Progression:
///    - Starts completely FULL (luminous light petals).
///    - As each class hour passes, its petal decreases from outer radius down to the center.
///    - When a class ends, it becomes completely DARK (denoting that period is completed).
///    - At the final hour, all completed petals are dark, denoting that all classes are done for the day.
/// 2. Interactive Apple Liquid Day Scrubber:
///    - Interactive slider to scrub time from 08:00 AM to 03:00 PM.
///    - Play/Pause automated day simulation.
///    - Real-time live clock sync in IST.
///    - One-tap quick period shortcuts.
/// 3. Liquid Glass UI & Apple visionOS optics with specular reflections.
class SubjectPetalChartCard extends StatefulWidget {
  final List<SubjectAttendanceModel> subjects;
  final List<TimetableItemModel>? timetable;
  final List<DateWiseEntryModel>? dateWiseEntries;
  final DateTime? targetDate;
  final double minimumRequired;

  const SubjectPetalChartCard({
    Key? key,
    required this.subjects,
    this.timetable,
    this.dateWiseEntries,
    this.targetDate,
    this.minimumRequired = 75.0,
  }) : super(key: key);

  @override
  State<SubjectPetalChartCard> createState() => _SubjectPetalChartCardState();
}

class _SubjectPetalChartCardState extends State<SubjectPetalChartCard>
    with TickerProviderStateMixin {
  bool _showListView = false;
  int? _selectedIndex;

  // Day Progression Time State (in minutes from midnight)
  double _currentDayMinutes = 550.0;
  Timer? _liveClockTimer;

  late AnimationController _bloomController;
  late Animation<double> _bloomAnimation;

  static const double minDayMinutes = 500.0; // 08:20 AM
  static const double maxDayMinutes = 1040.0; // 05:20 PM (covers full 7-8 period day)

  @override
  void initState() {
    super.initState();
    _bloomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _bloomAnimation = CurvedAnimation(
      parent: _bloomController,
      curve: Curves.easeOutBack,
    );
    _bloomController.forward();

    // Automatically sync to current day minutes & update every minute
    _syncToCurrentTime();
    _liveClockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        _syncToCurrentTime();
      }
    });
  }

  @override
  void dispose() {
    _liveClockTimer?.cancel();
    _bloomController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SubjectPetalChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subjects.length != widget.subjects.length) {
      _bloomController.forward(from: 0.0);
    }
  }

  static int _parseTimeToMinutes(String? timeStr, int defaultH, int defaultM) {
    if (timeStr == null || timeStr.trim().isEmpty) return defaultH * 60 + defaultM;
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final numOnly = clean.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = numOnly.split(':');
      int h = int.parse(parts[0]);
      int m = parts.length > 1 ? int.parse(parts[1]) : 0;
      if (isPm && h < 12) h += 12;
      if (isAm && h == 12) h = 0;
      return h * 60 + m;
    } catch (_) {
      return defaultH * 60 + defaultM;
    }
  }

  void _syncToCurrentTime() {
    final now = TimezoneUtils.nowIst();
    setState(() {
      _currentDayMinutes = (now.hour * 60 + now.minute).toDouble().clamp(minDayMinutes, maxDayMinutes);
    });
  }

  /// Curated chromatic progression that smoothly transitions from a luminous
  /// warm pearlescent cream (morning/first class) down to deep graphite charcoal (afternoon/last class).
  static Color _interpolateTimeColor(double t) {
    const c0 = Color(0xFFF7F5EE); // 0.00: Luminous Pearl Cream
    const c1 = Color(0xFFE4DFEB); // 0.25: Soft Lavender Mist
    const c2 = Color(0xFFC5BDD3); // 0.50: Muted Lilac
    const c3 = Color(0xFF867D97); // 0.75: Slate Violet
    const c4 = Color(0xFF383542); // 1.00: Deep Graphite Charcoal

    if (t <= 0.0) return c0;
    if (t >= 1.0) return c4;

    if (t < 0.25) {
      return Color.lerp(c0, c1, t / 0.25)!;
    } else if (t < 0.50) {
      return Color.lerp(c1, c2, (t - 0.25) / 0.25)!;
    } else if (t < 0.75) {
      return Color.lerp(c2, c3, (t - 0.50) / 0.25)!;
    } else {
      return Color.lerp(c3, c4, (t - 0.75) / 0.25)!;
    }
  }

  List<SubjectClassItem> _buildClassItems() {
    // 1. Determine target date and weekday in Asia/Kolkata
    final target = widget.targetDate ?? TimezoneUtils.todayIst();
    final targetIso = TimezoneUtils.dateToIsoString(target);
    final todayIso = TimezoneUtils.dateToIsoString(TimezoneUtils.todayIst());
    final isToday = targetIso == todayIso;
    final weekdayName = TimezoneUtils.weekdayNameFor(target);

    // 2. Build rapid lookup table of subjects by uppercase code and name
    final subjectMap = <String, SubjectAttendanceModel>{};
    for (final subj in widget.subjects) {
      if (subj.subjectCode.isNotEmpty) {
        subjectMap[subj.subjectCode.toUpperCase()] = subj;
      }
      if (subj.subjectName.isNotEmpty) {
        subjectMap[subj.subjectName.toUpperCase()] = subj;
      }
    }

    // 3. Extract periods for this target date from authoritative timetable
    List<TimetableItemModel> daySchedule = [];
    if (widget.timetable != null && widget.timetable!.isNotEmpty) {
      for (final tt in widget.timetable!) {
        if (tt.dayOfWeek.trim().toUpperCase() == weekdayName) {
          daySchedule.add(tt);
        }
      }
    }

    // CRITICAL FIX: If no classes are scheduled for this day (e.g. Sunday or non-working day),
    // NEVER fall back to Monday and NEVER fall back to semester subjects!
    // Return empty list so _buildNoClassesCard() is rendered truthfully.
    if (daySchedule.isEmpty) {
      return [];
    }

    // Sort periods strictly by periodNumber, then startTime
    daySchedule.sort((a, b) {
      final pA = a.periodNumber ?? 999;
      final pB = b.periodNumber ?? 999;
      if (pA != pB) return pA.compareTo(pB);
      final tA = a.startTime ?? '';
      final tB = b.startTime ?? '';
      return tA.compareTo(tB);
    });

    // 4. Match with real attendance records from dateWiseEntries
    DateWiseEntryModel? matchingDayEntry;
    if (widget.dateWiseEntries != null) {
      for (final entry in widget.dateWiseEntries!) {
        if (entry.date.trim() == targetIso) {
          matchingDayEntry = entry;
          break;
        }
      }
    }

    final periodEntryMap = <int, PeriodEntryModel>{};
    if (matchingDayEntry != null) {
      for (final p in matchingDayEntry.periods) {
        if (p.periodNumber != null) {
          periodEntryMap[p.periodNumber!] = p;
        }
      }
    }

    const defaultTimes = [
      (start: 525, end: 580), // P1: 08:45 AM - 09:40 AM
      (start: 580, end: 635), // P2: 09:40 AM - 10:35 AM
      (start: 655, end: 710), // P3: 10:55 AM - 11:50 AM
      (start: 710, end: 765), // P4: 11:50 AM - 12:45 PM
      (start: 825, end: 880), // P5: 01:45 PM - 02:40 PM
      (start: 880, end: 930), // P6: 02:40 PM - 03:30 PM
      (start: 930, end: 980), // P7: 03:30 PM - 04:20 PM
      (start: 980, end: 1030), // P8: 04:20 PM - 05:10 PM
    ];

    final total = daySchedule.length;
    return List.generate(total, (i) {
      final tt = daySchedule[i];
      final codeKey = (tt.subjectCode ?? '').toUpperCase();
      final nameKey = (tt.subjectName ?? '').toUpperCase();
      var matched = subjectMap[codeKey] ?? subjectMap[nameKey];

      // Fallback subject model if not explicitly in attendance roster yet
      matched ??= SubjectAttendanceModel(
        subjectId: tt.periodNumber ?? (i + 1),
        subjectCode: tt.subjectCode ?? 'P${tt.periodNumber ?? (i + 1)}',
        subjectName: tt.subjectName ?? tt.periodName ?? 'Period ${tt.periodNumber ?? (i + 1)}',
        total: 0,
        present: 0,
        absent: 0,
        od: 0,
        percentage: 0.0,
      );

      final double t = total > 1 ? (i / (total - 1)) : 0.0;
      final petalColor = _interpolateTimeColor(t);

      final def = i < defaultTimes.length ? defaultTimes[i] : (start: 525 + i * 55, end: 580 + i * 55);
      final int startM = _parseTimeToMinutes(tt.startTime, def.start ~/ 60, def.start % 60);
      final int endM = _parseTimeToMinutes(tt.endTime, def.end ~/ 60, def.end % 60);

      final periodNum = tt.periodNumber ?? (i + 1);
      final periodEntry = periodEntryMap[periodNum];

      PeriodAttendanceStatus attendanceStatus;
      PeriodLiveState liveState;
      double remaining = 1.0;
      double elapsed = 0.0;
      String? statusLabel;

      final rawStatus = periodEntry?.status.trim().toUpperCase() ?? 'NOT_ENTERED';
      final hasRealPresent = rawStatus == 'PRESENT' || rawStatus == 'P';
      final hasRealAbsent = rawStatus == 'ABSENT' || rawStatus == 'A';
      final hasRealOd = rawStatus == 'OD';

      if (hasRealPresent) {
        attendanceStatus = PeriodAttendanceStatus.present;
        liveState = PeriodLiveState.completed;
        remaining = 0.0;
        elapsed = 1.0;
        statusLabel = 'Present ✓';
      } else if (hasRealAbsent) {
        attendanceStatus = PeriodAttendanceStatus.absent;
        liveState = PeriodLiveState.completed;
        remaining = 0.0;
        elapsed = 1.0;
        statusLabel = 'Absent ✗';
      } else if (hasRealOd) {
        attendanceStatus = PeriodAttendanceStatus.od;
        liveState = PeriodLiveState.completed;
        remaining = 0.0;
        elapsed = 1.0;
        statusLabel = 'On-Duty';
      } else {
        // Attendance record has NOT been submitted yet by faculty
        if (isToday) {
          if (_currentDayMinutes < startM) {
            attendanceStatus = PeriodAttendanceStatus.upcoming;
            liveState = PeriodLiveState.upcoming;
            remaining = 1.0;
            elapsed = 0.0;
            statusLabel = tt.startTime ?? 'Upcoming';
          } else if (_currentDayMinutes >= endM) {
            // Period time elapsed, but NO attendance record entered: mark as Pending, NEVER Done!
            attendanceStatus = PeriodAttendanceStatus.unrecorded;
            liveState = PeriodLiveState.completed;
            remaining = 0.0;
            elapsed = 1.0;
            statusLabel = 'Pending';
          } else {
            // Currently active / in progress
            attendanceStatus = PeriodAttendanceStatus.inProgress;
            liveState = PeriodLiveState.inProgress;
            elapsed = ((_currentDayMinutes - startM) / (endM - startM)).clamp(0.0, 1.0);
            remaining = (1.0 - elapsed).clamp(0.0, 1.0);
            statusLabel = 'Live';
          }
        } else if (target.isBefore(TimezoneUtils.todayIst())) {
          // Past date with no recorded attendance
          attendanceStatus = PeriodAttendanceStatus.unrecorded;
          liveState = PeriodLiveState.completed;
          remaining = 0.0;
          elapsed = 1.0;
          statusLabel = 'No Record';
        } else {
          // Future date
          attendanceStatus = PeriodAttendanceStatus.upcoming;
          liveState = PeriodLiveState.upcoming;
          remaining = 1.0;
          elapsed = 0.0;
          statusLabel = tt.startTime ?? 'Upcoming';
        }
      }

      final bool isLight = (attendanceStatus == PeriodAttendanceStatus.upcoming)
          ? petalColor.computeLuminance() > 0.45
          : false;
      final textColor = isLight ? const Color(0xFF0F172A) : Colors.white;

      return SubjectClassItem(
        subject: matched,
        timetable: tt,
        index: i,
        totalCount: total,
        petalColor: petalColor,
        textColor: textColor,
        sweepFraction: total > 0 ? (1.0 / total) : 1.0,
        startMinutes: startM,
        endMinutes: endM,
        remainingFraction: remaining,
        elapsedProgress: elapsed,
        liveState: liveState,
        attendanceStatus: attendanceStatus,
        statusLabel: statusLabel,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = _buildClassItems();

    if (items.isEmpty) {
      return _buildNoClassesCard(context);
    }

    final selectedItem = (_selectedIndex != null && _selectedIndex! < items.length)
        ? items[_selectedIndex!]
        : items.first;

    final double overallAvg = items.map((e) => e.subject.percentage).reduce((a, b) => a + b) / items.length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppGlass.shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.glassSurfaceStrong,
                  colors.glassSurface,
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: colors.glassBorderStrong,
                width: 1.2,
              ),
            ),
            child: Stack(
              children: [
                // Ambient soft liquid orbs
                Positioned(
                  top: -40,
                  right: -40,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFE8DAC8).withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  left: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFD6E8DE).withValues(alpha: 0.20),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(items),

                      const SizedBox(height: 16),

                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 320),
                        crossFadeState: _showListView
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: _buildPetalGraphSection(items, selectedItem, overallAvg),
                        secondChild: _buildListViewSection(items),
                      ),
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

  /// Truthful Empty State rendered when no classes are scheduled (e.g. Sunday or holiday)
  Widget _buildNoClassesCard(BuildContext context) {
    final colors = context.colors;
    final target = widget.targetDate ?? TimezoneUtils.todayIst();
    final weekdayName = TimezoneUtils.weekdayNameFor(target);
    final isSunday = target.weekday == DateTime.sunday;
    final dateFormatted = TimezoneUtils.formatIstDate(target);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppGlass.shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.glassSurfaceStrong,
                  colors.glassSurface,
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: colors.glassBorderStrong,
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Today's Schedule",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.textMuted.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colors.textMuted.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            isSunday ? 'Sunday Holiday' : 'No Classes',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Center Peaceful Icon
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.glassSurfaceSubtle,
                      border: Border.all(
                        color: colors.glassBorderStrong,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      isSunday ? Icons.hotel_class_rounded : Icons.event_busy_rounded,
                      size: 34,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'No Classes Scheduled Today',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    isSunday
                        ? 'Sunday is not a scheduled working day for your class timetable.'
                        : 'No periods scheduled in the academic timetable for $weekdayName ($dateFormatted).',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Informative Status Chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.glassSurfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.glassBorder, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_busy_outlined, size: 14, color: colors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            '0 Scheduled Periods',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.glassSurfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.glassBorder, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.weekend_outlined, size: 14, color: colors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            isSunday ? 'Weekend Rest Day' : 'Academic Recess',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Header with Title, Live Status Subtitle, and View Toggle
  Widget _buildHeader(List<SubjectClassItem> items) {
    final colors = context.colors;
    final recordedItems = items.where((e) =>
        e.attendanceStatus == PeriodAttendanceStatus.present ||
        e.attendanceStatus == PeriodAttendanceStatus.absent ||
        e.attendanceStatus == PeriodAttendanceStatus.od
    ).toList();
    final recordedCount = recordedItems.length;
    final attendedCount = items.where((e) =>
        e.attendanceStatus == PeriodAttendanceStatus.present ||
        e.attendanceStatus == PeriodAttendanceStatus.od
    ).length;
    final inProgressItem = items.where((e) => e.attendanceStatus == PeriodAttendanceStatus.inProgress).firstOrNull;

    String statusText;
    if (recordedCount == items.length) {
      statusText = 'All ${items.length} classes recorded today ($attendedCount attended)';
    } else if (recordedCount > 0) {
      statusText = '$recordedCount of ${items.length} classes recorded ($attendedCount attended)';
    } else if (inProgressItem != null) {
      statusText = '${inProgressItem.periodLabel} in progress • Awaiting attendance submission';
    } else if (items.any((e) => e.attendanceStatus == PeriodAttendanceStatus.unrecorded)) {
      statusText = 'Periods concluded • Awaiting faculty attendance submission';
    } else {
      statusText = "Today's schedule ready • 0 of ${items.length} recorded";
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    "Today's Schedule",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: colors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: recordedCount > 0
                          ? colors.present.withValues(alpha: 0.15)
                          : colors.textMuted.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: recordedCount > 0
                            ? colors.present.withValues(alpha: 0.4)
                            : colors.textMuted.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '$recordedCount/${items.length} Recorded',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: recordedCount > 0
                            ? colors.present
                            : colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 3),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),

      // Apple Segmented Switch: Chart vs List
      Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: colors.glassSurfaceSubtle,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colors.glassBorder,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSegmentPill(
                icon: Icons.pie_chart_rounded,
                label: 'Petal',
                isSelected: !_showListView,
                colors: colors,
                onTap: () {
                  if (_showListView) {
                    setState(() => _showListView = false);
                    _bloomController.forward(from: 0.0);
                  }
                },
              ),
              _buildSegmentPill(
                icon: Icons.view_agenda_rounded,
                label: 'List',
                isSelected: _showListView,
                colors: colors,
                onTap: () {
                  if (!_showListView) {
                    setState(() => _showListView = true);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentPill({
    required IconData icon,
    required String label,
    required bool isSelected,
    required AppColors colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isSelected ? AppGlass.shadow : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? colors.onPrimary : colors.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? colors.onPrimary : colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Main Nightingale Petal Chart Section with Time Progression
  Widget _buildPetalGraphSection(
    List<SubjectClassItem> items,
    SubjectClassItem selectedItem,
    double overallAvg,
  ) {
    return Column(
      children: [
        const SizedBox(height: 8),

        // Nightingale Petal Custom Canvas
        Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartSize = math.min(constraints.maxWidth, 320.0).clamp(200.0, 320.0);
              return AnimatedBuilder(
                animation: _bloomAnimation,
                builder: (context, _) {
                  return SizedBox(
                    width: chartSize,
                    height: chartSize,
                    child: GestureDetector(
                      onTapUp: (details) => _handleChartTap(details.localPosition, items, chartSize),
                      child: CustomPaint(
                        size: Size(chartSize, chartSize),
                        painter: _NightingalePetalPainter(
                          items: items,
                          selectedIndex: _selectedIndex,
                          bloomProgress: _bloomAnimation.value,
                          overallAvg: overallAvg,
                          currentDayMinutes: _currentDayMinutes,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        const SizedBox(height: 18),

        // Time-wise Fading Timeline Bar with dynamic live period status
        _buildTimeWiseFadingBar(items),

        const SizedBox(height: 16),

        // Selected Subject Apple Frosted Glass Card
        _buildSelectedSubjectCard(selectedItem),
      ],
    );
  }

  /// Tap Handler converting polar coordinates to clicked petal index
  void _handleChartTap(Offset localPos, List<SubjectClassItem> items, double size) {
    final center = Offset(size / 2, size / 2);
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);

    const double rInner = 44.0;
    final double rOuterMax = (size / 2) - 12.0;

    if (dist < rInner) {
      setState(() => _selectedIndex = null);
      return;
    }

    if (dist <= rOuterMax + 14.0) {
      double angle = math.atan2(dy, dx);
      angle = (angle + math.pi / 2);
      if (angle < 0) angle += 2 * math.pi;

      final sliceAngle = (2 * math.pi) / items.length;
      final index = (angle / sliceAngle).floor() % items.length;

      setState(() {
        _selectedIndex = index;
      });
    }
  }

  /// Time-wise Fading Timeline Bar with dynamic state indicators
  Widget _buildTimeWiseFadingBar(List<SubjectClassItem> items) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppGlass.shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.glassSurfaceSubtle,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.glassBorderStrong,
                width: 0.9,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'DAILY CLASS PERIOD STATUS',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: colors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Real-time Period Status',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: List.generate(items.length, (index) {
                      final item = items[index];
                      final isSelected = _selectedIndex == index;

                      String stateLabel;
                      Color gemColor;
                      Color stateTextColor = colors.textSecondary;

                      switch (item.attendanceStatus) {
                        case PeriodAttendanceStatus.present:
                          stateLabel = 'Present ✓';
                          gemColor = colors.present;
                          stateTextColor = colors.present;
                          break;
                        case PeriodAttendanceStatus.absent:
                          stateLabel = 'Absent ✗';
                          gemColor = colors.absent;
                          stateTextColor = colors.absent;
                          break;
                        case PeriodAttendanceStatus.od:
                          stateLabel = 'On-Duty';
                          gemColor = colors.od;
                          stateTextColor = colors.od;
                          break;
                        case PeriodAttendanceStatus.inProgress:
                          stateLabel = '${(item.remainingFraction * 100).toInt()}% left';
                          gemColor = colors.present;
                          stateTextColor = colors.present;
                          break;
                        case PeriodAttendanceStatus.unrecorded:
                          stateLabel = 'Pending';
                          gemColor = colors.textMuted;
                          stateTextColor = colors.textMuted;
                          break;
                        case PeriodAttendanceStatus.upcoming:
                          stateLabel = item.simpleStartTime;
                          gemColor = item.petalColor;
                          stateTextColor = colors.textSecondary;
                          break;
                      }

                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedIndex = index);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.primary.withValues(alpha: 0.12)
                                : (item.attendanceStatus == PeriodAttendanceStatus.unrecorded
                                    ? colors.surfaceMuted
                                    : colors.glassSurface),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? colors.primary
                                  : (item.attendanceStatus == PeriodAttendanceStatus.inProgress
                                      ? colors.present
                                      : (item.attendanceStatus == PeriodAttendanceStatus.present
                                          ? colors.present.withValues(alpha: 0.5)
                                          : colors.glassBorder)),
                              width: isSelected ? 1.5 : 0.8,
                            ),
                            boxShadow: isSelected ? AppGlass.shadow : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 17,
                                height: 17,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: gemColor,
                                  border: Border.all(
                                    color: const Color(0xFF383542).withValues(alpha: 0.35),
                                    width: 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2B1A13).withValues(alpha: 0.15),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    '${item.index + 1}',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: gemColor.computeLuminance() > 0.45
                                          ? const Color(0xFF1B1922)
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item.shortName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? colors.primary
                                          : (item.attendanceStatus == PeriodAttendanceStatus.unrecorded
                                              ? colors.textMuted
                                              : colors.textPrimary),
                                    ),
                                  ),
                                  Text(
                                    stateLabel,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: (item.attendanceStatus == PeriodAttendanceStatus.inProgress ||
                                              item.attendanceStatus == PeriodAttendanceStatus.present)
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: stateTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Selected Subject Apple Frosted Glass Card
  Widget _buildSelectedSubjectCard(SubjectClassItem item) {
    final colors = context.colors;
    final hasSubjectHistory = item.subject.total > 0;
    final isSafe = hasSubjectHistory && item.subject.percentage >= widget.minimumRequired;
    final statusColor = hasSubjectHistory
        ? (isSafe ? colors.present : colors.absent)
        : colors.textMuted;

    String liveStatusText;
    Color liveBadgeColor;

    switch (item.attendanceStatus) {
      case PeriodAttendanceStatus.present:
        liveStatusText = 'Present ✓';
        liveBadgeColor = colors.present;
        break;
      case PeriodAttendanceStatus.absent:
        liveStatusText = 'Absent ✗';
        liveBadgeColor = colors.absent;
        break;
      case PeriodAttendanceStatus.od:
        liveStatusText = 'On-Duty';
        liveBadgeColor = colors.od;
        break;
      case PeriodAttendanceStatus.inProgress:
        final leftM = (item.endMinutes - _currentDayMinutes).toInt();
        liveStatusText = 'In Progress (${leftM}m)';
        liveBadgeColor = colors.present;
        break;
      case PeriodAttendanceStatus.unrecorded:
        liveStatusText = 'Pending';
        liveBadgeColor = colors.warning;
        break;
      case PeriodAttendanceStatus.upcoming:
        liveStatusText = 'Starts ${item.simpleStartTime}';
        liveBadgeColor = colors.od;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppGlass.shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.glassSurfaceSubtle,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colors.glassBorderStrong,
                width: 1.1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 150),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                center: const Alignment(-0.3, -0.3),
                                radius: 0.8,
                                colors: [Colors.white, item.petalColor],
                              ),
                              border: Border.all(color: Colors.white, width: 1.2),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              item.timeSlot != null
                                  ? '${item.periodLabel} • ${item.timeSlot}'
                                  : item.periodLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Live Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: liveBadgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: liveBadgeColor.withValues(alpha: 0.65), width: 0.9),
                      ),
                      child: Text(
                        liveStatusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: liveBadgeColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Code: ${item.code}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: statusColor, width: 1.2),
                      ),
                      child: Text(
                        hasSubjectHistory ? '${item.subject.percentage.toStringAsFixed(1)}%' : '--',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    children: [
                      Container(
                        height: 6,
                        color: colors.border.withValues(alpha: 0.45),
                      ),
                      FractionallySizedBox(
                        widthFactor: (item.subject.percentage / 100.0).clamp(0.0, 1.0),
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                item.petalColor,
                                statusColor,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatChip('Total', '${item.subject.total}', colors: colors),
                    _buildStatChip('Present', '${item.subject.present}', color: colors.present, colors: colors),
                    _buildStatChip('Absent', '${item.subject.absent}', color: colors.absent, colors: colors),
                    _buildStatChip('On-Duty', '${item.subject.od}', color: colors.od, colors: colors),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, {Color? color, required AppColors colors}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2.5),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        decoration: BoxDecoration(
          color: colors.glassSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.glassBorder, width: 0.8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color ?? colors.textPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                color: colors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// List View Section (Card List Mode)
  Widget _buildListViewSection(List<SubjectClassItem> items) {
    final colors = context.colors;
    return Column(
      children: items.map((item) {
        final hasSubjectHistory = item.subject.total > 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: colors.glassSurfaceSubtle,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colors.glassBorderStrong,
              width: 1.0,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Builder(
              builder: (context) {
                final badgeColor = (item.attendanceStatus == PeriodAttendanceStatus.present
                    ? colors.present
                    : (item.attendanceStatus == PeriodAttendanceStatus.absent
                        ? colors.absent
                        : (item.attendanceStatus == PeriodAttendanceStatus.od
                            ? colors.od
                            : item.petalColor)));
                return Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: badgeColor,
                    border: Border.all(
                      color: const Color(0xFF383542).withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2B1A13).withValues(alpha: 0.14),
                        blurRadius: 4,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${item.index + 1}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: badgeColor.computeLuminance() > 0.45
                            ? const Color(0xFF1B1922)
                            : Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
            title: Text(
              item.displayName,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: colors.textPrimary,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 3.0),
              child: Text(
                '${item.periodLabel} • ${item.timeSlot ?? item.simpleStartTime}'
                '${hasSubjectHistory ? " | ${item.subject.percentage.toStringAsFixed(0)}% Overall" : ""}',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (item.attendanceStatus == PeriodAttendanceStatus.present
                    ? colors.present
                    : (item.attendanceStatus == PeriodAttendanceStatus.absent
                        ? colors.absent
                        : (item.attendanceStatus == PeriodAttendanceStatus.od
                            ? colors.od
                            : colors.textMuted))).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: item.attendanceStatus == PeriodAttendanceStatus.present
                      ? colors.present
                      : (item.attendanceStatus == PeriodAttendanceStatus.absent
                          ? colors.absent
                          : (item.attendanceStatus == PeriodAttendanceStatus.od
                              ? colors.od
                              : colors.textMuted)),
                  width: 1,
                ),
              ),
              child: Text(
                item.statusLabel ?? item.simpleStartTime,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: item.attendanceStatus == PeriodAttendanceStatus.present
                      ? colors.present
                      : (item.attendanceStatus == PeriodAttendanceStatus.absent
                          ? colors.absent
                          : (item.attendanceStatus == PeriodAttendanceStatus.od
                              ? colors.od
                              : colors.textSecondary)),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Custom Painter drawing the Nightingale Rose / Petal Chart with Period Progression
class _NightingalePetalPainter extends CustomPainter {
  final List<SubjectClassItem> items;
  final int? selectedIndex;
  final double bloomProgress;
  final double overallAvg;
  final double currentDayMinutes;

  _NightingalePetalPainter({
    required this.items,
    required this.selectedIndex,
    required this.bloomProgress,
    required this.overallAvg,
    required this.currentDayMinutes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final count = items.length;

    const double rInner = 44.0;
    final double rOuterMax = (size.width / 2) - 14.0;
    final double cornerRadius = count >= 7 ? 6.5 : 8.5;

    final double sliceAngle = (2 * math.pi) / count;
    final double gapAngle = (count >= 7 ? 0.042 : 0.055).clamp(0.02, sliceAngle * 0.12);
    final double effectiveSweep = sliceAngle - gapAngle;

    // Outer ambient ring glow
    final bgGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawCircle(center, rOuterMax, bgGlowPaint);

    for (int i = 0; i < count; i++) {
      final item = items[i];
      final isSelected = selectedIndex == i;

      final aStart = -math.pi / 2 + i * sliceAngle + gapAngle / 2;
      final aEnd = aStart + effectiveSweep;
      final aMid = (aStart + aEnd) / 2;

      final selectExpansion = isSelected ? 5.0 : 0.0;
      final curOuterMax = rOuterMax + selectExpansion;

      // Radial length determined by remaining fraction of this class period!
      // When class starts: remainingFraction == 1.0 (full petal).
      // During class: remainingFraction decreases towards 0.0.
      // When class finishes: remainingFraction == 0.0 (fully drained down to hub, completely dark).
      final double rOuterActive = rInner + (curOuterMax - rInner) * item.remainingFraction * bloomProgress;

      final radialDir = Offset(math.cos(aMid), math.sin(aMid));
      final pStart = center + radialDir * rInner;
      final pEnd = center + radialDir * rOuterActive;

      // -------------------------------------------------------------
      // Step A: Draw Backing Base Petal (Semantic Jewel Tone)
      // When class is completed, this distinct jewel-toned petal is what's fully visible!
      // -------------------------------------------------------------
      final backPath = _buildRoundedPetalPath(
        center: center,
        rInner: rInner,
        rOuter: curOuterMax,
        aStart: aStart,
        aEnd: aEnd,
        cornerRadius: cornerRadius,
      );

      Color baseColorTop;
      Color baseColorBottom;
      Color borderColor;
      Color glowColor;

      switch (item.attendanceStatus) {
        case PeriodAttendanceStatus.present:
          baseColorTop = const Color(0xFF166534); // Rich vibrant emerald
          baseColorBottom = const Color(0xFF0D3820); // Deep midnight forest jade
          borderColor = const Color(0xFF34D399).withValues(alpha: 0.65);
          glowColor = const Color(0xFF10B981);
          break;
        case PeriodAttendanceStatus.absent:
          baseColorTop = const Color(0xFF7F1D1D); // Rich ruby wine
          baseColorBottom = const Color(0xFF450A0A); // Deep dark burgundy
          borderColor = const Color(0xFFF87171).withValues(alpha: 0.65);
          glowColor = const Color(0xFFF43F5E);
          break;
        case PeriodAttendanceStatus.od:
          baseColorTop = const Color(0xFF1E40AF); // Royal sapphire blue
          baseColorBottom = const Color(0xFF172554); // Deep midnight navy
          borderColor = const Color(0xFF60A5FA).withValues(alpha: 0.65);
          glowColor = const Color(0xFF3B82F6);
          break;
        case PeriodAttendanceStatus.inProgress:
          baseColorTop = const Color(0xFF14532D);
          baseColorBottom = const Color(0xFF052E16);
          borderColor = const Color(0xFF10B981).withValues(alpha: 0.75);
          glowColor = const Color(0xFF10B981);
          break;
        case PeriodAttendanceStatus.unrecorded:
          baseColorTop = const Color(0xFF334155); // Slate graphite
          baseColorBottom = const Color(0xFF1E293B); // Deep charcoal
          borderColor = Colors.white.withValues(alpha: 0.28);
          glowColor = const Color(0xFF64748B);
          break;
        case PeriodAttendanceStatus.upcoming:
          baseColorTop = const Color(0xFF33303D);
          baseColorBottom = const Color(0xFF1D1B26);
          borderColor = Colors.white.withValues(alpha: 0.20);
          glowColor = item.petalColor;
          break;
      }

      final backGradient = ui.Gradient.linear(
        pStart,
        center + radialDir * curOuterMax,
        [
          baseColorTop.withValues(alpha: 0.95),
          baseColorBottom.withValues(alpha: 0.98),
        ],
      );
      final backPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = backGradient;

      if (isSelected) {
        canvas.drawShadow(backPath, glowColor.withValues(alpha: 0.85), 14, true);
      } else if (item.attendanceStatus == PeriodAttendanceStatus.present ||
          item.attendanceStatus == PeriodAttendanceStatus.absent ||
          item.attendanceStatus == PeriodAttendanceStatus.od) {
        canvas.drawShadow(backPath, glowColor.withValues(alpha: 0.35), 6, true);
      }

      canvas.drawPath(backPath, backPaint);

      // Subtle specular rim sheen on outer arc for finished jewel effect
      final backGlareGradient = ui.Gradient.linear(
        center + radialDir * curOuterMax,
        center + radialDir * (rInner + (curOuterMax - rInner) * 0.60),
        [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.0),
        ],
      );
      final backGlarePaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = backGlareGradient;
      canvas.drawPath(backPath, backGlarePaint);

      final backStroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 1.8 : 1.0
        ..color = isSelected ? Colors.white : borderColor;
      canvas.drawPath(backPath, backStroke);

      // -------------------------------------------------------------
      // Step B: Draw Active Foreground Petal (Liquid Crystal Petal)
      // Only drawn while period is upcoming or in progress (remaining > 0)!
      // -------------------------------------------------------------
      if (item.remainingFraction > 0.015 &&
          (item.attendanceStatus == PeriodAttendanceStatus.upcoming ||
           item.attendanceStatus == PeriodAttendanceStatus.inProgress)) {
        final activePath = _buildRoundedPetalPath(
          center: center,
          rInner: rInner,
          rOuter: rOuterActive,
          aStart: aStart,
          aEnd: aEnd,
          cornerRadius: cornerRadius,
        );

        Color activePetalColor = item.petalColor;
        if (item.liveState == PeriodLiveState.inProgress) {
          activePetalColor = const Color(0xFF10B981);
        }

        final activeGradient = ui.Gradient.linear(
          pStart,
          pEnd,
          [
            activePetalColor.withValues(alpha: 0.98),
            activePetalColor.withValues(alpha: 0.88),
          ],
        );

        final activePaint = Paint()
          ..style = PaintingStyle.fill
          ..shader = activeGradient;

        if (isSelected) {
          canvas.drawShadow(activePath, activePetalColor.withValues(alpha: 0.80), 12, true);
        } else if (item.liveState == PeriodLiveState.inProgress) {
          canvas.drawShadow(activePath, const Color(0xFF10B981).withValues(alpha: 0.45), 8, true);
        } else {
          canvas.drawShadow(activePath, activePetalColor.withValues(alpha: 0.35), 6, true);
        }

        canvas.drawPath(activePath, activePaint);

        // Liquid Convex Specular Glare (Light Reflection on Outer Arc)
        final glareGradient = ui.Gradient.linear(
          pEnd,
          center + radialDir * (rInner + (rOuterActive - rInner) * 0.45),
          [
            Colors.white.withValues(alpha: 0.60),
            Colors.white.withValues(alpha: 0.0),
          ],
        );
        final glarePaint = Paint()
          ..style = PaintingStyle.fill
          ..shader = glareGradient;
        canvas.drawPath(activePath, glarePaint);

        // Active petal specular border
        final activeStroke = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 1.8 : (item.liveState == PeriodLiveState.inProgress ? 1.4 : 1.0)
          ..color = isSelected
              ? Colors.white.withValues(alpha: 0.98)
              : (item.liveState == PeriodLiveState.inProgress
                  ? const Color(0xFF10B981).withValues(alpha: 0.90)
                  : Colors.white.withValues(alpha: 0.45));
        canvas.drawPath(activePath, activeStroke);

        // Receding edge pulse wave if currently in progress
        if (item.liveState == PeriodLiveState.inProgress) {
          final pulsePaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..color = const Color(0xFF10B981).withValues(alpha: 0.8);
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: rOuterActive),
            aStart,
            effectiveSweep,
            false,
            pulsePaint,
          );
        }
      }

      // -------------------------------------------------------------
      // Step C: Draw Percentage & Subject Text on Petal
      // -------------------------------------------------------------
      final double rText = rInner + (curOuterMax - rInner) * 0.54;
      final textCenter = center + radialDir * rText;

      final bool isLightSurface = (item.attendanceStatus == PeriodAttendanceStatus.upcoming)
          ? item.petalColor.computeLuminance() > 0.45
          : false;

      final Color mainTextColor = isLightSurface ? const Color(0xFF0F172A) : Colors.white;
      final Color subjectTextColor = isLightSurface ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

      Color statusAccentColor;
      String statusText;

      switch (item.attendanceStatus) {
        case PeriodAttendanceStatus.present:
          statusText = 'Present ✓';
          statusAccentColor = isLightSurface ? const Color(0xFF059669) : const Color(0xFF4ADE80);
          break;
        case PeriodAttendanceStatus.absent:
          statusText = 'Absent ✗';
          statusAccentColor = isLightSurface ? const Color(0xFFDC2626) : const Color(0xFFFCA5A5);
          break;
        case PeriodAttendanceStatus.od:
          statusText = 'On-Duty';
          statusAccentColor = isLightSurface ? const Color(0xFF2563EB) : const Color(0xFF93C5FD);
          break;
        case PeriodAttendanceStatus.inProgress:
          statusText = '${(item.remainingFraction * 100).toInt()}% left';
          statusAccentColor = isLightSurface ? const Color(0xFF059669) : const Color(0xFF34D399);
          break;
        case PeriodAttendanceStatus.unrecorded:
          statusText = 'Pending';
          statusAccentColor = isLightSurface ? const Color(0xFFD97706) : const Color(0xFFFCD34D);
          break;
        case PeriodAttendanceStatus.upcoming:
          statusText = item.simpleStartTime;
          statusAccentColor = isLightSurface ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
          break;
      }

      _drawPetalText(
        canvas: canvas,
        position: textCenter,
        periodNumber: item.index + 1,
        statusText: statusText,
        subjectName: item.shortName,
        mainColor: mainTextColor,
        accentColor: statusAccentColor,
        subjectColor: subjectTextColor,
        isLightSurface: isLightSurface,
        count: count,
      );
    }

    // -------------------------------------------------------------
    // Step D: Center Aperture Hub (Espresso Liquid Crystal Lens)
    // -------------------------------------------------------------
    final hubShadowPaint = Paint()
      ..color = const Color(0xFF2B1A13).withValues(alpha: 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, rInner - 2, hubShadowPaint);

    final hubBgPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.radial(
        center,
        rInner - 2,
        [
          const Color(0xFF2B1A13),
          const Color(0xFF160E0A),
        ],
      );
    canvas.drawCircle(center, rInner - 2, hubBgPaint);

    final lensGlarePath = Path()
      ..addArc(Rect.fromCircle(center: center, radius: rInner - 3), -math.pi, math.pi);
    final lensGlarePaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        Offset(center.dx, center.dy - rInner),
        center,
        [
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.0),
        ],
      );
    canvas.drawPath(lensGlarePath, lensGlarePaint);

    final hubStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFFE6DCD0).withValues(alpha: 0.50);
    canvas.drawCircle(center, rInner - 2, hubStroke);

    // Hub Content: Period completion status or selected subject
    String hubTopText;
    String hubBottomText;
    Color hubTopColor = const Color(0xFFFFF8F0);

    final recordedItems = items.where((e) =>
        e.attendanceStatus == PeriodAttendanceStatus.present ||
        e.attendanceStatus == PeriodAttendanceStatus.absent ||
        e.attendanceStatus == PeriodAttendanceStatus.od
    ).toList();
    final recordedCount = recordedItems.length;
    final attendedCount = items.where((e) =>
        e.attendanceStatus == PeriodAttendanceStatus.present ||
        e.attendanceStatus == PeriodAttendanceStatus.od
    ).length;
    final inProgressItem = items.where((e) => e.attendanceStatus == PeriodAttendanceStatus.inProgress).firstOrNull;

    if (selectedIndex != null && selectedIndex! < items.length) {
      final sel = items[selectedIndex!];
      switch (sel.attendanceStatus) {
        case PeriodAttendanceStatus.present:
          hubTopText = 'Present ✓';
          hubTopColor = const Color(0xFF34D399);
          break;
        case PeriodAttendanceStatus.absent:
          hubTopText = 'Absent ✗';
          hubTopColor = const Color(0xFFFB7185);
          break;
        case PeriodAttendanceStatus.od:
          hubTopText = 'On-Duty';
          hubTopColor = const Color(0xFF60A5FA);
          break;
        case PeriodAttendanceStatus.inProgress:
          hubTopText = '${(sel.remainingFraction * 100).toInt()}% Left';
          hubTopColor = const Color(0xFF34D399);
          break;
        case PeriodAttendanceStatus.unrecorded:
          hubTopText = 'Pending';
          hubTopColor = const Color(0xFFFCD34D);
          break;
        case PeriodAttendanceStatus.upcoming:
          hubTopText = sel.simpleStartTime;
          hubTopColor = Colors.white;
          break;
      }
      hubBottomText = sel.shortName;
    } else if (recordedCount > 0) {
      hubTopText = '$attendedCount/$recordedCount';
      hubBottomText = 'Present';
      hubTopColor = const Color(0xFF34D399);
    } else if (inProgressItem != null) {
      hubTopText = inProgressItem.periodLabel;
      hubBottomText = '${(inProgressItem.remainingFraction * 100).toInt()}% Left';
      hubTopColor = const Color(0xFF34D399);
    } else if (items.any((e) => e.attendanceStatus == PeriodAttendanceStatus.unrecorded)) {
      hubTopText = 'Pending';
      hubBottomText = '0/$count Recorded';
      hubTopColor = const Color(0xFFFCD34D);
    } else {
      hubTopText = 'Today';
      hubBottomText = '$count Periods';
      hubTopColor = Colors.white;
    }

    _drawHubText(
      canvas: canvas,
      center: center,
      topText: hubTopText,
      bottomText: hubBottomText,
      topColor: hubTopColor,
    );
  }

  Path _buildRoundedPetalPath({
    required Offset center,
    required double rInner,
    required double rOuter,
    required double aStart,
    required double aEnd,
    required double cornerRadius,
  }) {
    final path = Path();
    if (rOuter <= rInner + 0.5) return path;

    final sweep = aEnd - aStart;
    final maxR = math.max(0.1, (rOuter - rInner) * 0.35);
    final minR = math.min(1.0, maxR);
    final r = cornerRadius.clamp(minR, maxR);

    final dThetaOut = (r / rOuter).clamp(0.01, sweep * 0.35);
    final dThetaIn = (r / rInner).clamp(0.01, sweep * 0.35);

    final pStartRadial = center + Offset(math.cos(aStart), math.sin(aStart)) * (rInner + r);
    final pEndRadial = center + Offset(math.cos(aStart), math.sin(aStart)) * (rOuter - r);

    path.moveTo(pStartRadial.dx, pStartRadial.dy);
    path.lineTo(pEndRadial.dx, pEndRadial.dy);

    final vOuterStart = center + Offset(math.cos(aStart), math.sin(aStart)) * rOuter;
    final pArcOutStart = center + Offset(math.cos(aStart + dThetaOut), math.sin(aStart + dThetaOut)) * rOuter;
    path.quadraticBezierTo(vOuterStart.dx, vOuterStart.dy, pArcOutStart.dx, pArcOutStart.dy);

    final arcOutSweep = sweep - 2 * dThetaOut;
    if (arcOutSweep > 0) {
      path.arcTo(
        Rect.fromCircle(center: center, radius: rOuter),
        aStart + dThetaOut,
        arcOutSweep,
        false,
      );
    }

    final vOuterEnd = center + Offset(math.cos(aEnd), math.sin(aEnd)) * rOuter;
    final pLineOutEnd = center + Offset(math.cos(aEnd), math.sin(aEnd)) * (rOuter - r);
    path.quadraticBezierTo(vOuterEnd.dx, vOuterEnd.dy, pLineOutEnd.dx, pLineOutEnd.dy);

    final pLineInEnd = center + Offset(math.cos(aEnd), math.sin(aEnd)) * (rInner + r);
    path.lineTo(pLineInEnd.dx, pLineInEnd.dy);

    final vInnerEnd = center + Offset(math.cos(aEnd), math.sin(aEnd)) * rInner;
    final pArcInEnd = center + Offset(math.cos(aEnd - dThetaIn), math.sin(aEnd - dThetaIn)) * rInner;
    path.quadraticBezierTo(vInnerEnd.dx, vInnerEnd.dy, pArcInEnd.dx, pArcInEnd.dy);

    final arcInSweep = sweep - 2 * dThetaIn;
    if (arcInSweep > 0) {
      path.arcTo(
        Rect.fromCircle(center: center, radius: rInner),
        aEnd - dThetaIn,
        -arcInSweep,
        false,
      );
    }

    final vInnerStart = center + Offset(math.cos(aStart), math.sin(aStart)) * rInner;
    path.quadraticBezierTo(vInnerStart.dx, vInnerStart.dy, pStartRadial.dx, pStartRadial.dy);

    path.close();
    return path;
  }

  void _drawPetalText({
    required Canvas canvas,
    required Offset position,
    required int periodNumber,
    required String statusText,
    required String subjectName,
    required Color mainColor,
    required Color accentColor,
    required Color subjectColor,
    required bool isLightSurface,
    required int count,
  }) {
    final double numFontSize = count >= 7 ? 10.5 : 12.0;
    final double subjectFontSize = count >= 7 ? 9.5 : 10.5;

    final shadow = Shadow(
      color: (isLightSurface ? Colors.white : Colors.black).withValues(alpha: 0.65),
      blurRadius: 3.5,
      offset: const Offset(0, 1),
    );

    // Line 1: Period number + Status badge
    final tpLine1 = TextPainter(
      text: TextSpan(
        style: TextStyle(
          fontSize: numFontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          shadows: [shadow],
        ),
        children: [
          TextSpan(
            text: 'P$periodNumber • ',
            style: TextStyle(color: mainColor),
          ),
          TextSpan(
            text: statusText,
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Line 2: Subject name (Single clean occurrence, high contrast)
    final tpLine2 = TextPainter(
      text: TextSpan(
        text: subjectName,
        style: TextStyle(
          color: subjectColor,
          fontSize: subjectFontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          shadows: [shadow],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final totalHeight = tpLine1.height + tpLine2.height + 2.5;
    final startY = position.dy - totalHeight / 2;

    tpLine1.paint(
      canvas,
      Offset(position.dx - tpLine1.width / 2, startY),
    );
    tpLine2.paint(
      canvas,
      Offset(position.dx - tpLine2.width / 2, startY + tpLine1.height + 2.5),
    );
  }

  void _drawHubText({
    required Canvas canvas,
    required Offset center,
    required String topText,
    required String bottomText,
    required Color topColor,
  }) {
    final tpTop = TextPainter(
      text: TextSpan(
        text: topText,
        style: TextStyle(
          color: topColor,
          fontSize: 13.0,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final tpBottom = TextPainter(
      text: TextSpan(
        text: bottomText,
        style: TextStyle(
          color: const Color(0xFFF1F5F9),
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final totalHeight = tpTop.height + tpBottom.height + 1.5;
    final startY = center.dy - totalHeight / 2;

    tpTop.paint(canvas, Offset(center.dx - tpTop.width / 2, startY));
    tpBottom.paint(canvas, Offset(center.dx - tpBottom.width / 2, startY + tpTop.height + 1.5));
  }

  @override
  bool shouldRepaint(covariant _NightingalePetalPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.bloomProgress != bloomProgress ||
        oldDelegate.overallAvg != overallAvg ||
        oldDelegate.currentDayMinutes != currentDayMinutes ||
        oldDelegate.items != items;
  }
}
