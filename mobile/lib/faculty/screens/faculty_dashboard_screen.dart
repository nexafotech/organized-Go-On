import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/theme_service.dart';
import '../../models/faculty_model.dart';
import '../../models/user_model.dart';
import '../../models/faculty_attendance_model.dart';
import '../../services/auth_service.dart';
import '../../services/faculty_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/widgets/change_password_dialog.dart';
import '../../widgets/widgets.dart';
import '../../core/network/api_client.dart';
import '../../services/notification_service.dart';
import '../../utils/timezone_utils.dart';
import 'faculty_notification_history_screen.dart';
import 'faculty_session_screen.dart';
import 'faculty_profile_screen.dart';
import 'faculty_attendance_screen.dart';
import 'faculty_class_advisor_screen.dart';
import 'faculty_attendance_report_screen.dart';
import 'faculty_attendance_entry_screen.dart';

class FacultyDashboardScreen extends StatefulWidget {
  final DateTime? simulatedTime;

  const FacultyDashboardScreen({
    Key? key,
    this.simulatedTime,
  }) : super(key: key);

  @override
  State<FacultyDashboardScreen> createState() => _FacultyDashboardScreenState();
}

class _FacultyDashboardScreenState extends State<FacultyDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  String _selectedScheduleDay = 'MONDAY';
  TimetableViewMode _timetableMode = TimetableViewMode.dayAgenda;
  bool _showClassAdvisorSchedule = false;

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

  Timer? _periodIconRefreshTimer;

  DateTime get _effectiveNow => widget.simulatedTime ?? TimezoneUtils.nowIst();

  void _startPeriodIconTicker() {
    if (widget.simulatedTime != null) return;
    _periodIconRefreshTimer?.cancel();
    _periodIconRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedScheduleDay = _getCurrentWeekdayName();
    _startPeriodIconTicker();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final facultyService = Provider.of<FacultyService>(context, listen: false);
      facultyService.loadDashboardData();
      if (facultyService.isClassAdvisor && facultyService.classAdvisorSchedule.isEmpty) {
        facultyService.fetchClassAdvisorTimetable();
      }
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.currentUser?.forcePasswordChange == true) {
        ChangePasswordDialog.show(context, isMandatory: true);
      }
      try {
        final notifService = Provider.of<NotificationService>(context, listen: false);
        notifService.requestNotificationPermissions();
        notifService.startInAppPolling(ApiClient());
        notifService.refreshUnreadCount(ApiClient());
        if (authService.currentUser != null) {
          notifService.registerTokenWithBackend(ApiClient(), user: authService.currentUser);
        }
      } catch (_) {
        // Safe fallback when running in widget test harness without NotificationService
      }
    });
  }

  @override
  void dispose() {
    _periodIconRefreshTimer?.cancel();
    _periodIconRefreshTimer = null;
    NotificationService().stopInAppPolling();
    super.dispose();
  }

  /// Returns the current weekday name in IST (Title Case, e.g. 'Monday').
  /// Uses _effectiveNow which is UTC+05:30 fixed-offset safe and supports simulated time.
  String _getCurrentWeekdayName() {
    final now = _effectiveNow;
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
    ];
    return days[now.weekday - 1];
  }

  bool _isToday(String day) {
    return day.toUpperCase() == _getCurrentWeekdayName().toUpperCase();
  }

  /// Computes the DateTime for the day at dayIndex (0 = Monday, ..., 6 = Sunday) in the current week (IST).
  DateTime _getDateForDayIndex(int dayIndex) {
    final nowIst = _effectiveNow;
    final monday = DateTime(nowIst.year, nowIst.month, nowIst.day)
        .subtract(Duration(days: nowIst.weekday - 1));
    return monday.add(Duration(days: dayIndex));
  }

  /// Returns YYYY-MM-DD formatted date string for a given weekday name in the current week.
  String _getDateForDay(String dayName) {
    final dayIndex = _weekdays.indexWhere((d) => d.toUpperCase() == dayName.toUpperCase());
    if (dayIndex == -1) {
      final nowIst = _effectiveNow;
      return '${nowIst.year}-${nowIst.month.toString().padLeft(2, '0')}-${nowIst.day.toString().padLeft(2, '0')}';
    }
    final targetDate = _getDateForDayIndex(dayIndex);
    return '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
  }

  /// Formatted date for the currently selected schedule day (e.g. '18 October 2026').
  String _getFormattedSelectedDate() {
    final dayIndex = _weekdays.indexWhere((d) => d.toUpperCase() == _selectedScheduleDay.toUpperCase());
    final dt = dayIndex != -1 ? _getDateForDayIndex(dayIndex) : _effectiveNow;
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  /// Evaluates whether a timetable period has finished based strictly on its scheduled end time.
  bool _isPeriodEnded(FacultyScheduleItem item, {DateTime? clockNow}) {
    final now = clockNow ?? _effectiveNow;
    final dayIndex = _weekdays.indexWhere((d) => d.toUpperCase() == _selectedScheduleDay.toUpperCase());
    if (dayIndex == -1) return false;
    final targetDate = _getDateForDayIndex(dayIndex);
    return TimezoneUtils.isPeriodCompleted(
      targetDate: targetDate,
      endTimeStr: item.endTime,
      now: now,
    );
  }

  Future<void> _startSession() async {
    final facultyService = Provider.of<FacultyService>(context, listen: false);
    final colors = context.colors;
    try {
      await facultyService.startSession();
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FacultySessionScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(facultyService.errorMessage ?? 'Failed to start session: $e'),
          backgroundColor: colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _confirmLogout(BuildContext context) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
          side: BorderSide(color: colors.border),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: colors.errorBg,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Icon(Icons.logout_rounded, color: colors.error, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Confirm Sign Out',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out of your faculty account?',
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final authService = Provider.of<AuthService>(context, listen: false);
              await authService.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Widget _buildLiquidAmbientCanvas() {
    return AppScaffold.buildLiquidAmbientCanvas(context);
  }

  FacultyScheduleItem? _getNextUpcomingClass(List<FacultyScheduleItem> todayClasses) {
    if (todayClasses.isEmpty) return null;
    final nowIst = TimezoneUtils.toIst(DateTime.now());
    final currentMinutes = nowIst.hour * 60 + nowIst.minute;

    FacultyScheduleItem? nextClass;
    int minStartDiff = 999999;

    for (final item in todayClasses) {
      final timeParts = item.startTime.split(':');
      if (timeParts.length >= 2) {
        final startMinutes =
            (int.tryParse(timeParts[0]) ?? 0) * 60 + (int.tryParse(timeParts[1]) ?? 0);
        final diff = startMinutes - currentMinutes;
        if (diff > 0 && diff < minStartDiff) {
          minStartDiff = diff;
          nextClass = item;
        }
      }
    }
    return nextClass;
  }

  Widget _buildFacultyProfileHeader({
    required AppColors colors,
    required AppTypography typography,
    required UserModel? user,
    required bool isAdvisor,
    required List<FacultyScheduleItem> schedule,
    required AdvisedClassInfo? advisedClass,
  }) {
    final facultyName = user?.fullName.isNotEmpty == true ? user!.fullName : (user?.username ?? 'Faculty Member');
    final facultyId = user?.employeeId?.isNotEmpty == true ? user!.employeeId! : (user?.username ?? 'N/A');
    final department = user?.department;
    final advisedClassName = advisedClass?.name ?? user?.advisedClassName;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppGlass.shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Go-On Logo on Top-Left Corner, Role pill + Notification bell + Avatar on Top-Right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Top Left: Go-On Logo (Opens Navigation Menu Drawer on Tap)
                    Tooltip(
                      message: 'Open Navigation Menu',
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            _scaffoldKey.currentState?.openDrawer();
                          },
                          child: const GoOnLogo(size: 48),
                        ),
                      ),
                    ),

                    // Top Right: Role Chip, Notification Bell & User Avatar
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: colors.accent.withValues(alpha: 0.12),
                            borderRadius: AppRadius.pillBorder,
                            border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            isAdvisor ? 'CLASS ADVISOR' : 'FACULTY',
                            style: TextStyle(
                              color: colors.accentStrong,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        // Notification Bell with unread badge counter
                        NotificationBellWidget(
                          activeColor: colors.accent,
                          inactiveColor: colors.textSecondary,
                          badgeColor: colors.error,
                          badgeBorderColor: colors.glassSurfaceStrong,
                        ),
                        const SizedBox(width: 4),
                        UserAvatarWidget(
                          avatarId: user?.avatarId,
                          fallbackSeed: user?.username ?? user?.fullName ?? 'faculty',
                          radius: 20,
                          borderWidth: 1.5,
                          borderColor: colors.borderStrong.withValues(alpha: 0.4),
                          onTap: () {
                            setState(() => _currentIndex = isAdvisor ? 4 : 3);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // "Welcome Back!" Label
                Text(
                  'Welcome Back!',
                  style: typography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),

                // Faculty User Name in Caviar Dreams Font
                Text(
                  facultyName,
                  style: TextStyle(
                    fontFamily: 'CaviarDreams',
                    fontFamilyFallback: const ['sans-serif'],
                    color: colors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Faculty Metadata Details (ID, Department, Advisor/Assigned Class)
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.badge_outlined, size: 14, color: colors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          'Faculty ID: $facultyId',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (department != null && department.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.apartment_rounded, size: 14, color: colors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            department,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    if (isAdvisor && advisedClassName != null && advisedClassName.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.supervisor_account_rounded, size: 14, color: colors.textMuted),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 240),
                            child: Text(
                              'Advisor: $advisedClassName',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    else if (schedule.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.school_outlined, size: 14, color: colors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '${schedule.map((e) => e.className).toSet().length} Classes Assigned',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
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

  Widget _buildDashboardTab(FacultyService facultyService, AuthService authService) {
    final colors = context.colors;
    final typography = context.typography;
    final user = authService.currentUser;
    final activeSlot = facultyService.activeSlot;
    final schedule = facultyService.schedule;
    final isAdvisor = facultyService.isClassAdvisor || user?.isClassAdvisor == true;

    // Today's classes
    final todayName = _getCurrentWeekdayName();
    final todayClasses = schedule.where((item) => item.dayOfWeek.toUpperCase() == todayName.toUpperCase()).toList();
    final nextUpcomingClass = _getNextUpcomingClass(todayClasses);

    return SizedBox.expand(
      child: RefreshIndicator(
        color: colors.primary,
        backgroundColor: colors.surface,
        onRefresh: () => facultyService.loadDashboardData(),
        child: Stack(
          children: [
            _buildLiquidAmbientCanvas(),
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Semantic / accessibility anchor for Faculty Dashboard
                  Semantics(
                    header: true,
                    child: const Offstage(
                      offstage: false,
                      child: SizedBox(
                        height: 0,
                        width: 0,
                        child: Text('Faculty Dashboard', style: TextStyle(fontSize: 0, color: Colors.transparent)),
                      ),
                    ),
                  ),

                  // 1. Faculty Profile Header Card (Student Portal reference design)
                  _buildFacultyProfileHeader(
                    colors: colors,
                    typography: typography,
                    user: user,
                    isAdvisor: isAdvisor,
                    schedule: schedule,
                    advisedClass: facultyService.advisedClass,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Schedule Loading State / Error State
                  if (facultyService.isLoading && schedule.isEmpty) ...[
                    GlassCard(
                      variant: GlassCardVariant.standard,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: colors.primary),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Loading faculty dashboard data...',
                            style: TextStyle(color: colors.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ] else if (() {
                    String? schedErr;
                    try {
                      schedErr = facultyService.scheduleErrorMessage;
                    } catch (_) {
                      schedErr = null;
                    }
                    return (schedErr != null || facultyService.errorMessage != null) && schedule.isEmpty;
                  }()) ...[
                    GlassCard(
                      variant: GlassCardVariant.standard,
                      borderColor: colors.error.withValues(alpha: 0.4),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.cloud_off_rounded, color: colors.error, size: 28),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Schedule Data Unavailable',
                                      style: typography.titleMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Builder(
                                      builder: (context) {
                                        String? schedErr;
                                        try {
                                          schedErr = facultyService.scheduleErrorMessage;
                                        } catch (_) {
                                          schedErr = null;
                                        }
                                        return Text(
                                          schedErr ??
                                              facultyService.errorMessage ??
                                              'Unable to connect to server.',
                                          style: TextStyle(color: colors.textMuted, fontSize: 12),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          PrimaryButton(
                            text: 'Retry',
                            icon: Icons.refresh_rounded,
                            onPressed: () => facultyService.loadDashboardData(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // 1. Current Scheduled Slot (Active session resume banner OR active slot card OR no-active-class card)
                  if (facultyService.activeSessionId != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.infoBg,
                        borderRadius: AppRadius.cardBorder,
                        border: Border.all(color: colors.info.withValues(alpha: 0.5), width: 1.5),
                        boxShadow: AppGlass.shadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.play_circle_fill_rounded, color: colors.info, size: 22),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Attendance Session In Progress',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: colors.info,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.info,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.edit_note_rounded, size: 20),
                            label: const Text(
                              'RESUME ATTENDANCE SESSION',
                              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const FacultySessionScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  if (activeSlot != null)
                    GlassCard(
                      variant: GlassCardVariant.hero,
                      padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Current Scheduled Slot',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: colors.onHeroSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colors.presentBg,
                                  borderRadius: AppRadius.pillBorder,
                                  border: Border.all(color: colors.present, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: colors.present,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'ACTIVE NOW',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: colors.present,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            '${activeSlot.subjectName} (${activeSlot.subjectCode})',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colors.onHero,
                            ),
                            softWrap: true,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: colors.heroChip,
                              borderRadius: AppRadius.mediumBorder,
                              border: Border.all(color: colors.border.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.school_outlined, size: 16, color: colors.accentOnHero),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        activeSlot.className,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colors.onHero,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        softWrap: true,
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Divider(height: 1, color: colors.border.withValues(alpha: 0.2)),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Row(
                                        children: [
                                          Icon(Icons.tag_rounded, size: 16, color: colors.accentOnHero),
                                          const SizedBox(width: 6),
                                          Text(
                                            'P${activeSlot.periodNumber}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: colors.onHero,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 6,
                                      child: Row(
                                        children: [
                                          Icon(Icons.access_time_rounded, size: 16, color: colors.accentOnHero),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '${activeSlot.startTime} - ${activeSlot.endTime}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: colors.onHero,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              softWrap: true,
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
                          const SizedBox(height: AppSpacing.lg),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.present,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.add_task_rounded, size: 20),
                              label: const Text(
                                'START ATTENDANCE SESSION',
                                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                              onPressed: facultyService.isLoading ? null : _startSession,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    GlassCard(
                      variant: GlassCardVariant.standard,
                      padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Current Scheduled Slot',
                                  style: typography.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colors.surfaceMuted,
                                  borderRadius: AppRadius.pillBorder,
                                  border: Border.all(color: colors.border),
                                ),
                                child: Text(
                                  'NO ACTIVE CLASS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Icon(Icons.event_available_rounded, size: 24, color: colors.textMuted),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'No class scheduled for your account at the current time.',
                                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),

                  // 2. Next Upcoming Class (when applicable)
                  if (nextUpcomingClass != null) ...[
                    GlassCard(
                      variant: GlassCardVariant.standard,
                      padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
                      borderColor: colors.accent.withValues(alpha: 0.35),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.upcoming_rounded, size: 18, color: colors.accent),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Next Upcoming Class',
                                    style: typography.titleMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colors.accent.withValues(alpha: 0.12),
                                  borderRadius: AppRadius.pillBorder,
                                  border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  'UPCOMING',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: colors.accentStrong,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '${nextUpcomingClass.subjectName} (${nextUpcomingClass.subjectCode})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                            softWrap: true,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.school_outlined, size: 14, color: colors.textMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  nextUpcomingClass.className,
                                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'P${nextUpcomingClass.periodNumber}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.primary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.schedule_rounded, size: 14, color: colors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                '${TimezoneUtils.format24hTo12h(nextUpcomingClass.startTime)} - ${TimezoneUtils.format24hTo12h(nextUpcomingClass.endTime)}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // 3. Today's Teaching Schedule Overview
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Today's Schedule ($todayName)",
                          style: typography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _currentIndex = isAdvisor ? 3 : 2),
                        child: Text(
                          'View Full Week',
                          style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  if (todayClasses.isEmpty)
                    GlassCard(
                      variant: GlassCardVariant.muted,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Center(
                        child: Text(
                          'No teaching sessions scheduled for today.',
                          style: TextStyle(color: colors.textMuted, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ...todayClasses.asMap().entries.map(
                          (entry) => _buildScheduleCard(entry.value, isToday: true, index: entry.key),
                        ),
                  const SizedBox(height: AppSpacing.md),

                  // 4. Authorized Attendance-Management Actions
                  Row(
                    children: [
                      Expanded(
                        child: GlassCard(
                          key: const ValueKey('faculty_quick_reports_card'),
                          variant: GlassCardVariant.standard,
                          enableBlur: false,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.xs),
                                    decoration: BoxDecoration(
                                      color: colors.heroChip,
                                      borderRadius: AppRadius.smallBorder,
                                    ),
                                    child: Icon(Icons.assessment_rounded, color: colors.primary, size: 20),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const FacultyAttendanceReportScreen()),
                                      );
                                    },
                                    child: Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.primary)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Attendance Reports & Matrix',
                                style: typography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Class summary rosters & daily P1–P7 matrices',
                                style: TextStyle(color: colors.textMuted, fontSize: 11),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: GlassCard(
                          key: const ValueKey('faculty_quick_attendance_card'),
                          variant: GlassCardVariant.standard,
                          enableBlur: false,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.xs),
                                    decoration: BoxDecoration(
                                      color: colors.presentBg,
                                      borderRadius: AppRadius.smallBorder,
                                    ),
                                    child: Icon(Icons.assignment_turned_in_rounded, color: colors.present, size: 20),
                                  ),
                                  const Spacer(),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colors.present,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      setState(() => _currentIndex = 1);
                                    },
                                    child: const Text('Open', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Mark Attendance',
                                style: typography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Today's completed & yesterday's periods",
                                style: TextStyle(color: colors.textMuted, fontSize: 11),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 5. Class Advisor Summary (only when applicable)
                  if (isAdvisor) ...[
                    GlassCard(
                      variant: GlassCardVariant.hero,
                      padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: colors.heroChip,
                                  borderRadius: AppRadius.smallBorder,
                                ),
                                child: Icon(Icons.supervisor_account_rounded, color: colors.accentOnHero, size: 24),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                          color: colors.onHero,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      facultyService.advisedClass?.name ?? user?.advisedClassName ?? 'Assigned Section',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: colors.onHero,
                                      ),
                                      softWrap: true,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'You have authoritative management privileges for all periods (P1–P7) of your advised class across all subjects.',
                            style: TextStyle(color: colors.onHeroSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.accent,
                                foregroundColor: colors.onPrimary,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                              ),
                              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                              label: const Text(
                                'MANAGE CLASS ATTENDANCE',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                              ),
                              onPressed: () {
                                setState(() {
                                  _currentIndex = 2; // Class Advisor Tab
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // 6. Mandatory Password Change Banner (if flagged by backend/admin)
                  if (user?.forcePasswordChange == true) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.warningBg,
                        borderRadius: AppRadius.mediumBorder,
                        border: Border.all(color: colors.warning.withValues(alpha: 0.5)),
                        boxShadow: AppGlass.shadow,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_reset_rounded, color: colors.warning, size: 24),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mandatory Password Update',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: colors.warning,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Administration has requested you set a new password.',
                                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.warning,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            onPressed: () => ChangePasswordDialog.show(context, isMandatory: true),
                            child: const Text('Update', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Generous bottom clearance ensuring full scrolling above bottom bar
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerSectionHeader(String title, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          color: colors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required AppColors colors,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      decoration: BoxDecoration(
        color: isSelected ? colors.primary.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? colors.primary.withValues(alpha: 0.22) : Colors.transparent,
          width: 1.1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        leading: Icon(
          icon,
          color: isSelected ? colors.primary : colors.textSecondary,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? colors.primary : colors.textPrimary,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 11,
          ),
        ),
        onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildFacultyDrawer(BuildContext context, FacultyService facultyService, AuthService authService) {
    final colors = context.colors;
    final user = authService.currentUser;
    final isAdvisor = facultyService.isClassAdvisor || user?.isClassAdvisor == true;
    final facultyName = user?.fullName.isNotEmpty == true ? user!.fullName : (user?.username ?? 'Faculty');
    final facultyId = user?.employeeId?.isNotEmpty == true ? user!.employeeId! : (user?.username ?? 'fac01');
    final deptOrClass = user?.department?.isNotEmpty == true
        ? user!.department!
        : (isAdvisor
            ? (facultyService.advisedClass?.name ?? user?.advisedClassName ?? 'Class Advisor')
            : 'Faculty Department');

    return Drawer(
      backgroundColor: colors.glassSurfaceStrong,
      surfaceTintColor: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Column(
          children: [
            // Drawer Header with Frosted Pearl Liquid Glass & faculty credentials
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.glassSurfaceStrong,
                    colors.glassSurface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(
                  bottom: BorderSide(color: colors.glassBorderStrong),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const GoOnLogo(size: 46),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.accent.withValues(alpha: 0.15),
                            borderRadius: AppRadius.pillBorder,
                            border: Border.all(color: colors.accent.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            isAdvisor ? 'CLASS ADVISOR PORTAL' : 'FACULTY PORTAL',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.accentStrong,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    facultyName,
                    style: TextStyle(
                      fontFamily: 'CaviarDreams',
                      fontFamilyFallback: const ['sans-serif'],
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.badge_outlined, size: 14, color: colors.textMuted),
                      const SizedBox(width: 5),
                      Text(
                        facultyId,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.textMuted.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          deptOrClass,
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

            // Drawer Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                children: [
                  _buildDrawerSectionHeader('MAIN NAVIGATION', colors),
                  _buildDrawerItem(
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    subtitle: 'Schedule overview & quick actions',
                    isSelected: _currentIndex == 0,
                    colors: colors,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 0);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.assignment_turned_in_rounded,
                    title: 'Attendance',
                    subtitle: 'Mark today & yesterday sessions',
                    isSelected: _currentIndex == 1,
                    colors: colors,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 1);
                    },
                  ),
                  if (isAdvisor)
                    _buildDrawerItem(
                      icon: Icons.supervisor_account_rounded,
                      title: 'Class Advisor',
                      subtitle: 'Manage advised class attendance',
                      isSelected: _currentIndex == 2,
                      colors: colors,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _currentIndex = 2);
                      },
                    ),
                  _buildDrawerItem(
                    icon: Icons.calendar_today_rounded,
                    title: 'Faculty Timetable',
                    subtitle: 'Weekly teaching timetable',
                    isSelected: _currentIndex == (isAdvisor ? 3 : 2),
                    colors: colors,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = isAdvisor ? 3 : 2);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.person_rounded,
                    title: 'Faculty Profile',
                    subtitle: 'Account & assignment details',
                    isSelected: _currentIndex == (isAdvisor ? 4 : 3),
                    colors: colors,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = isAdvisor ? 4 : 3);
                    },
                  ),
                  Builder(
                    builder: (context) {
                      NotificationService? notifService;
                      try {
                        notifService = Provider.of<NotificationService>(context);
                      } catch (_) {
                        notifService = null;
                      }
                      final unread = notifService?.unreadCount ?? 0;
                      return _buildDrawerItem(
                        icon: unread > 0 ? Icons.notifications_active_rounded : Icons.notifications_outlined,
                        title: 'Notifications',
                        subtitle: unread > 0
                            ? '$unread unread message${unread > 1 ? "s" : ""}'
                            : 'Alerts & announcements',
                        isSelected: false,
                        colors: colors,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FacultyNotificationHistoryScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Divider(color: colors.border.withValues(alpha: 0.5), height: 1),
                  const SizedBox(height: 12),
                  _buildDrawerSectionHeader('FACULTY SERVICES', colors),
                  _buildDrawerItem(
                    icon: Icons.assessment_rounded,
                    title: 'Attendance Reports & Matrix',
                    subtitle: 'Class rosters & daily matrices',
                    isSelected: false,
                    colors: colors,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FacultyAttendanceReportScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.lock_reset_rounded,
                    title: 'Change Password',
                    subtitle: 'Manage account security',
                    isSelected: false,
                    colors: colors,
                    onTap: () {
                      Navigator.pop(context);
                      ChangePasswordDialog.show(context);
                    },
                  ),
                ],
              ),
            ),

            // Drawer Footer with Logout
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: colors.border),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.pop(context);
                        _confirmLogout(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        decoration: BoxDecoration(
                          color: colors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colors.error.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.logout_rounded, color: colors.error, size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Sign Out',
                                style: TextStyle(
                                  color: colors.error,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Go-On v1.2',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvisorScopeSelector(FacultyService facultyService, AppColors colors) {
    final advisedClassName = facultyService.classAdvisorClassName ??
        facultyService.advisedClass?.name ??
        'Advised Class';

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildScopeTabButton(
              key: const Key('scope_my_schedule'),
              title: 'My Schedule',
              icon: Icons.person_rounded,
              isSelected: !_showClassAdvisorSchedule,
              colors: colors,
              onTap: () => setState(() => _showClassAdvisorSchedule = false),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildScopeTabButton(
              key: const Key('scope_class_schedule'),
              title: advisedClassName,
              icon: Icons.groups_rounded,
              isSelected: _showClassAdvisorSchedule,
              colors: colors,
              onTap: () {
                setState(() => _showClassAdvisorSchedule = true);
                if (facultyService.classAdvisorSchedule.isEmpty) {
                  facultyService.fetchClassAdvisorTimetable();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeTabButton({
    Key? key,
    required String title,
    required IconData icon,
    required bool isSelected,
    required AppColors colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (colors.isDark ? colors.surfaceElevated : colors.primary)
              : (colors.isDark ? colors.surface : colors.surfaceMuted),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (colors.isDark ? colors.accent : colors.primary)
                : colors.glassBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? (colors.isDark ? colors.accent : Colors.white)
                  : colors.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? (colors.isDark ? colors.textPrimary : Colors.white)
                      : colors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimetableTab(FacultyService facultyService) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = colors.isDark;
    final bool isAdvisorScope = _showClassAdvisorSchedule && facultyService.isClassAdvisor;
    List<FacultyScheduleItem> activeSchedule;
    try {
      activeSchedule = isAdvisorScope
          ? facultyService.classAdvisorSchedule
          : facultyService.schedule;
    } catch (_) {
      activeSchedule = facultyService.schedule;
    }
    bool isCurrentScheduleLoading;
    try {
      isCurrentScheduleLoading = isAdvisorScope
          ? facultyService.isClassAdvisorScheduleLoading
          : facultyService.isScheduleLoading;
    } catch (_) {
      isCurrentScheduleLoading = facultyService.isLoading;
    }
    String? currentScheduleError;
    try {
      currentScheduleError = isAdvisorScope
          ? facultyService.classAdvisorScheduleErrorMessage
          : facultyService.scheduleErrorMessage;
    } catch (_) {
      currentScheduleError = null;
    }

    final dayClasses = activeSchedule.where((item) {
      if (item.dayOfWeek.toUpperCase() != _selectedScheduleDay.toUpperCase()) {
        return false;
      }
      final subCode = item.subjectCode.toUpperCase();
      final subName = item.subjectName.toUpperCase();
      final pName = item.periodName.toUpperCase();
      if (subCode.contains('BREAK') || subName.contains('BREAK') || pName.contains('BREAK')) {
        return false;
      }
      if (subCode.contains('LUNCH') || subName.contains('LUNCH') || pName.contains('LUNCH')) {
        return false;
      }
      return true;
    }).toList();

    // Deduplicate distinct teaching periods by periodNumber to guard against duplicate timetable joins
    final distinctPeriodMap = <int, FacultyScheduleItem>{};
    for (final s in dayClasses) {
      if (s.periodNumber > 0) {
        distinctPeriodMap.putIfAbsent(s.periodNumber, () => s);
      }
    }
    final sessionCount = distinctPeriodMap.isNotEmpty ? distinctPeriodMap.length : dayClasses.length;

    if (_timetableMode == TimetableViewMode.weeklyGrid) {
      final className = facultyService.classAdvisorClassName ??
          facultyService.advisedClass?.name ??
          'Class Schedule';
      return SizedBox.expand(
        child: Column(
          children: [
            if (facultyService.isClassAdvisor)
              _buildAdvisorScopeSelector(facultyService, colors),
            Expanded(
              child: isCurrentScheduleLoading && activeSchedule.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : currentScheduleError != null && activeSchedule.isEmpty
                      ? _buildErrorState(facultyService, colors, typography, errorMessage: currentScheduleError)
                      : WeeklyMatrixTimetableView(
                          items: activeSchedule.map((i) => i.toTimetableItemModel()).toList(),
                          title: _showClassAdvisorSchedule ? 'Class Schedule' : 'Faculty Timetable',
                          subtitle: _showClassAdvisorSchedule
                              ? className
                              : (facultyService.schedule.isNotEmpty
                                  ? facultyService.schedule.first.className
                                  : 'Weekly Teaching Schedule'),
                          showHeader: false,
                        ),
            ),
          ],
        ),
      );
    }

    return SizedBox.expand(
      child: Column(
        children: [
          if (facultyService.isClassAdvisor)
            _buildAdvisorScopeSelector(facultyService, colors),
          // 7-Day Selector Strip (Reference Image 1)
        Container(
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(bottom: BorderSide(color: colors.border.withValues(alpha: 0.5))),
          ),
          child: Row(
            children: List.generate(_weekdays.length, (idx) {
              final dayCode = _weekdays[idx];
              final label = _dayLabels[idx];
              final isSelected = dayCode.toUpperCase() == _selectedScheduleDay.toUpperCase();
              final isCurrentDay = _isToday(dayCode);
              final targetDate = _getDateForDayIndex(idx);
              final hasClasses = activeSchedule.any(
                (item) => item.dayOfWeek.toUpperCase() == dayCode.toUpperCase(),
              );

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedScheduleDay = dayCode);
                    },
                    borderRadius: BorderRadius.circular(22),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? colors.surfaceElevated : const Color(0xFF261E1A))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                        border: isSelected
                            ? Border.all(
                                color: isDark ? colors.accent : const Color(0xFF261E1A),
                                width: 1.5,
                              )
                            : (isCurrentDay
                                ? Border.all(color: colors.primary.withValues(alpha: 0.4), width: 1.2)
                                : null),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Day label (e.g. 'Mon' - matches test selector)
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (isCurrentDay ? colors.primary : colors.textSecondary),
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Day number (e.g. '19')
                          Text(
                            '${targetDate.day}',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : (isCurrentDay ? colors.primary : colors.textPrimary),
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 5),
                          // Indicator dot
                          if (isSelected)
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            )
                          else if (isCurrentDay)
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.primary,
                              ),
                            )
                          else if (hasClasses)
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.textMuted.withValues(alpha: 0.5),
                              ),
                            )
                          else
                            const SizedBox(height: 5),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        // Daily Summary Subheader
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _selectedScheduleDay.isNotEmpty
                              ? _selectedScheduleDay[0].toUpperCase() +
                                  _selectedScheduleDay.substring(1).toLowerCase()
                              : '',
                          style: typography.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isToday(_selectedScheduleDay)) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: colors.presentBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.present.withValues(alpha: 0.5), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colors.present,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'TODAY',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: colors.present,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getFormattedSelectedDate(),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _buildSessionCountBadge(
              isLoading: isCurrentScheduleLoading && activeSchedule.isEmpty,
              hasError: currentScheduleError != null && activeSchedule.isEmpty,
              sessionCount: sessionCount,
              colors: colors,
              onRetry: () {
                if (_showClassAdvisorSchedule) {
                  facultyService.fetchClassAdvisorTimetable();
                } else {
                  facultyService.fetchSchedule();
                }
              },
            ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xs),

        // Timetable Session Cards List
        Expanded(
          child: RefreshIndicator(
            color: colors.primary,
            backgroundColor: colors.surface,
            onRefresh: () async {
              if (_showClassAdvisorSchedule) {
                await facultyService.fetchClassAdvisorTimetable();
              } else {
                await facultyService.fetchSchedule();
              }
            },
            child: isCurrentScheduleLoading && activeSchedule.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : currentScheduleError != null && activeSchedule.isEmpty
                    ? _buildErrorState(facultyService, colors, typography, errorMessage: currentScheduleError)
                    : dayClasses.isEmpty
                        ? _buildEmptyDayState(colors, typography)
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.xs,
                              AppSpacing.md,
                              110,
                            ),
                            itemCount: dayClasses.length,
                            itemBuilder: (context, index) {
                              return _buildScheduleCard(
                                dayClasses[index],
                                isToday: _isToday(_selectedScheduleDay),
                                index: index,
                              );
                            },
                          ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildEmptyDayState(AppColors colors, AppTypography typography) {
    final isSunday = _selectedScheduleDay.toUpperCase() == 'SUNDAY';
    final isSaturday = _selectedScheduleDay.toUpperCase() == 'SATURDAY';
    final isTodaySelected = _isToday(_selectedScheduleDay);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
          decoration: BoxDecoration(
            color: colors.surfaceElevated.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border.withValues(alpha: 0.6)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.heroChip,
                ),
                child: Icon(
                  isSunday || isSaturday ? Icons.wb_sunny_rounded : Icons.event_available_rounded,
                  size: 32,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                isSunday
                    ? 'Weekend — No Classes Scheduled'
                    : 'No Classes on $_selectedScheduleDay',
                textAlign: TextAlign.center,
                style: typography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isSunday
                    ? 'Sunday has no scheduled classes. Relax and recharge.'
                    : isSaturday
                        ? 'Saturday has no scheduled teaching periods.'
                        : 'No assigned periods configured for this day in your timetable.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.textMuted, height: 1.4),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (!isTodaySelected) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.today_rounded, size: 18),
                  label: Text('Go to Today (${_getCurrentWeekdayName()})'),
                  onPressed: () {
                    setState(() {
                      _selectedScheduleDay = _getCurrentWeekdayName().toUpperCase();
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionCountBadge({
    required bool isLoading,
    required bool hasError,
    required int sessionCount,
    required AppColors colors,
    required VoidCallback onRetry,
  }) {
    if (isLoading) {
      return Container(
        key: const Key('timetable_session_count_badge_loading'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (hasError) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('timetable_session_count_badge_error'),
          onTap: onRetry,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.refresh_rounded,
                  size: 13,
                  color: colors.error,
                ),
                const SizedBox(width: 4),
                Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      key: const Key('timetable_session_count_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$sessionCount Session${sessionCount == 1 ? "" : "s"}',
        style: TextStyle(
          fontSize: 12,
          color: colors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildErrorState(
    FacultyService facultyService,
    AppColors colors,
    AppTypography typography, {
    String? errorMessage,
  }) {
    String? scheduleErr;
    try {
      scheduleErr = facultyService.scheduleErrorMessage;
    } catch (_) {
      scheduleErr = null;
    }
    final String? errorText =
        errorMessage ?? scheduleErr ?? facultyService.errorMessage;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 52, color: colors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Timetable Unavailable',
              style: typography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              errorText ?? 'Unable to connect to server',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              onPressed: () {
                if (_showClassAdvisorSchedule) {
                  facultyService.fetchClassAdvisorTimetable();
                } else {
                  facultyService.fetchSchedule();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard(
    FacultyScheduleItem item, {
    bool isToday = false,
    int index = 0,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = colors.isDark;
    final palette = _TimetableCardPalette.of(index, isDark);

    final periodTimeText =
        '${TimezoneUtils.format24hTo12h(item.startTime)} - ${TimezoneUtils.format24hTo12h(item.endTime)}';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _handleSessionAction(item, isToday: isToday),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Period pill badge on left, circular action button on right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: palette.iconBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: palette.border,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: palette.accent,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Period ${item.periodNumber} • $periodTimeText',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: palette.accent,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Circular Action Button matching Reference Image 1
                    () {
                      final bool hasEnded = _isPeriodEnded(item);
                      return Semantics(
                        button: true,
                        label: hasEnded
                            ? 'Period completed'
                            : (isToday ? 'Mark attendance' : 'View session details'),
                        child: InkWell(
                          onTap: () => _handleSessionAction(item, isToday: isToday),
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? palette.iconBg : const Color(0xFF261E1A),
                              border: isDark
                                  ? Border.all(color: palette.accent.withValues(alpha: 0.6), width: 1.2)
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                hasEnded ? Icons.how_to_reg_rounded : Icons.person_rounded,
                                key: Key('period_action_icon_${item.id}'),
                                size: 19,
                                color: isDark ? palette.accent : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    }(),
                  ],
                ),

                const SizedBox(height: 12),

                // Main Subject Title
                Text(
                  item.subjectName,
                  style: typography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: colors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 6),

                // Subject Code & Class Name
                // NOTE: Preserves exact text format required by tests:
                // 'Code: ${item.subjectCode} | Class: ${item.className}'
                Text(
                  'Code: ${item.subjectCode} | Class: ${item.className}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.accent,
                  ),
                  softWrap: true,
                ),

                // Faculty Name (if assigned / co-taught)
                if (item.facultyName != null && item.facultyName!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: colors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.facultyName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                            fontWeight: FontWeight.w500,
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
        ),
      ),
    );
  }

  void _handleSessionAction(FacultyScheduleItem item, {required bool isToday}) {
    if (isToday) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FacultyAttendanceEntryScreen(
            timetableEntryId: item.id,
            date: _getDateForDay(_selectedScheduleDay),
            dayOfWeek: item.dayOfWeek,
            periodName: item.periodName.isNotEmpty ? item.periodName : 'Period ${item.periodNumber}',
            periodTime:
                '${TimezoneUtils.format24hTo12h(item.startTime)} - ${TimezoneUtils.format24hTo12h(item.endTime)}',
            subjectCode: item.subjectCode,
            subjectName: item.subjectName,
            className: item.className,
          ),
        ),
      );
    } else {
      _showSessionDetailSheet(item);
    }
  }

  void _showSessionDetailSheet(FacultyScheduleItem item) {
    TimetableSessionPopUp.showFromFacultySchedule(context, item);
  }


  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final facultyService = Provider.of<FacultyService>(context);
    final authService = Provider.of<AuthService>(context);
    final isAdvisor = facultyService.isClassAdvisor || authService.currentUser?.isClassAdvisor == true;

    final List<Widget> screens = [
      _buildDashboardTab(facultyService, authService),
      const FacultyAttendanceScreen(),
      if (isAdvisor) const FacultyClassAdvisorScreen(),
      _buildTimetableTab(facultyService),
      const FacultyProfileScreen(),
    ];

    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    String appBarTitle;
    if (_currentIndex == 0) {
      appBarTitle = 'Faculty Dashboard';
    } else if (_currentIndex == 1) {
      appBarTitle = 'Attendance';
    } else if (isAdvisor && _currentIndex == 2) {
      appBarTitle = 'Class Advisor';
    } else if ((isAdvisor && _currentIndex == 3) || (!isAdvisor && _currentIndex == 2)) {
      appBarTitle = (_showClassAdvisorSchedule && isAdvisor)
          ? 'Class Schedule'
          : 'Faculty Timetable';
    } else {
      appBarTitle = 'Faculty Profile';
    }

    final isDesktopOrLaptop = MediaQuery.sizeOf(context).width >= 900.0;

    final bottomNavWidget = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: AppGlass.shadowFloating,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
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
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: colors.glassBorderStrong,
                  width: 1.2,
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedItemColor: colors.primary,
                unselectedItemColor: colors.textMuted,
                type: BottomNavigationBarType.fixed,
                selectedFontSize: isAdvisor ? 11.0 : 12.0,
                unselectedFontSize: isAdvisor ? 10.5 : 11.5,
                selectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isAdvisor ? 11.0 : 12.0,
                  letterSpacing: isAdvisor ? -0.3 : -0.1,
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: isAdvisor ? 10.5 : 11.5,
                  letterSpacing: isAdvisor ? -0.3 : -0.1,
                ),
                iconSize: isAdvisor ? 22.0 : 24.0,
                onTap: (idx) => setState(() => _currentIndex = idx),
                items: [
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.dashboard_rounded),
                    label: 'Dashboard',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.assignment_turned_in_rounded),
                    label: 'Attendance',
                  ),
                  if (isAdvisor)
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.supervisor_account_rounded),
                      label: 'Advisor',
                    ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.calendar_today_rounded),
                    label: 'Timetable',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.person_rounded),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.background,
      drawer: _buildFacultyDrawer(context, facultyService, authService),
      appBar: _currentIndex == 0
          ? null
          : AppBar(
              titleSpacing: 12,
              leading: IconButton(
                icon: const GoOnLogoBadge(size: 26),
                tooltip: 'Open Menu',
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: Text(
                appBarTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
              elevation: 0,
              actions: [
                if ((isAdvisor && _currentIndex == 3) || (!isAdvisor && _currentIndex == 2))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Tooltip(
                      message: _timetableMode == TimetableViewMode.dayAgenda
                          ? 'Weekly Matrix View'
                          : 'Day Agenda View',
                      child: TimetableToggleMenuIcon(
                        isWeeklyGrid: _timetableMode == TimetableViewMode.weeklyGrid,
                        onTap: () {
                          setState(() {
                            _timetableMode = _timetableMode == TimetableViewMode.dayAgenda
                                ? TimetableViewMode.weeklyGrid
                                : TimetableViewMode.dayAgenda;
                          });
                        },
                      ),
                    ),
                  ),
                if (_currentIndex == 0)
                  NotificationBellWidget(
                    activeColor: colors.primary,
                    inactiveColor: colors.textSecondary,
                    badgeColor: colors.error,
                    badgeBorderColor: colors.surface,
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  icon: const Icon(Icons.assessment_rounded),
                  tooltip: 'Attendance Reports',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FacultyAttendanceReportScreen()),
                    );
                  },
                ),
                if (_currentIndex == screens.length - 1)
                  SafeThemeConsumer(
                    builder: (context, themeService, _) {
                      final isDark = themeService.isDarkMode;
                      return IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        icon: Icon(
                          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          color: isDark ? const Color(0xFFF59E0B) : colors.textPrimary,
                        ),
                        tooltip: isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
                        onPressed: () => themeService.toggleTheme(),
                      );
                    },
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Logout',
                  onPressed: () => _confirmLogout(context),
                ),
              ],
            ),
      body: SafeArea(
        child: isDesktopOrLaptop
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080.0),
                  child: IndexedStack(
                    index: _currentIndex,
                    children: screens,
                  ),
                ),
              )
            : IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
      ),
      bottomNavigationBar: isDesktopOrLaptop
          ? Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1.0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580.0),
                child: bottomNavWidget,
              ),
            )
          : bottomNavWidget,
    );
  }
}

class _TimetableCardPalette {
  final Color background;
  final Color border;
  final Color accent;
  final Color iconBg;
  final Color iconFg;
  final Color badgeBg;
  final Color badgeFg;

  const _TimetableCardPalette({
    required this.background,
    required this.border,
    required this.accent,
    required this.iconBg,
    required this.iconFg,
    required this.badgeBg,
    required this.badgeFg,
  });

  static _TimetableCardPalette of(int index, bool isDark) {
    if (isDark) {
      switch (index % 5) {
        case 0: // Warm Amber / Rust
          return const _TimetableCardPalette(
            background: Color(0xFF221812),
            border: Color(0xFF4A3222),
            accent: Color(0xFFE88A4B),
            iconBg: Color(0xFF352216),
            iconFg: Color(0xFFF09F67),
            badgeBg: Color(0xFF3D2518),
            badgeFg: Color(0xFFF3AB77),
          );
        case 1: // Slate / Cerulean Blue
          return const _TimetableCardPalette(
            background: Color(0xFF131C24),
            border: Color(0xFF233B4D),
            accent: Color(0xFF5BA4DC),
            iconBg: Color(0xFF1B2D3B),
            iconFg: Color(0xFF7CB8E8),
            badgeBg: Color(0xFF1D3242),
            badgeFg: Color(0xFF8DC4EE),
          );
        case 2: // Seafoam / Aqua Mint
          return const _TimetableCardPalette(
            background: Color(0xFF122223),
            border: Color(0xFF204547),
            accent: Color(0xFF43C5C1),
            iconBg: Color(0xFF183739),
            iconFg: Color(0xFF67DDD9),
            badgeBg: Color(0xFF1B3C3E),
            badgeFg: Color(0xFF7CE4E0),
          );
        case 3: // Warm Bronze Sand
          return const _TimetableCardPalette(
            background: Color(0xFF211D12),
            border: Color(0xFF423B1E),
            accent: Color(0xFFD4B743),
            iconBg: Color(0xFF332D16),
            iconFg: Color(0xFFE2CB66),
            badgeBg: Color(0xFF383118),
            badgeFg: Color(0xFFEAD477),
          );
        case 4: // Plum / Lavender
        default:
          return const _TimetableCardPalette(
            background: Color(0xFF201424),
            border: Color(0xFF42234B),
            accent: Color(0xFFBB70E0),
            iconBg: Color(0xFF321A3A),
            iconFg: Color(0xFFCE8DEE),
            badgeBg: Color(0xFF371C40),
            badgeFg: Color(0xFFD69BF3),
          );
      }
    } else {
      switch (index % 5) {
        case 0: // Soft Peach / Apricot (Reference Image 1 top card)
          return const _TimetableCardPalette(
            background: Color(0xFFFDF1E7),
            border: Color(0xFFF6DAC7),
            accent: Color(0xFFB55818),
            iconBg: Color(0xFFFCE3D2),
            iconFg: Color(0xFF91410D),
            badgeBg: Color(0xFFFCE3D2),
            badgeFg: Color(0xFF91410D),
          );
        case 1: // Soft Cloud Slate / Periwinkle (Reference Image 1 second card)
          return const _TimetableCardPalette(
            background: Color(0xFFEEF4F8),
            border: Color(0xFFD4E2EE),
            accent: Color(0xFF2B699B),
            iconBg: Color(0xFFDCE7F2),
            iconFg: Color(0xFF1E537F),
            badgeBg: Color(0xFFDCE7F2),
            badgeFg: Color(0xFF1E537F),
          );
        case 2: // Soft Sky / Aqua Mint (Reference Image 1 third card)
          return const _TimetableCardPalette(
            background: Color(0xFFE8F6F6),
            border: Color(0xFFC7EAE9),
            accent: Color(0xFF187B77),
            iconBg: Color(0xFFD2EFEB),
            iconFg: Color(0xFF10605D),
            badgeBg: Color(0xFFD2EFEB),
            badgeFg: Color(0xFF10605D),
          );
        case 3: // Soft Butter Sand (Reference Image 1 fourth card)
          return const _TimetableCardPalette(
            background: Color(0xFFFAF6E5),
            border: Color(0xFFEFE6C0),
            accent: Color(0xFF8C7114),
            iconBg: Color(0xFFF3ECCB),
            iconFg: Color(0xFF6C550A),
            badgeBg: Color(0xFFF3ECCB),
            badgeFg: Color(0xFF6C550A),
          );
        case 4: // Soft Lavender / Lilac
        default:
          return const _TimetableCardPalette(
            background: Color(0xFFF5EFF8),
            border: Color(0xFFE4D3EB),
            accent: Color(0xFF7A3B9A),
            iconBg: Color(0xFFEBDCF1),
            iconFg: Color(0xFF5F297C),
            badgeBg: Color(0xFFEBDCF1),
            badgeFg: Color(0xFF5F297C),
          );
      }
    }
  }
}
