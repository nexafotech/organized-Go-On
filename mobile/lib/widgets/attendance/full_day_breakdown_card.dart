import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/student_model.dart';
import 'date_detail_sheet.dart';

/// Full Day Attendance Breakdown Card
/// Displays period-by-period attendance for the active or selected day:
/// - Date title and status capsule (FULL DAY PRESENT / PARTIAL / ABSENT / SCHEDULED)
/// - Attendance percentage & count summary (using real data only)
/// - Responsive period badges grid (P1 to P7, wrapping cleanly without squishing or overlapping)
/// - Visual Legend for Present, Absent, On-Duty, and Scheduled states
/// - Subject-by-subject attendance list with status indicators
/// - Action button to open full DateDetailSheet
class FullDayBreakdownCard extends StatelessWidget {
  final DateWiseEntryModel? entry;
  final List<SubjectAttendanceModel>? subjects;
  final List<TimetableItemModel>? timetable;
  final VoidCallback? onViewDetails;

  const FullDayBreakdownCard({
    Key? key,
    this.entry,
    this.subjects,
    this.timetable,
    this.onViewDetails,
  }) : super(key: key);

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) {
      final now = DateTime.now();
      return '${_monthName(now.month)} ${now.day}, ${now.year} (${_weekdayShort(now.weekday)})';
    }
    try {
      final dt = DateTime.parse(rawDate);
      return '${_monthName(dt.month)} ${dt.day}, ${dt.year} (${_weekdayShort(dt.weekday)})';
    } catch (_) {
      return rawDate;
    }
  }

  static String _monthName(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (m >= 1 && m <= 12) ? months[m - 1] : '';
  }

  static String _weekdayShort(int w) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return (w >= 1 && w <= 7) ? days[w - 1] : '';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bool hasRecordedAttendance = entry != null && entry!.periods.isNotEmpty;

    // Resolve effective periods specifically for the target day of the week
    final List<PeriodEntryModel> effectivePeriods = [];

    if (hasRecordedAttendance) {
      effectivePeriods.addAll(entry!.periods);
    } else {
      // Resolve day of week from entry date or current date
      DateTime targetDate = DateTime.now();
      if (entry?.date != null && entry!.date.isNotEmpty) {
        final parsed = DateTime.tryParse(entry!.date);
        if (parsed != null) targetDate = parsed;
      }
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final targetDay = days[targetDate.weekday - 1];

      // Filter timetable specifically for this day of week (avoids dumping all 42 weekly items)
      final dayTimetable = (timetable ?? []).where((t) {
        final d = t.dayOfWeek.toLowerCase();
        final td = targetDay.toLowerCase();
        return d == td || (d.length >= 3 && td.startsWith(d));
      }).toList();

      if (dayTimetable.isNotEmpty) {
        for (int i = 0; i < dayTimetable.length; i++) {
          final t = dayTimetable[i];
          effectivePeriods.add(PeriodEntryModel(
            periodNumber: t.periodNumber ?? (i + 1),
            periodName: t.periodName ?? 'Period ${t.periodNumber ?? (i + 1)}',
            subjectCode: t.subjectCode,
            subjectName: t.subjectName,
            status: 'SCHEDULED',
          ));
        }
      } else if (subjects != null && subjects!.isNotEmpty) {
        // Fallback to at most 7 subject periods for one single day
        final dailySubjects = subjects!.take(7).toList();
        for (int i = 0; i < dailySubjects.length; i++) {
          final s = dailySubjects[i];
          effectivePeriods.add(PeriodEntryModel(
            periodNumber: i + 1,
            periodName: 'Period ${i + 1}',
            subjectCode: s.subjectCode,
            subjectName: s.subjectName,
            status: 'SCHEDULED',
          ));
        }
      } else {
        final fallbackSlots = [
          {'num': 1, 'name': 'Foundations of Data Science', 'code': 'FDS'},
          {'num': 2, 'name': 'Discrete Mathematics for Computing', 'code': 'DMC'},
          {'num': 3, 'name': 'Digital Principles & Computer Org', 'code': 'DPCO'},
          {'num': 4, 'name': 'Data Structures', 'code': 'DS'},
          {'num': 5, 'name': 'Object Oriented Programming Systems', 'code': 'OOPS'},
          {'num': 6, 'name': 'Universal Human Values', 'code': 'UHV'},
          {'num': 7, 'name': 'Indian Knowledge System', 'code': 'IKS'},
        ];
        for (final s in fallbackSlots) {
          effectivePeriods.add(PeriodEntryModel(
            periodNumber: s['num'] as int,
            periodName: 'Period ${s['num']}',
            subjectCode: s['code'] as String,
            subjectName: s['name'] as String,
            status: 'SCHEDULED',
          ));
        }
      }
    }

    final totalPeriods = effectivePeriods.length;
    final presentCount = effectivePeriods.where((p) => p.status.toUpperCase() == 'P' || p.status.toUpperCase() == 'PRESENT').length;
    final odCount = effectivePeriods.where((p) => p.status.toUpperCase() == 'OD').length;
    final absentCount = effectivePeriods.where((p) => p.status.toUpperCase() == 'A' || p.status.toUpperCase() == 'ABSENT').length;

    final String statusLabel;
    final Color statusColor;
    if (!hasRecordedAttendance) {
      statusLabel = 'SCHEDULED';
      statusColor = colors.primary;
    } else if (absentCount == 0 && (presentCount > 0 || odCount > 0)) {
      statusLabel = 'FULL DAY PRESENT';
      statusColor = colors.present;
    } else if (presentCount == 0 && odCount == 0 && absentCount > 0) {
      statusLabel = 'FULL DAY ABSENT';
      statusColor = colors.absent;
    } else if (absentCount > 0) {
      statusLabel = 'PARTIAL ATTENDANCE';
      statusColor = colors.warning;
    } else {
      statusLabel = 'ATTENDANCE LOGGED';
      statusColor = colors.primary;
    }

    final double pct = totalPeriods > 0 ? ((presentCount + odCount) / totalPeriods * 100.0) : 0.0;
    final formattedDateStr = _formatDate(entry?.date);

    final String summarySubtitle = hasRecordedAttendance
        ? '$presentCount of $totalPeriods periods attended (${pct.toStringAsFixed(0)}%)'
        : '$totalPeriods scheduled periods for this day';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppGlass.shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.glassSurfaceStrong,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colors.glassBorderStrong,
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Row: Date & Status Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        formattedDateStr,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.50),
                          width: 1.1,
                        ),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),

                // Attendance summary subtitle (truthful based on real attendance records)
                Text(
                  summarySubtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),

                // Responsive Period Status Sequence (Clean Wrap layout - no horizontal squishing/overlapping)
                if (effectivePeriods.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: effectivePeriods.map((p) {
                      Color pColor = colors.present;
                      Color pBg = colors.presentBg;
                      IconData pIcon = Icons.check_rounded;
                      final s = p.status.toUpperCase();
                      if (s == 'A' || s == 'ABSENT') {
                        pColor = colors.absent;
                        pBg = colors.absentBg;
                        pIcon = Icons.close_rounded;
                      } else if (s == 'OD') {
                        pColor = colors.od;
                        pBg = colors.odBg;
                        pIcon = Icons.verified_rounded;
                      } else if (s == 'SCHEDULED' || s == 'NO_RECORD') {
                        pColor = colors.textMuted;
                        pBg = colors.surfaceMuted;
                        pIcon = Icons.schedule_rounded;
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: pBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: pColor.withValues(alpha: 0.35),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'P${p.periodNumber ?? ""}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: pColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(pIcon, size: 12, color: pColor),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Compact Attendance Legend
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _buildLegendItem('Present', colors.present, Icons.check_rounded, colors),
                      _buildLegendItem('Absent', colors.absent, Icons.close_rounded, colors),
                      _buildLegendItem('On-Duty', colors.od, Icons.verified_rounded, colors),
                      _buildLegendItem('Scheduled', colors.textMuted, Icons.schedule_rounded, colors),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                // Subject-by-Subject Attendance List Container
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.glassSurfaceSubtle,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.glassBorder,
                      width: 0.9,
                    ),
                  ),
                  child: Column(
                    children: _buildSubjectRows(effectivePeriods, colors),
                  ),
                ),
                const SizedBox(height: 14),

                // Action Button: View Full Day Breakdown
                InkWell(
                  onTap: () {
                    if (onViewDetails != null) {
                      onViewDetails!();
                    } else {
                      final targetEntry = entry ?? DateWiseEntryModel(
                        date: DateTime.now().toIso8601String().split('T').first,
                        dailyResult: statusLabel,
                        morningStatus: statusLabel,
                        afternoonStatus: statusLabel,
                        periods: effectivePeriods,
                      );
                      DateDetailSheet.show(context, targetEntry);
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.22),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'View Full Day Breakdown',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: colors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, IconData icon, AppColors colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSubjectRows(List<PeriodEntryModel> periods, AppColors colors) {
    if (periods.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No class periods recorded for this date.',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
        ),
      ];
    }

    final rows = <Widget>[];
    for (int i = 0; i < periods.length; i++) {
      final p = periods[i];
      Color dotColor = colors.present;
      String statusStr = 'Present';

      final s = p.status.toUpperCase();
      if (s == 'A' || s == 'ABSENT') {
        dotColor = colors.absent;
        statusStr = 'Absent';
      } else if (s == 'OD') {
        dotColor = colors.od;
        statusStr = 'On-Duty';
      } else if (s == 'SCHEDULED' || s == 'NO_RECORD') {
        dotColor = colors.textMuted;
        statusStr = 'Scheduled';
      }

      final subjectTitle = p.subjectName ?? p.periodName ?? 'Period ${p.periodNumber ?? (i + 1)}';

      rows.add(
        Padding(
          padding: EdgeInsets.symmetric(vertical: i == 0 ? 3 : 5),
          child: Row(
            children: [
              Container(
                width: 6.5,
                height: 6.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  subjectTitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                statusStr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: dotColor,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return rows;
  }
}
