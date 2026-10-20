import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_tokens.dart';
import '../../widgets/widgets.dart';
import '../../models/faculty_attendance_model.dart';
import '../../services/faculty_service.dart';
import '../../utils/timezone_utils.dart';
import 'faculty_attendance_entry_screen.dart';
import '../widgets/faculty_calendar_theme.dart';

class FacultyAttendanceScreen extends StatefulWidget {
  final bool isStandalone;
  const FacultyAttendanceScreen({Key? key, this.isStandalone = false}) : super(key: key);

  @override
  State<FacultyAttendanceScreen> createState() =>
      _FacultyAttendanceScreenState();
}

class _FacultyAttendanceScreenState extends State<FacultyAttendanceScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  AvailablePeriodsResponse? _data;

  DateTime _selectedPastDate = DateTime.now().subtract(const Duration(days: 1));
  bool _isLoadingPast = false;
  String? _pastErrorMessage;
  FacultyPeriodsForDateResponse? _pastData;

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
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAvailablePeriods();
      _loadPastPeriods(_selectedPastDate);
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
      final facultyService =
          Provider.of<FacultyService>(context, listen: false);
      final res = await facultyService.fetchPeriodsForDate(dateStr);
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
          _pastErrorMessage =
              'Unable to load attendance periods for this date.';
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

  Future<void> _loadAvailablePeriods({bool isRefresh = false}) async {
    if (isRefresh && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final facultyService =
          Provider.of<FacultyService>(context, listen: false);
      final res = await facultyService.fetchAvailableAttendancePeriods();
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
          _errorMessage =
              'Unable to load attendance periods. Please check your connection.';
        });
      }
    }
  }

  void _openEntryScreen(AvailablePeriodItem period) async {
    final currentTabIndex = _tabController.index;
    final savedPeriodNumber = period.periodNumber;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FacultyAttendanceEntryScreen(
          timetableEntryId: period.timetableEntryId,
          date: period.date,
          dayOfWeek: period.dayOfWeek,
          periodName: period.periodName,
          periodTime: '${TimezoneUtils.format24hTo12h(period.startTime)} - ${TimezoneUtils.format24hTo12h(period.endTime)}',
          subjectCode: period.subjectCode,
          subjectName: period.subjectName,
          className: period.className,
        ),
      ),
    );

    if (result == true && mounted) {
      if (currentTabIndex == 2) {
        await _loadPastPeriods(_selectedPastDate);
      } else {
        await _loadAvailablePeriods();
      }

      if (!mounted) return;
      if (_tabController.index != currentTabIndex) return;

      final List<AvailablePeriodItem> activePeriods;
      if (currentTabIndex == 0) {
        activePeriods = _data?.todayPeriods ?? [];
      } else if (currentTabIndex == 1) {
        activePeriods = _data?.yesterdayPeriods ?? [];
      } else {
        activePeriods = _pastData?.periods ?? [];
      }

      final sortedPeriods = List<AvailablePeriodItem>.from(activePeriods)
        ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));

      AvailablePeriodItem? nextEligiblePeriod;
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    Widget content;

    if (_isLoading) {
      content = Center(
        child: CircularProgressIndicator(color: colors.primary),
      );
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
                Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: colors.error,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: typography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: _loadAvailablePeriods,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      content = Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: colors.glassSurfaceStrong,
              border: Border(
                bottom: BorderSide(color: colors.glassBorder, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: colors.primary,
              indicatorWeight: 3,
              labelColor: colors.primary,
              unselectedLabelColor: colors.textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: const [
                Tab(text: 'TODAY'),
                Tab(text: 'YESTERDAY'),
                Tab(text: 'PAST DATES'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TODAY TAB
                _buildPeriodList(
                  tabIndex: 0,
                  scrollController: _todayScrollController,
                  periods: _data?.todayPeriods ?? [],
                  dateStr: _data?.todayDate ?? '',
                  dayStr: _data?.todayDay ?? '',
                  isToday: true,
                ),
                // YESTERDAY TAB
                _buildPeriodList(
                  tabIndex: 1,
                  scrollController: _yesterdayScrollController,
                  periods: _data?.yesterdayPeriods ?? [],
                  dateStr: _data?.yesterdayDate ?? '',
                  dayStr: _data?.yesterdayDay ?? '',
                  isToday: false,
                ),
                // PAST DATES TAB
                _buildPastDatesTab(),
              ],
            ),
          ),
        ],
      );
    }

    if (widget.isStandalone) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Attendance'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _loadAvailablePeriods,
            ),
          ],
        ),
        body: content,
      );
    }

    return content;
  }

  Widget _buildPeriodList({
    required int tabIndex,
    required ScrollController scrollController,
    required List<AvailablePeriodItem> periods,
    required String dateStr,
    required String dayStr,
    required bool isToday,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: _loadAvailablePeriods,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 110),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Informational Notice Banner
          GlassCard(
            variant: GlassCardVariant.muted,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isToday ? colors.infoBg : colors.surfaceMuted,
                    borderRadius: AppRadius.smallBorder,
                  ),
                  child: Icon(
                    isToday ? Icons.info_outline : Icons.history,
                    size: 20,
                    color: isToday ? colors.info : colors.accent,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isToday
                            ? "Today's Attendance Window"
                            : "Yesterday's Attendance Window",
                        style: typography.titleMedium.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isToday
                            ? "Attendance is available for completed periods. Current and upcoming periods unlock after their scheduled end time."
                            : "All scheduled periods from yesterday are available for attendance.",
                        style: typography.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Section Title
          Text(
            isToday
                ? "Today's Periods ($dayStr, $dateStr)"
                : "Yesterday's Periods ($dayStr, $dateStr)",
            style: typography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          if (periods.isEmpty)
            GlassCard(
              variant: GlassCardVariant.standard,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 48,
                    color: colors.textMuted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No scheduled classes.',
                    style: typography.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'There are no timetable slots scheduled for $dayStr.',
                    textAlign: TextAlign.center,
                    style: typography.bodySmall.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            )
          else
            ...periods.map((p) => _buildPeriodCard(p, isToday, tabIndex)).toList(),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildPeriodCard(AvailablePeriodItem period, bool isToday, int tabIndex) {
    final colors = context.colors;
    final typography = context.typography;
    final isAvailable = period.status == 'AVAILABLE';
    final isAlreadyMarked = period.status == 'ALREADY_MARKED';
    final isLocked = period.status == 'LOCKED';

    Color cardBorderColor = colors.glassBorder;
    if (isAvailable) {
      cardBorderColor = colors.present.withValues(alpha: 0.5);
    } else if (isAlreadyMarked) {
      cardBorderColor = colors.primary.withValues(alpha: 0.3);
    }

    return GlassCard(
      key: _getOrCreatePeriodKey(tabIndex, period.periodNumber),
      variant: isAvailable ? GlassCardVariant.elevated : GlassCardVariant.standard,
      enableBlur: false, // Smooth scroll list rule
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
      borderColor: cardBorderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Number + Time Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? colors.presentBg
                      : isAlreadyMarked
                          ? colors.infoBg
                          : colors.surfaceMuted,
                  borderRadius: AppRadius.smallBorder,
                  border: Border.all(
                    color: isAvailable
                        ? colors.present.withValues(alpha: 0.4)
                        : colors.glassBorder,
                  ),
                ),
                child: Text(
                  'P${period.periodNumber}',
                  style: TextStyle(
                    fontSize: 13,
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
                  '${TimezoneUtils.format24hTo12h(period.startTime)} - ${TimezoneUtils.format24hTo12h(period.endTime)}',
                  style: typography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              _buildStatusPill(period),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Subject Name & Code
          Text(
            '${period.subjectName} (${period.subjectCode})',
            style: typography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
            softWrap: true,
          ),
          const SizedBox(height: 4),

          // Class Section
          Text(
            period.className,
            style: typography.bodySmall.copyWith(
              color: colors.textMuted,
            ),
            softWrap: true,
          ),
          const SizedBox(height: AppSpacing.md),

          // Lock Reason or Action Button
          if (isLocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: AppRadius.smallBorder,
                border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_clock,
                    size: 16,
                    color: colors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      period.lockReason ??
                          'Attendance opens at ${TimezoneUtils.format24hTo12h(period.startTime)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            )
          else if (isAlreadyMarked)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.present,
                      side: BorderSide(color: colors.present, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.pillBorder,
                      ),
                    ),
                    onPressed: () => _openEntryScreen(period),
                    icon: Icon(Icons.check, size: 16, color: colors.present),
                    label: const Text(
                      'ATTENDANCE RECORDED',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else if (isAvailable)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.present,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
                onPressed: () => _openEntryScreen(period),
                icon: const Icon(Icons.edit_note, color: Colors.white, size: 18),
                label: const Text(
                  'MARK ATTENDANCE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(AvailablePeriodItem period) {
    final colors = context.colors;

    if (period.status == 'AVAILABLE') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colors.presentBg,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(color: colors.present.withValues(alpha: 0.4)),
        ),
        child: Text(
          'AVAILABLE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: colors.present,
            letterSpacing: 0.5,
          ),
        ),
      );
    } else if (period.status == 'ALREADY_MARKED') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colors.infoBg,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(color: colors.primary.withValues(alpha: 0.4)),
        ),
        child: Text(
          'RECORDED',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: colors.primary,
            letterSpacing: 0.5,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colors.warningBg,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
        ),
        child: Text(
          'LOCKED',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: colors.warning,
            letterSpacing: 0.5,
          ),
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
          const SizedBox(height: AppSpacing.md),

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
          else if (_pastData != null && _pastData!.periods.isEmpty)
            GlassCard(
              variant: GlassCardVariant.standard,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                children: [
                  Icon(Icons.event_busy, size: 48, color: colors.textMuted),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No Timetable Periods Scheduled',
                    style: typography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'There are no teaching periods scheduled for ${_pastData!.dayOfWeek} ($dateStr). Select another past date using the calendar.',
                    style: typography.bodySmall.copyWith(color: colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else if (_pastData != null)
            ..._pastData!.periods.map((p) => _buildPeriodCard(p, false, 2)),
        ],
      ),
    );
  }
}

