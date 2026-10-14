import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/student_model.dart';
import '../../services/student_service.dart';
import '../../widgets/widgets.dart';

enum PeriodClassStatus {
  activeNow,
  upcoming,
  completed,
  freePeriod,
  none,
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

  late String _selectedDay;

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
      final parts = timeStr.trim().split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return hour * 60 + minute;
      }
    } catch (_) {}
    return -1;
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final studentService = Provider.of<StudentService>(context);
    final timetable = studentService.timetable;

    if (studentService.isLoading && timetable.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (studentService.errorMessage != null && timetable.isEmpty) {
      return Center(
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
      );
    }

    // Filter items for the selected day
    final dayItems = timetable.where((item) {
      return item.dayOfWeek.toUpperCase() == _selectedDay.toUpperCase();
    }).toList();

    // Sort by period number or start time
    dayItems.sort((a, b) {
      if (a.periodNumber != null && b.periodNumber != null) {
        return a.periodNumber!.compareTo(b.periodNumber!);
      }
      final aStart = _parseTimeToMinutes(a.startTime);
      final bStart = _parseTimeToMinutes(b.startTime);
      return aStart.compareTo(bStart);
    });

    final isTodaySelected = _isToday(_selectedDay);

    return RefreshIndicator(
      color: colors.primary,
      backgroundColor: colors.surface,
      onRefresh: () => studentService.fetchTimetable(),
      child: Column(
        children: [
          // Day Selection Bar
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
                      onTap: () {
                        setState(() => _selectedDay = dayCode);
                      },
                      borderRadius: AppRadius.smallBorder,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.primary
                              : (isCurrentDay
                                  ? colors.heroChip
                                  : colors.glassSurfaceSubtle),
                          borderRadius: AppRadius.smallBorder,
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
                                  color: isSelected ? colors.onPrimary : colors.primary,
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

          // Day Header
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      _selectedDay,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (isTodaySelected) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.presentBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: colors.present, width: 1),
                        ),
                        child: Text(
                          'TODAY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colors.present,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${dayItems.length} Period${dayItems.length == 1 ? "" : "s"}',
                  style: TextStyle(fontSize: 12, color: colors.textMuted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // Timetable List
          Expanded(
            child: dayItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy_outlined, size: 48, color: colors.textMuted),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _selectedDay.toUpperCase() == 'SUNDAY'
                                ? 'No Classes Scheduled'
                                : 'No Classes on $_selectedDay',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedDay.toUpperCase() == 'SUNDAY'
                                ? 'Weekend — Sunday has no scheduled classes.'
                                : 'No timetable schedule entries configured for this day.',
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
                      return _buildPeriodCard(item, status);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodCard(TimetableItemModel item, PeriodClassStatus status) {
    final colors = context.colors;
    Color cardBorderColor = colors.border;
    Color periodBadgeBg = colors.primary;
    Widget? statusBadge;

    switch (status) {
      case PeriodClassStatus.activeNow:
        cardBorderColor = colors.present;
        periodBadgeBg = colors.present;
        statusBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colors.present,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
              SizedBox(width: 2),
              Text(
                'CURRENT CLASS',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
        break;
      case PeriodClassStatus.upcoming:
        cardBorderColor = colors.warning;
        periodBadgeBg = colors.warning;
        statusBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colors.warningBg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: colors.warning),
          ),
          child: Text(
            'UPCOMING',
            style: TextStyle(color: colors.warning, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        );
        break;
      case PeriodClassStatus.completed:
        cardBorderColor = colors.border;
        periodBadgeBg = colors.surfaceMuted;
        statusBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            'COMPLETED',
            style: TextStyle(color: colors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        );
        break;
      case PeriodClassStatus.freePeriod:
        cardBorderColor = colors.border;
        periodBadgeBg = colors.surfaceMuted;
        statusBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            'FREE PERIOD',
            style: TextStyle(color: colors.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        );
        break;
      case PeriodClassStatus.none:
        break;
    }

    final isFree = status == PeriodClassStatus.freePeriod;
    final subjectTitle = isFree ? 'Free Period / Recess' : (item.subjectName ?? 'Subject Not Set');
    final timeDisplay = (item.startTime != null && item.endTime != null)
        ? '${item.startTime} - ${item.endTime}'
        : 'Timing not specified';

    return GlassCard(
      variant: status == PeriodClassStatus.activeNow ? GlassCardVariant.elevated : GlassCardVariant.standard,
      enableBlur: false,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      borderColor: cardBorderColor,
      borderWidth: status == PeriodClassStatus.activeNow ? 1.8 : 1.0,
      padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period Number Badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: periodBadgeBg,
                borderRadius: AppRadius.mediumBorder,
              ),
              child: Center(
                child: Text(
                  item.periodNumber != null ? 'P${item.periodNumber}' : '•',
                  style: TextStyle(
                    color: periodBadgeBg == colors.surfaceMuted ? colors.textPrimary : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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
                          subjectTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isFree ? colors.textMuted : colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (statusBadge != null) statusBadge,
                    ],
                  ),
                  const SizedBox(height: 4),

                  if (item.subjectCode != null && item.subjectCode!.isNotEmpty) ...[
                    Text(
                      'Code: ${item.subjectCode}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],

                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 14, color: colors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        timeDisplay,
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                      ),
                    ],
                  ),

                  if (!isFree) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 14, color: colors.textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            (item.facultyName != null && item.facultyName!.isNotEmpty)
                                ? 'Faculty: ${item.facultyName}'
                                : 'Faculty: Faculty assignment pending',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: (item.facultyName == null || item.facultyName!.isEmpty || item.facultyName!.toLowerCase().contains('pending'))
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              color: (item.facultyName == null || item.facultyName!.isEmpty || item.facultyName!.toLowerCase().contains('pending'))
                                  ? colors.warning
                                  : colors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
    );
  }
}
