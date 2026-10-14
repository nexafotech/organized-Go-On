import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/student_model.dart';

/// Period item data structure for DailyScheduleCard
class DailySchedulePeriodItem {
  final int number;
  final String time;
  final String code;
  final String name;
  final String status; // 'PRESENT', 'ABSENT', 'OD', 'NO_RECORD'

  const DailySchedulePeriodItem({
    required this.number,
    required this.time,
    required this.code,
    required this.name,
    required this.status,
  });

  String get statusLabel {
    switch (status.toUpperCase()) {
      case 'PRESENT':
      case 'P':
        return 'Present';
      case 'ABSENT':
      case 'A':
        return 'Absent';
      case 'OD':
        return 'On Duty';
      case 'NO_RECORD':
      default:
        return 'No record';
    }
  }

  Color getStatusColor(AppColors colors) {
    switch (status.toUpperCase()) {
      case 'PRESENT':
      case 'P':
        return colors.present;
      case 'ABSENT':
      case 'A':
        return const Color(0xFF991B1B);
      case 'OD':
        return colors.od;
      case 'NO_RECORD':
      default:
        return colors.textMuted;
    }
  }

  Color getCardBackgroundColor(AppColors colors) {
    switch (status.toUpperCase()) {
      case 'ABSENT':
      case 'A':
        return const Color(0xFF991B1B);
      case 'PRESENT':
      case 'P':
        return const Color(0xFF047857);
      case 'OD':
        return const Color(0xFF1E40AF);
      case 'NO_RECORD':
      default:
        return colors.isDark ? const Color(0xFF262E3B) : const Color(0xFF334155);
    }
  }
}

/// DailyScheduleCard — Exact reproduction of the reference "YOUR DAY" card
/// Replaces the subject-wise list with an interactive daily class schedule breakdown.
class DailyScheduleCard extends StatefulWidget {
  final DateWiseEntryModel? entry;
  final List<TimetableItemModel>? timetable;
  final List<SubjectAttendanceModel>? subjects;
  final String? dateLabel;

  const DailyScheduleCard({
    Key? key,
    this.entry,
    this.timetable,
    this.subjects,
    this.dateLabel,
  }) : super(key: key);

  @override
  State<DailyScheduleCard> createState() => _DailyScheduleCardState();
}

class _DailyScheduleCardState extends State<DailyScheduleCard> {
  int _selectedPeriodIndex = 0;

  static const List<Map<String, String>> _defaultSlots = [
    {
      'num': '1',
      'time': '08:45 AM',
      'code': '19IT501',
      'name': 'Design and Analysis of Algorithms',
    },
    {
      'num': '2',
      'time': '09:40 AM',
      'code': '19IT502',
      'name': 'Computer Networks',
    },
    {
      'num': '3',
      'time': '10:55 AM',
      'code': '19IT503',
      'name': 'Database Management Systems',
    },
    {
      'num': '4',
      'time': '11:50 AM',
      'code': '19IT504',
      'name': 'Full Stack Web Development',
    },
    {
      'num': '5',
      'time': '01:45 PM',
      'code': '19IT505',
      'name': 'Artificial Intelligence & Machine Learning',
    },
    {
      'num': '6',
      'time': '02:40 PM',
      'code': '19IT506',
      'name': 'Cloud Computing & DevOps',
    },
    {
      'num': '7',
      'time': '03:30 PM',
      'code': '19IT507',
      'name': 'Mobile Application Development',
    },
  ];

  List<DailySchedulePeriodItem> _resolvePeriods() {
    final entry = widget.entry;
    final timetable = widget.timetable ?? [];
    final subjects = widget.subjects ?? [];

    // 1. If entry has periods, construct from entry with timetable times
    if (entry != null && entry.periods.isNotEmpty) {
      final List<DailySchedulePeriodItem> items = [];
      for (int i = 0; i < entry.periods.length; i++) {
        final p = entry.periods[i];
        final num = p.periodNumber ?? (i + 1);

        // Find timetable start time
        String time = '';
        for (final t in timetable) {
          if (t.periodNumber == num && t.startTime != null && t.startTime!.isNotEmpty) {
            time = t.startTime!;
            break;
          }
        }
        if (time.isEmpty) {
          final slotIdx = (num - 1).clamp(0, _defaultSlots.length - 1);
          time = _defaultSlots[slotIdx]['time']!;
        }

        String code = p.subjectCode ?? '';
        String name = p.subjectName ?? '';

        // If code or name missing, try resolving from timetable
        if (code.isEmpty || name.isEmpty) {
          for (final t in timetable) {
            if (t.periodNumber == num) {
              if (code.isEmpty && t.subjectCode != null && t.subjectCode!.isNotEmpty) {
                code = t.subjectCode!;
              }
              if (name.isEmpty && t.subjectName != null && t.subjectName!.isNotEmpty) {
                name = t.subjectName!;
              }
            }
          }
        }

        // Try resolving from subjects
        if (code.isEmpty || name.isEmpty) {
          for (final s in subjects) {
            if (code.isNotEmpty && s.subjectCode.toUpperCase() == code.toUpperCase()) {
              name = s.subjectName;
              break;
            }
          }
          if (name.isEmpty && subjects.isNotEmpty) {
            final sIdx = (num - 1).clamp(0, subjects.length - 1);
            if (code.isEmpty) code = subjects[sIdx].subjectCode;
            if (name.isEmpty) name = subjects[sIdx].subjectName;
          }
        }

        // Fallback to default reference slots
        final slotIdx = (num - 1).clamp(0, _defaultSlots.length - 1);
        if (code.isEmpty) {
          code = _defaultSlots[slotIdx]['code']!;
        }
        if (name.isEmpty) {
          final matchedSlot = _defaultSlots.firstWhere(
            (s) => s['code'] == code,
            orElse: () => _defaultSlots[slotIdx],
          );
          name = matchedSlot['name']!;
        }

        String statusStr = p.status.toUpperCase();
        if (statusStr == 'P' || statusStr == 'PRESENT') {
          statusStr = 'PRESENT';
        } else if (statusStr == 'A' || statusStr == 'ABSENT') {
          statusStr = 'ABSENT';
        } else if (statusStr == 'OD') {
          statusStr = 'OD';
        } else {
          statusStr = 'NO_RECORD';
        }

        items.add(DailySchedulePeriodItem(
          number: num,
          time: time,
          code: code,
          name: name,
          status: statusStr,
        ));
      }

      // If less than 7 periods, pad up to 7 so the full day 1-7 track is complete
      if (items.length < 7) {
        final existingNums = items.map((e) => e.number).toSet();
        for (int i = 1; i <= 7; i++) {
          if (!existingNums.contains(i)) {
            final slotIdx = i - 1;
            items.add(DailySchedulePeriodItem(
              number: i,
              time: _defaultSlots[slotIdx]['time']!,
              code: _defaultSlots[slotIdx]['code']!,
              name: _defaultSlots[slotIdx]['name']!,
              status: 'NO_RECORD',
            ));
          }
        }
        items.sort((a, b) => a.number.compareTo(b.number));
      }

      return items;
    }

    // 2. Fallback to default reference 7 periods (as shown in reference design image)
    return List.generate(7, (i) {
      final slot = _defaultSlots[i];
      return DailySchedulePeriodItem(
        number: int.parse(slot['num']!),
        time: slot['time']!,
        code: slot['code']!,
        name: slot['name']!,
        status: 'ABSENT', // Default to Absent as depicted in the reference screenshot
      );
    });
  }

  String _formatHeaderDate() {
    if (widget.dateLabel != null && widget.dateLabel!.isNotEmpty) {
      // Remove "Today • " prefix if present for clean date display
      return widget.dateLabel!.replaceFirst('Today • ', '');
    }
    final now = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final periods = _resolvePeriods();

    if (_selectedPeriodIndex >= periods.length) {
      _selectedPeriodIndex = 0;
    }
    final featuredPeriod = periods[_selectedPeriodIndex];

    // Counts
    final missedCount = periods.where((p) => p.status == 'ABSENT').length;
    final attendedCount = periods.where((p) => p.status == 'PRESENT' || p.status == 'OD').length;
    final recordedTotal = periods.where((p) => p.status != 'NO_RECORD').length;
    final double overallTodayPct = recordedTotal > 0
        ? ((attendedCount / recordedTotal) * 100.0).clamp(0.0, 100.0)
        : 0.0;

    final dateText = _formatHeaderDate();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.isDark ? colors.surfaceElevated : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: colors.isDark ? colors.glassBorderStrong : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.20 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Date Header
          Text(
            dateText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),

          // 2. Headline: "You missed 7 classes today."
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
                letterSpacing: -0.5,
              ),
              children: [
                if (missedCount > 0) ...[
                  const TextSpan(text: 'You missed '),
                  TextSpan(
                    text: '$missedCount class${missedCount > 1 ? 'es' : ''}',
                    style: const TextStyle(
                      color: Color(0xFF991B1B),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const TextSpan(text: ' today.'),
                ] else if (attendedCount > 0) ...[
                  const TextSpan(text: 'You attended '),
                  TextSpan(
                    text: '$attendedCount class${attendedCount > 1 ? 'es' : ''}',
                    style: TextStyle(
                      color: colors.present,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const TextSpan(text: ' today.'),
                ] else ...[
                  const TextSpan(text: 'No attendance recorded today.'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),

          // 3. Subtitle: "Schedule will update as classes proceed."
          Text(
            'Schedule will update as classes proceed.',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w400,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),

          // 4. "YOUR DAY" Section Header
          Text(
            'YOUR DAY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          // 5. Numbered Circles Track (1 to 7)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.isDark ? colors.surfaceMuted : const Color(0xFFF1E9E3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(periods.length.clamp(0, 7), (idx) {
                final p = periods[idx];
                final isSelected = idx == _selectedPeriodIndex;
                final isAbsent = p.status == 'ABSENT';
                final isPresent = p.status == 'PRESENT';
                final isOd = p.status == 'OD';

                Color circleBg;
                Color textColor = Colors.white;
                Border? border;

                if (isAbsent) {
                  circleBg = const Color(0xFF991B1B);
                } else if (isPresent) {
                  circleBg = colors.present;
                } else if (isOd) {
                  circleBg = colors.od;
                } else {
                  circleBg = Colors.transparent;
                  border = Border.all(
                    color: colors.textMuted.withValues(alpha: 0.4),
                    width: 1.5,
                  );
                  textColor = colors.textMuted;
                }

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedPeriodIndex = idx);
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: circleBg,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: colors.primary,
                              width: 2.5,
                            )
                          : border,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${p.number}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // 6. Time Indicators: 08:45 AM ---------- 12:00 ---------- 04:20 PM
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '08:45 AM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors.textMuted,
                  ),
                ),
                Text(
                  '12:00',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors.textMuted,
                  ),
                ),
                Text(
                  '04:20 PM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // 7. Legend: ● Absent   ○ No record
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFF991B1B),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'Absent',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.textMuted.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'No record',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 8. Featured Active Period Card (Large Rich-Red Card)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: featuredPeriod.getCardBackgroundColor(colors),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: featuredPeriod.getCardBackgroundColor(colors).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Period # • Time | Status Capsule
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Period ${featuredPeriod.number} • ${featuredPeriod.time}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        featuredPeriod.statusLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: featuredPeriod.getStatusColor(colors),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Large Subject Code
                Text(
                  featuredPeriod.code,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),

                // Subject Name
                Text(
                  featuredPeriod.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 9. Remaining Periods Grid (2 columns)
          Builder(
            builder: (context) {
              final remaining = periods.asMap().entries.where((e) => e.key != _selectedPeriodIndex).toList();

              return LayoutBuilder(
                builder: (context, constraints) {
                  final tileWidth = (constraints.maxWidth - 10) / 2;

                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: remaining.map((entry) {
                      final p = entry.value;
                      final originalIndex = entry.key;

                      return SizedBox(
                        width: tileWidth,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedPeriodIndex = originalIndex);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: colors.isDark ? colors.surfaceMuted : const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colors.isDark
                                    ? colors.glassBorderStrong
                                    : const Color(0xFFF1F5F9),
                                width: 1.1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: colors.isDark ? 0.12 : 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Period ${p.number} • ${p.time}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: colors.textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  p.code,
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: colors.textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  p.statusLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: p.getStatusColor(colors),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 18),

          // 10. Bottom "Overall today" Target Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Overall today',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textMuted,
                      ),
                      children: [
                        TextSpan(
                          text: '${overallTodayPct.toStringAsFixed(0)}% ',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: overallTodayPct >= 75.0 ? colors.present : const Color(0xFF991B1B),
                          ),
                        ),
                        const TextSpan(text: 'target 75%'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Progress Track with Vertical Tick Mark at 75%
              LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final fillFraction = (overallTodayPct / 100.0).clamp(0.0, 1.0);
                  final fillWidth = totalWidth * fillFraction;
                  final tickPosition = totalWidth * 0.75;

                  return SizedBox(
                    height: 14,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Background line track
                        Container(
                          height: 3.5,
                          width: totalWidth,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // Filled active progress line
                        if (fillWidth > 0)
                          Container(
                            height: 3.5,
                            width: fillWidth,
                            decoration: BoxDecoration(
                              color: overallTodayPct >= 75.0 ? colors.present : const Color(0xFF991B1B),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        // 75% Target Marker Tick
                        Positioned(
                          left: tickPosition - 1,
                          child: Container(
                            width: 2,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF475569),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
