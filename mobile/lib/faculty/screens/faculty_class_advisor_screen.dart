import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_tokens.dart';
import '../../widgets/widgets.dart';
import '../../models/faculty_attendance_model.dart';
import '../../services/faculty_service.dart';
import '../../utils/timezone_utils.dart';
import 'faculty_class_advisor_entry_screen.dart';
import '../widgets/faculty_calendar_theme.dart';

class FacultyClassAdvisorScreen extends StatefulWidget {
  final bool isStandalone;
  const FacultyClassAdvisorScreen({Key? key, this.isStandalone = false}) : super(key: key);

  @override
  State<FacultyClassAdvisorScreen> createState() => _FacultyClassAdvisorScreenState();
}

class _FacultyClassAdvisorScreenState extends State<FacultyClassAdvisorScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  ClassAdvisorAvailablePeriodsResponse? _data;

  DateTime _selectedPastDate = DateTime.now().subtract(const Duration(days: 1));
  bool _isLoadingPast = false;
  String? _pastErrorMessage;
  ClassAdvisorPeriodsForDateResponse? _pastData;

  late TabController _tabController;
  final ScrollController _todayScrollController = ScrollController();
  final ScrollController _yesterdayScrollController = ScrollController();
  final ScrollController _pastScrollController = ScrollController();

  final Map<int, GlobalKey> _todayPeriodKeys = {};
  final Map<int, GlobalKey> _yesterdayPeriodKeys = {};
  final Map<int, GlobalKey> _pastPeriodKeys = {};

  int? _pendingScrollPeriodNumber;
  int? _pendingScrollTabIndex;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _loadPastPeriods(_selectedPastDate);
      final facultyService = Provider.of<FacultyService>(context, listen: false);
      if (facultyService.classAdvisorSchedule.isEmpty) {
        facultyService.fetchClassAdvisorTimetable();
      }
    });
  }

  void _onTabChanged() {
    _pendingScrollPeriodNumber = null;
    _pendingScrollTabIndex = null;
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _todayScrollController.dispose();
    _yesterdayScrollController.dispose();
    _pastScrollController.dispose();
    super.dispose();
  }

  GlobalKey _getOrCreatePeriodKey(int tabIndex, int periodNumber) {
    final map = tabIndex == 0
        ? _todayPeriodKeys
        : tabIndex == 1
            ? _yesterdayPeriodKeys
            : _pastPeriodKeys;
    return map.putIfAbsent(periodNumber, () => GlobalKey());
  }

  Future<void> _loadPastPeriods(DateTime date) async {
    if (!mounted) return;
    setState(() {
      _selectedPastDate = date;
      _isLoadingPast = true;
      _pastErrorMessage = null;
    });

    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      final facultyService = Provider.of<FacultyService>(context, listen: false);
      final res = await facultyService.fetchClassAdvisorPeriodsForDate(dateStr);
      if (mounted) {
        setState(() {
          _pastData = res;
          _isLoadingPast = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPast = false;
          _pastErrorMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingPast = false;
          _pastErrorMessage = 'Unable to load class advisor periods for this date.';
        });
      }
    }
  }

  Future<void> _pickPastDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedPastDate.isAfter(now) ? now : _selectedPastDate,
      firstDate: DateTime(2025, 1, 1),
      lastDate: now,
      builder: (context, child) => buildFacultyDatePickerTheme(context, child!),
    );
    if (picked != null) {
      _loadPastPeriods(picked);
    }
  }

  Future<void> _loadData({bool isRefresh = false}) async {
    if (isRefresh && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final facultyService = Provider.of<FacultyService>(context, listen: false);
      final res = await facultyService.fetchClassAdvisorAvailablePeriods();
      if (mounted) {
        setState(() {
          _data = res;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load class advisor periods. Please check connection.';
        });
      }
    }
  }

  void _openEntryScreen(ClassAdvisorPeriodItem period) async {
    final currentTabIndex = _tabController.index;
    final savedPeriodNumber = period.periodNumber;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FacultyClassAdvisorEntryScreen(
          timetableEntryId: period.timetableEntryId,
          date: period.date,
          dayOfWeek: period.dayOfWeek,
          periodName: period.periodName,
          periodNumber: period.periodNumber,
          periodTime: '${TimezoneUtils.format24hTo12h(period.startTime)} - ${TimezoneUtils.format24hTo12h(period.endTime)}',
          subjectCode: period.subjectCode,
          subjectName: period.subjectName,
          className: period.className,
          subjectFacultyName: period.subjectFacultyName,
        ),
      ),
    );

    if (result == true && mounted) {
      // 1. Authoritative reload from backend
      if (currentTabIndex == 2) {
        await _loadPastPeriods(_selectedPastDate);
      } else {
        await _loadData();
      }

      if (!mounted) return;
      if (_tabController.index != currentTabIndex) return;

      // 2. Identify active periods list
      final List<ClassAdvisorPeriodItem> activePeriods;
      if (currentTabIndex == 0) {
        activePeriods = _data?.todayPeriods ?? [];
      } else if (currentTabIndex == 1) {
        activePeriods = _data?.yesterdayPeriods ?? [];
      } else {
        activePeriods = _pastData?.periods ?? [];
      }

      // Sort in timetable order
      final sortedPeriods = List<ClassAdvisorPeriodItem>.from(activePeriods)
        ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));

      // 3. Find next eligible period (periodNumber > savedPeriodNumber and not already marked)
      ClassAdvisorPeriodItem? nextEligiblePeriod;
      for (final p in sortedPeriods) {
        if (p.periodNumber > savedPeriodNumber) {
          final bool isAlreadyMarked = p.status == 'ALREADY_MARKED';
          final bool isEligible = (p.status == 'AVAILABLE' || p.canMark) && !isAlreadyMarked;
          if (isEligible) {
            nextEligiblePeriod = p;
            break;
          }
        }
      }

      // 4. Handle completion or auto-scroll
      if (nextEligiblePeriod == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('All eligible periods for this date have been recorded.'),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF0B7A55),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        _scrollToPeriod(currentTabIndex, nextEligiblePeriod.periodNumber);
      }
    }
  }

  void _scrollToPeriod(int tabIndex, int periodNumber) {
    _pendingScrollTabIndex = tabIndex;
    _pendingScrollPeriodNumber = periodNumber;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_tabController.index != tabIndex) return;
      if (_pendingScrollTabIndex != tabIndex) return;
      if (_pendingScrollPeriodNumber != periodNumber) return;

      // Brief delay to allow the reloaded widget tree to finish laying out
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      if (_tabController.index != tabIndex) return;
      if (_pendingScrollTabIndex != tabIndex) return;
      if (_pendingScrollPeriodNumber != periodNumber) return;

      final key = _getOrCreatePeriodKey(tabIndex, periodNumber);
      final targetContext = key.currentContext;

      if (targetContext != null && targetContext.mounted) {
        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOutCubic,
          alignment: 0.0,
        );
      }
      _pendingScrollPeriodNumber = null;
      _pendingScrollTabIndex = null;
    });
  }

  void _showDailySummary(String date) async {
    final colors = context.colors;
    final typography = context.typography;

    try {
      final facultyService = Provider.of<FacultyService>(context, listen: false);
      final summary = await facultyService.fetchClassAdvisorDailySummary(date);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: colors.surface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: Row(
            children: [
              Icon(Icons.analytics_rounded, color: colors.primary, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Daily Half-Day Summary',
                  style: typography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.75,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${summary.className} — $date',
                    style: typography.caption.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: AppRadius.mediumBorder,
                      border: Border.all(color: colors.glassBorder),
                    ),
                    child: DailyAttendanceSummaryMetrics(summary: summary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Student Statuses:',
                    style: typography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: summary.students.length,
                      itemBuilder: (context, idx) {
                        final st = summary.students[idx];
                        Color badgeColor = colors.textMuted;
                        if (st.dailyResult == 'FULL DAY PRESENT') badgeColor = colors.present;
                        if (st.dailyResult == 'HALF-DAY PRESENT') badgeColor = colors.present;
                        if (st.dailyResult == 'FULL DAY ABSENT') badgeColor = colors.error;
                        if (st.dailyResult == 'OD') badgeColor = colors.warning;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: colors.surfaceMuted,
                            borderRadius: AppRadius.smallBorder,
                            border: Border.all(color: colors.glassBorder),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      st.fullName,
                                      style: typography.bodySmall.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'M: ${st.morningStatus} | A: ${st.afternoonStatus}',
                                      style: typography.caption.copyWith(color: colors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.15),
                                  borderRadius: AppRadius.pillBorder,
                                  border: Border.all(color: badgeColor, width: 0.8),
                                ),
                                child: Text(
                                  st.dailyResult,
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: badgeColor),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load daily summary.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final facultyService = Provider.of<FacultyService>(context);
    Widget content;

    if (_isLoading) {
      content = Center(child: CircularProgressIndicator(color: colors.primary));
    } else if (_errorMessage != null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: GlassCard(
            variant: GlassCardVariant.standard,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: colors.error),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: typography.bodyMedium.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  text: 'Retry',
                  icon: Icons.refresh_rounded,
                  onPressed: _loadData,
                ),
              ],
            ),
          ),
        ),
      );
    } else if (_data == null || !_data!.isClassAdvisor) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: GlassCard(
            variant: GlassCardVariant.standard,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 56, color: colors.textMuted),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No Class Advisor Assignment',
                  style: typography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'You are currently not designated as the Class Advisor for any class section. Contact the administrator to assign this role.',
                  textAlign: TextAlign.center,
                  style: typography.bodySmall.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      final advisedClass = _data!.advisedClass;

      content = Column(
        children: [
            // Class Advisor Header
            GlassCard(
              variant: GlassCardVariant.hero,
              margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.heroChip,
                      borderRadius: AppRadius.smallBorder,
                    ),
                    child: Icon(Icons.supervisor_account_rounded, color: colors.accentOnHero, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.accent,
                                borderRadius: AppRadius.pillBorder,
                              ),
                              child: Text(
                                'CLASS ADVISOR',
                                style: TextStyle(
                                  color: colors.onPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          advisedClass?.name ?? 'Assigned Class',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: colors.onHero,
                          ),
                          softWrap: true,
                        ),
                        if (advisedClass?.gradeLevel != null || advisedClass?.academicYear != null)
                          Text(
                            'Year: ${advisedClass?.academicYear ?? "N/A"} | Grade: ${advisedClass?.gradeLevel ?? "N/A"}',
                            style: TextStyle(fontSize: 11, color: colors.onHeroSecondary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: colors.glassSurfaceStrong,
                border: Border(bottom: BorderSide(color: colors.glassBorder)),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                indicatorColor: colors.primary,
                indicatorWeight: 3,
                labelColor: colors.primary,
                unselectedLabelColor: colors.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                tabs: const [
                  Tab(text: 'TODAY'),
                  Tab(text: 'YESTERDAY'),
                  Tab(text: 'PAST DATES'),
                  Tab(key: Key('tab_class_schedule'), text: 'CLASS SCHEDULE'),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPeriodSchedule(
                    tabIndex: 0,
                    scrollController: _todayScrollController,
                    periods: _data!.todayPeriods,
                    dateStr: _data!.todayDate,
                    dayStr: _data!.todayDay,
                    isToday: true,
                  ),
                  _buildPeriodSchedule(
                    tabIndex: 1,
                    scrollController: _yesterdayScrollController,
                    periods: _data!.yesterdayPeriods,
                    dateStr: _data!.yesterdayDate,
                    dayStr: _data!.yesterdayDay,
                    isToday: false,
                  ),
                  _buildPastDatesTab(),
                  _buildClassScheduleTab(facultyService),
                ],
              ),
            ),
          ],
        );
    }

    if (widget.isStandalone) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Class Advisor Management'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _loadData,
            ),
          ],
        ),
        body: content,
      );
    }

    return content;
  }

  Widget _buildClassScheduleTab(FacultyService facultyService) {
    final colors = context.colors;
    final schedule = facultyService.classAdvisorSchedule;
    final advisedClass = _data?.advisedClass;
    final className = facultyService.classAdvisorClassName ??
        advisedClass?.name ??
        'Advised Class Schedule';

    if (facultyService.isLoading && schedule.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (facultyService.errorMessage != null && schedule.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: colors.error),
              const SizedBox(height: 12),
              Text(
                'Timetable Unavailable',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                facultyService.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => facultyService.fetchClassAdvisorTimetable(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh Timetable'),
              ),
            ],
          ),
        ),
      );
    }

    if (schedule.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month_rounded, size: 48, color: colors.textMuted),
              const SizedBox(height: 12),
              Text(
                'No schedule entries available',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No timetable entries configured for $className',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => facultyService.fetchClassAdvisorTimetable(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh Timetable'),
              ),
            ],
          ),
        ),
      );
    }

    return WeeklyMatrixTimetableView(
      items: schedule.map((i) => i.toTimetableItemModel()).toList(),
      title: 'Class Schedule',
      subtitle: className,
      showHeader: false,
    );
  }

  String _getNoClassesTitle({
    required bool isSunday,
    required int tabIndex,
    required String dateStr,
  }) {
    if (isSunday) {
      if (tabIndex == 0) {
        return 'No Classes Today';
      } else if (tabIndex == 1) {
        return 'No Classes Yesterday';
      } else {
        return 'No Classes on Sunday';
      }
    } else {
      return 'No classes scheduled for this date';
    }
  }

  Widget _buildNoClassesCard({
    required String title,
    required String subtitle,
    required bool isSunday,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    return Center(
      child: GlassCard(
        variant: GlassCardVariant.standard,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surfaceMuted,
                border: Border.all(
                  color: colors.glassBorder,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                isSunday ? Icons.hotel_class_rounded : Icons.event_busy_rounded,
                size: 34,
                color: isSunday ? colors.primary : colors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: typography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: typography.bodyMedium.copyWith(
                color: colors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSchedule({
    required int tabIndex,
    required ScrollController scrollController,
    required List<ClassAdvisorPeriodItem> periods,
    required String dateStr,
    required String dayStr,
    required bool isToday,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    final parsedDate = DateTime.tryParse(dateStr);
    final isSunday = (parsedDate != null && parsedDate.weekday == DateTime.sunday) ||
        dayStr.trim().toUpperCase() == 'SUNDAY';
    final hasAttendanceRecords = periods.any((p) => p.recordCount > 0 || p.status == 'ALREADY_MARKED');

    if (periods.isEmpty) {
      final title = _getNoClassesTitle(isSunday: isSunday, tabIndex: tabIndex, dateStr: dateStr);
      final String subtitle;
      if (isSunday) {
        subtitle = 'There are no scheduled classes on Sunday. Enjoy your day off!';
      } else {
        subtitle = 'There are no scheduled teaching periods for $dayStr ($dateStr).';
      }

      return RefreshIndicator(
        color: colors.primary,
        onRefresh: () => _loadData(isRefresh: true),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, 110),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (hasAttendanceRecords) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.surfaceMuted,
                  foregroundColor: colors.textPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder,
                    side: BorderSide(color: colors.glassBorder),
                  ),
                ),
                icon: Icon(Icons.analytics_rounded, size: 18, color: colors.primary),
                label: const Text(
                  'View Daily Half-Day Summary for this date',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: () => _showDailySummary(dateStr),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            _buildNoClassesCard(
              title: title,
              subtitle: subtitle,
              isSunday: isSunday,
            ),
          ],
        ),
      );
    }

    // Separate morning (P1-P4) and afternoon (P5-P7)
    final morning = periods.where((p) => p.periodNumber <= 4).toList();
    final afternoon = periods.where((p) => p.periodNumber >= 5).toList();

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () => _loadData(isRefresh: true),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 110),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Role Responsibility Notice Banner
          GlassCard(
            variant: GlassCardVariant.muted,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colors.infoBg,
                    borderRadius: AppRadius.smallBorder,
                  ),
                  child: Icon(Icons.verified_user_outlined, size: 20, color: colors.info),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isToday ? "Today's Periods ($dayStr, $dateStr)" : "Yesterday's Periods ($dayStr, $dateStr)",
                        style: typography.titleMedium.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "As Class Advisor, you have full authority to mark or edit attendance for every period (P1–P7) of your advised class across all subjects.",
                        style: typography.bodySmall.copyWith(color: colors.textSecondary),
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Daily Summary Shortcut Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.surfaceMuted,
              foregroundColor: colors.textPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.pillBorder,
                side: BorderSide(color: colors.glassBorder),
              ),
            ),
            icon: Icon(Icons.analytics_rounded, size: 18, color: colors.primary),
            label: const Text('View Daily Half-Day Summary for this date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            onPressed: () => _showDailySummary(dateStr),
          ),
          const SizedBox(height: AppSpacing.md),

          // MORNING SESSION HEADER
          _buildSessionHeader('MORNING SESSION (P1 – P4)', colors.primary),
          const SizedBox(height: AppSpacing.sm),

          if (morning.isEmpty)
            _buildEmptyPeriodNote('No morning timetable periods scheduled.')
          else
            ..._buildMorningList(morning, isToday, tabIndex),

          const SizedBox(height: AppSpacing.md),

          // AFTERNOON SESSION HEADER
          _buildSessionHeader('AFTERNOON SESSION (P5 – P7)', colors.accent),
          const SizedBox(height: AppSpacing.sm),

          if (afternoon.isEmpty)
            _buildEmptyPeriodNote('No afternoon timetable periods scheduled.')
          else
            ...afternoon.map((p) => _buildPeriodCard(p, isToday, tabIndex)),

          const SizedBox(height: AppSpacing.md),

          // COLLEGE DAY END FOOTER
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: AppRadius.pillBorder,
              border: Border.all(color: colors.glassBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flag_rounded, size: 16, color: colors.textMuted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Authoritative College Day Ends at 4:10 PM',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  List<Widget> _buildMorningList(List<ClassAdvisorPeriodItem> morning, bool isToday, int tabIndex) {
    List<Widget> widgets = [];
    for (int i = 0; i < morning.length; i++) {
      widgets.add(_buildPeriodCard(morning[i], isToday, tabIndex));
    }
    return widgets;
  }

  Widget _buildSessionHeader(String title, Color accent) {
    final colors = context.colors;
    final typography = context.typography;

    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(color: accent, borderRadius: AppRadius.pillBorder),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: typography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPeriodNote(String message) {
    final colors = context.colors;

    return GlassCard(
      variant: GlassCardVariant.standard,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: Text(message, style: TextStyle(color: colors.textMuted, fontSize: 12)),
      ),
    );
  }

  Widget _buildPeriodCard(ClassAdvisorPeriodItem period, bool isToday, int tabIndex) {
    final colors = context.colors;
    final typography = context.typography;
    final isAvailable = period.status == 'AVAILABLE';
    final isAlreadyMarked = period.status == 'ALREADY_MARKED';
    final isLocked = period.status == 'LOCKED';

    Color cardBorderColor = colors.glassBorder;
    if (isAvailable) {
      cardBorderColor = colors.present.withValues(alpha: 0.5);
    } else if (isAlreadyMarked) {
      cardBorderColor = colors.primary.withValues(alpha: 0.4);
    }

    return GlassCard(
      key: _getOrCreatePeriodKey(tabIndex, period.periodNumber),
      variant: isAvailable ? GlassCardVariant.elevated : GlassCardVariant.standard,
      enableBlur: false, // Smooth scroll list rule
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
      borderColor: cardBorderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? colors.presentBg
                      : isAlreadyMarked
                          ? colors.infoBg
                          : colors.surfaceMuted,
                  borderRadius: AppRadius.smallBorder,
                  border: Border.all(
                    color: isAvailable ? colors.present.withValues(alpha: 0.4) : colors.glassBorder,
                  ),
                ),
                child: Text(
                  'P${period.periodNumber}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isAvailable
                        ? colors.present
                        : isAlreadyMarked
                            ? colors.primary
                            : colors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${TimezoneUtils.format24hTo12h(period.startTime)} – ${TimezoneUtils.format24hTo12h(period.endTime)}',
                  style: typography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              _buildStatusPill(period),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${period.subjectName} (${period.subjectCode})',
            style: typography.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
            softWrap: true,
          ),
          const SizedBox(height: 2),
          Text(
            'Teacher: ${period.subjectFacultyName}',
            style: typography.caption.copyWith(color: colors.textMuted),
            softWrap: true,
          ),
          const SizedBox(height: AppSpacing.md),

          // Actions
          if (isLocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: AppRadius.smallBorder,
                border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_clock, size: 15, color: colors.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      period.lockReason ?? 'Attendance opens at ${TimezoneUtils.format24hTo12h(period.startTime)}',
                      style: TextStyle(fontSize: 11, color: colors.warning, fontWeight: FontWeight.w500),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            )
          else if (isAlreadyMarked)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                ),
                onPressed: () => _openEntryScreen(period),
                icon: Icon(Icons.edit_rounded, size: 16, color: colors.primary),
                label: Text(
                  'EDIT ATTENDANCE (${period.recordCount} RECORDED)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            )
          else if (isAvailable)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.present,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                ),
                onPressed: () => _openEntryScreen(period),
                icon: const Icon(Icons.edit_note, color: Colors.white, size: 18),
                label: const Text(
                  'RECORD ATTENDANCE',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(ClassAdvisorPeriodItem period) {
    final colors = context.colors;

    if (period.status == 'AVAILABLE') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: colors.presentBg,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(color: colors.present.withValues(alpha: 0.4)),
        ),
        child: Text(
          'AVAILABLE',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.present, letterSpacing: 0.5),
        ),
      );
    } else if (period.status == 'ALREADY_MARKED') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: colors.infoBg,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(color: colors.primary.withValues(alpha: 0.4)),
        ),
        child: Text(
          'RECORDED',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.primary, letterSpacing: 0.5),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: colors.warningBg,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
        ),
        child: Text(
          'LOCKED',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.warning, letterSpacing: 0.5),
        ),
      );
    }
  }

  Widget _buildPastDatesTab() {
    final colors = context.colors;
    final typography = context.typography;
    final dateStr =
        '${_selectedPastDate.year.toString().padLeft(4, '0')}-${_selectedPastDate.month.toString().padLeft(2, '0')}-${_selectedPastDate.day.toString().padLeft(2, '0')}';

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () => _loadPastPeriods(_selectedPastDate),
      child: ListView(
        controller: _pastScrollController,
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 110),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Past Date Picker Header Card
          GlassCard(
            variant: GlassCardVariant.standard,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.smallBorder,
                  ),
                  child: Icon(Icons.calendar_month_rounded, color: colors.primary, size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected Date',
                        style: typography.caption.copyWith(color: colors.textMuted),
                      ),
                      Text(
                        _pastData != null
                            ? '${_pastData!.dayOfWeek}, $dateStr'
                            : dateStr,
                        style: typography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: _pickPastDate,
                  icon: const Icon(Icons.event, size: 16),
                  label: const Text('Change Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Daily Summary Shortcut Button (Only if attendance records or scheduled periods exist)
          if ((_pastData?.periods.isNotEmpty ?? false) ||
              (_pastData?.periods.any((p) => p.recordCount > 0 || p.status == 'ALREADY_MARKED') ?? false)) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.surfaceMuted,
                foregroundColor: colors.textPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.pillBorder,
                  side: BorderSide(color: colors.glassBorder),
                ),
              ),
              icon: Icon(Icons.analytics_rounded, size: 18, color: colors.primary),
              label: const Text('View Daily Half-Day Summary for this date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              onPressed: () => _showDailySummary(dateStr),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Content state
          if (_isLoadingPast)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator(color: colors.primary)),
            )
          else if (_pastErrorMessage != null)
            GlassCard(
              variant: GlassCardVariant.standard,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Icon(Icons.error_outline_rounded, color: colors.error, size: 40),
                  const SizedBox(height: AppSpacing.sm),
                  Text(_pastErrorMessage!, textAlign: TextAlign.center, style: TextStyle(color: colors.textPrimary)),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    text: 'Retry',
                    onPressed: () => _loadPastPeriods(_selectedPastDate),
                  ),
                ],
              ),
            )
          else if (_pastData != null && _pastData!.periods.isEmpty) ...[
            Builder(
              builder: (context) {
                final isSunday = _selectedPastDate.weekday == DateTime.sunday ||
                    (_pastData?.dayOfWeek.trim().toUpperCase() == 'SUNDAY');
                final title = _getNoClassesTitle(
                  isSunday: isSunday,
                  tabIndex: 2,
                  dateStr: dateStr,
                );
                final subtitle = isSunday
                    ? 'There are no scheduled classes on Sunday. Enjoy your day off!'
                    : 'There are no teaching periods scheduled for ${_pastData!.dayOfWeek} ($dateStr). Select another past date using the calendar.';
                return _buildNoClassesCard(
                  title: title,
                  subtitle: subtitle,
                  isSunday: isSunday,
                );
              },
            ),
          ]
          else if (_pastData != null) ...[
            // MORNING SESSION HEADER
            _buildSessionHeader('MORNING SESSION (P1 – P4)', colors.primary),
            const SizedBox(height: AppSpacing.sm),
            if (_pastData!.periods.where((p) => p.periodNumber <= 4).isEmpty)
              _buildEmptyPeriodNote('No morning timetable periods scheduled.')
            else
              ..._buildMorningList(_pastData!.periods.where((p) => p.periodNumber <= 4).toList(), false, 2),

            const SizedBox(height: AppSpacing.md),

            // AFTERNOON SESSION HEADER
            _buildSessionHeader('AFTERNOON SESSION (P5 – P7)', colors.accent),
            const SizedBox(height: AppSpacing.sm),
            if (_pastData!.periods.where((p) => p.periodNumber >= 5).isEmpty)
              _buildEmptyPeriodNote('No afternoon timetable periods scheduled.')
            else
              ..._pastData!.periods.where((p) => p.periodNumber >= 5).map((p) => _buildPeriodCard(p, false, 2)),

            const SizedBox(height: AppSpacing.md),

            // COLLEGE DAY END FOOTER
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: AppRadius.pillBorder,
                border: Border.all(color: colors.glassBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flag_rounded, size: 16, color: colors.textMuted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Authoritative College Day Ends at 4:10 PM',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ],
      ),
    );
  }
}
