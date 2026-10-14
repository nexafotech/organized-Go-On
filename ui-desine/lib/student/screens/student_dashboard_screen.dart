import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../services/auth_service.dart';
import '../../services/student_service.dart';
import '../../models/student_model.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/widgets/change_password_dialog.dart';
import '../../widgets/widgets.dart';
import 'student_timetable_screen.dart';
import 'student_profile_screen.dart';
import 'student_attendance_report_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({Key? key}) : super(key: key);

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StudentService>(context, listen: false).loadDashboardData();
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.currentUser?.forcePasswordChange == true) {
        ChangePasswordDialog.show(context, isMandatory: true);
      }
    });
  }

  Color _getStatusColor(String status, AppColors colors) {
    switch (status.toUpperCase()) {
      case 'CRITICAL':
        return colors.error;
      case 'WARNING':
        return colors.warning;
      case 'OK':
      default:
        return colors.success;
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
          'Are you sure you want to sign out of your student account?',
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

  Widget _buildDashboardTab(StudentService studentService) {
    final colors = context.colors;
    final typography = context.typography;
    final summary = studentService.summary;

    if (studentService.isLoading && summary == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              LoadingSkeleton.card(height: 100),
              SizedBox(height: AppSpacing.md),
              LoadingSkeleton.card(height: 220),
            ],
          ),
        ),
      );
    }

    if (studentService.errorMessage != null && summary == null) {
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
                'Attendance Data Unavailable',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                studentService.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                text: 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: () => studentService.loadDashboardData(),
              ),
            ],
          ),
        ),
      );
    }

    if (summary == null) {
      return Center(
        child: Text('No attendance data available', style: TextStyle(color: colors.textSecondary)),
      );
    }

    final statusColor = _getStatusColor(summary.attendanceStatus, colors);

    return RefreshIndicator(
      color: colors.primary,
      backgroundColor: colors.surface,
      onRefresh: () => studentService.loadDashboardData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Student Profile Header Card
            GlassCard(
              variant: GlassCardVariant.standard,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: colors.heroChip,
                    child: Text(
                      summary.fullName.isNotEmpty ? summary.fullName[0].toUpperCase() : 'S',
                      style: TextStyle(
                        fontSize: 22,
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
                          children: [
                            Expanded(
                              child: Text(
                                summary.fullName,
                                style: typography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.glassSurfaceSubtle,
                                borderRadius: AppRadius.pillBorder,
                                border: Border.all(color: colors.glassBorder),
                              ),
                              child: Text(
                                'STUDENT',
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
                        const SizedBox(height: 3),
                        Text(
                          'Reg No: ${summary.registerNumber} | Class: ${summary.className ?? "N/A"}',
                          style: TextStyle(color: colors.textSecondary, fontSize: 12),
                        ),
                        if (summary.department != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Dept: ${summary.department} | Sem: ${summary.semester ?? "N/A"}',
                            style: TextStyle(color: colors.textMuted, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Mandatory Password Change Banner (if flagged by backend/admin)
            if (Provider.of<AuthService>(context).currentUser?.forcePasswordChange == true) ...[
              GlassCard(
                variant: GlassCardVariant.muted,
                tint: colors.warning.withValues(alpha: 0.12),
                borderColor: colors.warning.withValues(alpha: 0.6),
                padding: const EdgeInsets.all(AppSpacing.md),
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
                          SizedBox(height: 2),
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
                        minimumSize: const Size(80, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.small)),
                      ),
                      onPressed: () => ChangePasswordDialog.show(context, isMandatory: true),
                      child: const Text('Update', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Overall Attendance % Card with AttendanceGauge
            GlassCard(
              variant: GlassCardVariant.elevated,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Overall Attendance',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: AppRadius.pillBorder,
                          border: Border.all(color: statusColor, width: 1.2),
                        ),
                        child: Text(
                          summary.attendanceStatus,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // AttendanceGauge
                  AttendanceGauge(
                    percentage: summary.percentage,
                    size: 150,
                    strokeWidth: 12,
                    showStatusText: true,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Min: ${summary.minimumRequired.toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 12, color: colors.textMuted, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 4 Stat Columns: Total, Present, Absent, OD
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: colors.glassSurfaceSubtle,
                      borderRadius: AppRadius.cardBorder,
                      border: Border.all(color: colors.glassBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn('Total', summary.total.toString(), colors.textPrimary),
                        _buildStatColumn('Present', summary.present.toString(), colors.present),
                        _buildStatColumn('Absent', summary.absent.toString(), colors.absent),
                        _buildStatColumn('OD', summary.od.toString(), colors.od),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Divider(height: 1, color: colors.glassBorder),
                  const SizedBox(height: AppSpacing.sm),

                  // Half-Day Counters
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.wb_sunny_outlined, size: 16, color: colors.present),
                          const SizedBox(width: 6),
                          Text(
                            'Half-Day Present: ',
                            style: TextStyle(fontSize: 12, color: colors.textSecondary),
                          ),
                          Text(
                            '${summary.halfDayPresent}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.present),
                          ),
                        ],
                      ),
                      Container(height: 16, width: 1, color: colors.glassBorder),
                      Row(
                        children: [
                          Icon(Icons.nightlight_round_outlined, size: 16, color: colors.absent),
                          const SizedBox(width: 6),
                          Text(
                            'Half-Day Absent: ',
                            style: TextStyle(fontSize: 12, color: colors.textSecondary),
                          ),
                          Text(
                            '${summary.halfDayAbsent}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.absent),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Minimum Attendance Recovery & Missable Alert Banner
            if (summary.belowMinimum) ...[
              GlassCard(
                variant: GlassCardVariant.muted,
                tint: colors.errorBg,
                borderColor: colors.error.withValues(alpha: 0.5),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: colors.error, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Attendance below required minimum',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colors.error,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Required classes to reach minimum: ${summary.requiredFutureClasses ?? 0}',
                      style: TextStyle(color: colors.error.withValues(alpha: 0.85), fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    if (summary.estimatedWorkingDays != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '• Estimated working days required: ${summary.estimatedWorkingDays}',
                        style: TextStyle(color: colors.error.withValues(alpha: 0.75), fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              GlassCard(
                variant: GlassCardVariant.muted,
                tint: colors.successBg,
                borderColor: colors.success.withValues(alpha: 0.5),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: colors.success, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attendance requirement satisfied',
                            style: TextStyle(fontWeight: FontWeight.bold, color: colors.success, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Classes you can miss while remaining safe: ${summary.missableFutureClasses ?? 0}',
                            style: TextStyle(color: colors.success.withValues(alpha: 0.85), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              text: 'VIEW FULL ATTENDANCE REPORT',
              icon: Icons.assessment_rounded,
              isFullWidth: true,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StudentAttendanceReportScreen()),
                );
              },
            ),

            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              title: 'Subject Breakdown',
            ),
            const SizedBox(height: AppSpacing.xs),

            // Subject Breakdown List
            if (studentService.subjects.isEmpty)
              GlassCard(
                variant: GlassCardVariant.muted,
                enableBlur: false,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: Text('No subject attendance recorded yet.', style: TextStyle(color: colors.textSecondary)),
                ),
              )
            else
              ...studentService.subjects.map((subj) {
                final isSafe = subj.percentage >= summary.minimumRequired;
                final subjStatusColor = isSafe ? colors.success : colors.error;

                return GlassCard(
                  variant: GlassCardVariant.standard,
                  enableBlur: false,
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: EdgeInsets.zero,
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                      title: Text(
                        subj.subjectName,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colors.textPrimary),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          'Code: ${subj.subjectCode} | Total Classes: ${subj.total}',
                          style: TextStyle(fontSize: 12, color: colors.textSecondary),
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: subjStatusColor.withValues(alpha: 0.15),
                          borderRadius: AppRadius.smallBorder,
                          border: Border.all(color: subjStatusColor, width: 1),
                        ),
                        child: Text(
                          '${subj.percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: subjStatusColor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),

            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: 'Daily Attendance History',
              action: studentService.dateWise.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.glassSurfaceSubtle,
                        borderRadius: AppRadius.smallBorder,
                        border: Border.all(color: colors.glassBorder),
                      ),
                      child: Text(
                        '${studentService.dateWise.length} Days Recorded',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textSecondary),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: AppSpacing.xs),
            if (studentService.dateWise.isEmpty)
              GlassCard(
                variant: GlassCardVariant.muted,
                enableBlur: false,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: Text('No daily attendance records found.', style: TextStyle(color: colors.textSecondary)),
                ),
              )
            else
              ...studentService.dateWise.map((entry) => _buildDateWiseCard(entry)),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildDateWiseCard(DateWiseEntryModel entry) {
    final colors = context.colors;
    Color badgeColor = colors.textMuted;
    Color badgeBg = colors.surfaceMuted;
    final res = entry.dailyResult ?? 'NOT ENTERED';

    if (res == 'FULL DAY PRESENT') {
      badgeColor = colors.present;
      badgeBg = colors.presentBg;
    } else if (res == 'HALF-DAY PRESENT') {
      badgeColor = colors.warning;
      badgeBg = colors.warningBg;
    } else if (res == 'FULL DAY ABSENT') {
      badgeColor = colors.absent;
      badgeBg = colors.absentBg;
    } else if (res == 'OD') {
      badgeColor = colors.od;
      badgeBg = colors.odBg;
    } else if (res == 'PARTIAL / MIXED') {
      badgeColor = colors.od;
      badgeBg = colors.odBg;
    }

    return GlassCard(
      variant: GlassCardVariant.standard,
      enableBlur: false,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          title: Row(
            children: [
              Icon(Icons.event_note_rounded, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                entry.date,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colors.textPrimary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeColor, width: 1),
                ),
                child: Text(
                  res,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              children: [
                Text(
                  'Morning: ${entry.morningStatus ?? "N/A"}',
                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                ),
                const SizedBox(width: 12),
                Text(
                  'Afternoon: ${entry.afternoonStatus ?? "N/A"}',
                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          children: [
            Divider(height: 1, color: colors.border),
            const SizedBox(height: AppSpacing.sm),
            // Institutional Lunch Break Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.lunchBg,
                borderRadius: AppRadius.smallBorder,
                border: Border.all(color: colors.lunch.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.restaurant_rounded, size: 14, color: colors.lunch),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Lunch Break: ${entry.lunchInterval} • Not counted',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.lunch),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (entry.periods.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text('No individual period records found.', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
              )
            else
              ...entry.periods.map((p) {
                Color statusColor = colors.textMuted;
                if (p.status == 'PRESENT') {
                  statusColor = colors.present;
                } else if (p.status == 'ABSENT') {
                  statusColor = colors.absent;
                } else if (p.status == 'OD') {
                  statusColor = colors.od;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'P${p.periodNumber ?? "?"}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colors.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.subjectName ?? p.subjectCode ?? p.periodName ?? 'Class Period',
                          style: TextStyle(fontSize: 12, color: colors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor, width: 0.8),
                        ),
                        child: Text(
                          p.status == 'OD' && p.odReason != null && p.odReason!.isNotEmpty
                              ? 'OD (${p.odReason})'
                              : p.status,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    final colors = context.colors;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colors.textSecondary, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final studentService = Provider.of<StudentService>(context);

    final List<Widget> tabs = [
      _buildDashboardTab(studentService),
      const StudentAttendanceReportScreen(),
      const StudentTimetableScreen(),
      const StudentProfileScreen(),
    ];

    String appBarTitle;
    if (_currentIndex == 0) {
      appBarTitle = 'Student Dashboard';
    } else if (_currentIndex == 1) {
      appBarTitle = 'Attendance Report';
    } else if (_currentIndex == 2) {
      appBarTitle = 'Class Timetable';
    } else {
      appBarTitle = 'Student Profile';
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
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assessment_rounded),
              label: 'Attendance',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_rounded),
              label: 'Timetable',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
