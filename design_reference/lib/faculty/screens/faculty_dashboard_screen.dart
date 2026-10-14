import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/theme_service.dart';
import '../../models/faculty_model.dart';
import '../../services/auth_service.dart';
import '../../services/faculty_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/widgets/change_password_dialog.dart';
import '../../widgets/widgets.dart';
import '../../core/network/api_client.dart';
import '../../services/notification_service.dart';
import 'faculty_notification_history_screen.dart';
import 'faculty_session_screen.dart';
import 'faculty_profile_screen.dart';
import 'faculty_attendance_screen.dart';
import 'faculty_class_advisor_screen.dart';
import 'faculty_attendance_report_screen.dart';

class FacultyDashboardScreen extends StatefulWidget {
  const FacultyDashboardScreen({Key? key}) : super(key: key);

  @override
  State<FacultyDashboardScreen> createState() => _FacultyDashboardScreenState();
}

class _FacultyDashboardScreenState extends State<FacultyDashboardScreen> {
  int _currentIndex = 0;
  String _selectedScheduleDay = 'MONDAY';

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

  @override
  void initState() {
    super.initState();
    _selectedScheduleDay = _getCurrentWeekdayName();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FacultyService>(context, listen: false).loadDashboardData();
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.currentUser?.forcePasswordChange == true) {
        ChangePasswordDialog.show(context, isMandatory: true);
      }
      final notifService = Provider.of<NotificationService>(context, listen: false);
      notifService.requestNotificationPermissions();
      notifService.startInAppPolling(ApiClient());
    });
  }

  @override
  void dispose() {
    NotificationService().stopInAppPolling();
    super.dispose();
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

    final firstName = user?.fullName.isNotEmpty == true
        ? user!.fullName.split(' ').first
        : (user?.username ?? 'Faculty');

    return RefreshIndicator(
      color: colors.primary,
      backgroundColor: colors.surface,
      onRefresh: () => facultyService.loadDashboardData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Faculty Identity / Greeting Hero Card
            GlassCard(
              variant: GlassCardVariant.elevated,
              padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: colors.heroChip,
                    child: Text(
                      (user?.fullName.isNotEmpty == true) ? user!.fullName[0].toUpperCase() : 'F',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Hey $firstName',
                                style: typography.bodySmall.copyWith(
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.glassSurfaceSubtle,
                                borderRadius: AppRadius.pillBorder,
                                border: Border.all(color: colors.glassBorder),
                              ),
                              child: Text(
                                isAdvisor ? 'CLASS ADVISOR' : 'FACULTY',
                                style: TextStyle(
                                  color: colors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.fullName.isNotEmpty == true ? user!.fullName : (user?.username ?? 'Faculty Member'),
                          style: typography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Faculty ID: ${user?.username ?? "N/A"}',
                          style: TextStyle(color: colors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 2. Mandatory Password Change Banner (if flagged by backend/admin)
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

            // 3. Schedule Loading State / Error State
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
            ] else if (facultyService.errorMessage != null && schedule.isEmpty) ...[
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
                              Text(
                                facultyService.errorMessage ?? 'Unable to connect to server.',
                                style: TextStyle(color: colors.textMuted, fontSize: 12),
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

            // 4. Active Session Resume Banner (if session is already running)
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

            // 5. Current Active Class Slot Card
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

            // 6. Class Advisor Card (if assigned)
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
                                    color: colors.onPrimary,
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

            // 7. Quick Access Cards
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    variant: GlassCardVariant.standard,
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
                    variant: GlassCardVariant.standard,
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

            // 8. Today's Schedule Overview
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
              ...todayClasses.map((item) => _buildScheduleCard(item, isToday: true)),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildTimetableTab(FacultyService facultyService) {
    final colors = context.colors;
    final typography = context.typography;
    final schedule = facultyService.schedule;
    final dayClasses = schedule.where((item) => item.dayOfWeek.toUpperCase() == _selectedScheduleDay.toUpperCase()).toList();

    return Column(
      children: [
        // Day Selection Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.glassSurfaceStrong,
            border: Border(bottom: BorderSide(color: colors.glassBorder)),
          ),
          child: Row(
            children: List.generate(_weekdays.length, (idx) {
              final dayCode = _weekdays[idx];
              final label = _dayLabels[idx];
              final isSelected = dayCode.toUpperCase() == _selectedScheduleDay.toUpperCase();
              final isCurrentDay = _isToday(dayCode);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedScheduleDay = dayCode);
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
                                : colors.surfaceMuted),
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
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    _selectedScheduleDay,
                    style: typography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (_isToday(_selectedScheduleDay)) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.presentBg,
                        borderRadius: AppRadius.pillBorder,
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
                '${dayClasses.length} Class${dayClasses.length == 1 ? "" : "es"}',
                style: TextStyle(fontSize: 12, color: colors.textMuted, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),

        // Timetable List
        Expanded(
          child: RefreshIndicator(
            color: colors.primary,
            backgroundColor: colors.surface,
            onRefresh: () => facultyService.fetchSchedule(),
            child: facultyService.isLoading && schedule.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : facultyService.errorMessage != null && schedule.isEmpty
                    ? Center(
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
                                facultyService.errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: colors.textMuted),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.primary,
                                  foregroundColor: colors.onPrimary,
                                  shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                                ),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry'),
                                onPressed: () => facultyService.fetchSchedule(),
                              ),
                            ],
                          ),
                        ),
                      )
                    : dayClasses.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 48),
                                  Icon(Icons.event_busy_outlined, size: 52, color: colors.textMuted),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    _selectedScheduleDay.toUpperCase() == 'SUNDAY'
                                        ? 'No Classes Scheduled'
                                        : 'No Classes on $_selectedScheduleDay',
                                    style: typography.titleMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _selectedScheduleDay.toUpperCase() == 'SUNDAY'
                                        ? 'Weekend — Sunday has no scheduled classes.'
                                        : 'No assigned periods configured for this day in the timetable.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: colors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                            itemCount: dayClasses.length,
                            itemBuilder: (context, index) {
                              return _buildScheduleCard(dayClasses[index], isToday: _isToday(_selectedScheduleDay));
                            },
                          ),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleCard(FacultyScheduleItem item, {bool isToday = false}) {
    final colors = context.colors;
    final typography = context.typography;

    return GlassCard(
      variant: GlassCardVariant.standard,
      enableBlur: false,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: AppRadius.smallBorder,
            ),
            child: Center(
              child: Text(
                'P${item.periodNumber}',
                style: TextStyle(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.subjectName,
                  style: typography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                ),
                const SizedBox(height: 3),
                Text(
                  'Code: ${item.subjectCode} | Class: ${item.className}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                  softWrap: true,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 14, color: colors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${item.startTime} - ${item.endTime}',
                        style: TextStyle(fontSize: 12, color: colors.textMuted),
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
                if (item.facultyName != null && item.facultyName!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 14, color: colors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.facultyName!,
                          style: TextStyle(fontSize: 12, color: colors.textMuted, fontWeight: FontWeight.w500),
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
      appBarTitle = 'Faculty Timetable';
    } else {
      appBarTitle = 'Faculty Profile';
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: _currentIndex == 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GoOnLogoBadge(size: 30),
                  const SizedBox(width: 10),
                  Flexible(child: Text(appBarTitle, overflow: TextOverflow.ellipsis)),
                ],
              )
            : Text(appBarTitle),
        elevation: 0,
        actions: [
          Consumer<NotificationService>(
            builder: (context, notifService, _) {
              final unread = notifService.unreadCount;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      unread > 0
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_outlined,
                      color: unread > 0 ? colors.primary : null,
                    ),
                    tooltip: 'Notifications',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FacultyNotificationHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.assessment_rounded),
            tooltip: 'Attendance Reports',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FacultyAttendanceReportScreen()),
              );
            },
          ),
          Consumer<ThemeService>(
            builder: (context, themeService, _) {
              final isDark = themeService.isDarkMode;
              return IconButton(
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
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.glassSurfaceStrong,
          border: Border(top: BorderSide(color: colors.glassBorder)),
          boxShadow: AppGlass.shadowFloating,
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: colors.primary,
          unselectedItemColor: colors.textMuted,
          type: BottomNavigationBarType.fixed,
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
    );
  }
}
