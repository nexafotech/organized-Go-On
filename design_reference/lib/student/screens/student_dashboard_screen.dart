import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/theme_service.dart';
import '../../services/auth_service.dart';
import '../../services/student_service.dart';
import '../../models/student_model.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/widgets/change_password_dialog.dart';
import '../../widgets/widgets.dart';
import 'student_timetable_screen.dart';
import 'student_profile_screen.dart';
import 'student_attendance_report_screen.dart';
import 'biometric_enrollment_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({Key? key}) : super(key: key);

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  bool _showOnlyPast5Days = true;

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

  void _confirmLogout(BuildContext context) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
          side: BorderSide(color: colors.glassBorderStrong, width: 1.2),
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

    return RefreshIndicator(
      color: colors.primary,
      backgroundColor: colors.surface,
      onRefresh: () => studentService.loadDashboardData(),
      child: Stack(
        children: [
          // Apple Liquid Ambient Glow Backdrop (Blurred Orbs creating optical caustics behind glass)
          _buildLiquidAmbientCanvas(),

          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Student Profile Header Card (Upgraded Liquid Glass)
                Container(
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
                  // Top Row: Go-On Logo on Top-Left Corner, User Profile on Top-Right Corner
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Top Left Corner: Go-On Logo (Pure Transparent PNG - Opens Menu Drawer on Click)
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

                      // Top Right Corner: User Profile & Role Chip
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: colors.accent.withValues(alpha: 0.12),
                              borderRadius: AppRadius.pillBorder,
                              border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'STUDENT',
                              style: TextStyle(
                                color: colors.accentStrong,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() => _currentIndex = 3);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.borderStrong.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: colors.surfaceMuted,
                                child: Text(
                                  summary.fullName.isNotEmpty ? summary.fullName[0].toUpperCase() : 'S',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
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

                  // Student User Name in Caviar Dreams Font
                  Text(
                    summary.fullName,
                    style: TextStyle(
                      fontFamily: 'CaviarDreams',
                      fontFamilyFallback: const ['sans-serif'],
                      color: colors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Student Details (Reg No, Class, Department, Semester)
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
                            summary.registerNumber,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (summary.className != null && summary.className!.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.school_outlined, size: 14, color: colors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              summary.className!,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      if (summary.department != null && summary.department!.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.apartment_rounded, size: 14, color: colors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              '${summary.department}${summary.semester != null ? " • Sem ${summary.semester}" : ""}',
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

            // Interactive Overall Attendance Card with Concentric Rings Graph & Day-wise Calendar Heatmap Switch
            InteractiveAttendanceOverviewCard(
              summary: summary,
              dateWiseEntries: studentService.dateWise,
              subjects: studentService.subjects,
              timetable: studentService.timetable,
            ),
            // Minimum Attendance Recovery Alert Banner (only shown if attendance drops below minimum)
            if (summary.belowMinimum) ...[
              const SizedBox(height: AppSpacing.md),
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
            ],

            const SizedBox(height: AppSpacing.lg),
            SubjectPetalChartCard(
              subjects: studentService.subjects,
              timetable: studentService.timetable,
              minimumRequired: summary.minimumRequired,
            ),

            const SizedBox(height: AppSpacing.lg),
            Builder(
              builder: (context) {
                final allEntries = List<DateWiseEntryModel>.from(studentService.dateWise)
                  ..sort((a, b) => b.date.compareTo(a.date));
                final displayEntries = _showOnlyPast5Days
                    ? allEntries.take(5).toList()
                    : allEntries;
                final hasMoreThan5 = allEntries.length > 5;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: 'Daily Attendance History',
                      action: allEntries.isNotEmpty
                          ? InkWell(
                              onTap: hasMoreThan5
                                  ? () => setState(() => _showOnlyPast5Days = !_showOnlyPast5Days)
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: colors.glassSurfaceSubtle,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: hasMoreThan5
                                        ? colors.accent.withValues(alpha: 0.5)
                                        : colors.glassBorder,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 11.5,
                                      color: hasMoreThan5 ? colors.accent : colors.textSecondary,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _showOnlyPast5Days
                                          ? 'Past 5 Days'
                                          : 'All ${allEntries.length} Days',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: hasMoreThan5 ? colors.accent : colors.textSecondary,
                                      ),
                                    ),
                                    if (hasMoreThan5) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        _showOnlyPast5Days
                                            ? Icons.keyboard_arrow_down_rounded
                                            : Icons.keyboard_arrow_up_rounded,
                                        size: 14,
                                        color: colors.accent,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (displayEntries.isEmpty)
                      GlassCard(
                        variant: GlassCardVariant.muted,
                        enableBlur: false,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Center(
                          child: Text(
                            'No daily attendance records found.',
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        ),
                      )
                    else ...[
                      ...displayEntries.map((entry) => _buildDateWiseCard(entry)),
                      if (hasMoreThan5)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: AppSpacing.sm),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: () => setState(() => _showOnlyPast5Days = !_showOnlyPast5Days),
                              icon: Icon(
                                _showOnlyPast5Days ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                                size: 16,
                                color: colors.accent,
                              ),
                              label: Text(
                                _showOnlyPast5Days
                                    ? 'View All ${allEntries.length} Recorded Days'
                                    : 'Show Only Past 5 Days',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colors.accent,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    ],
  ),
);
  }

  Widget _buildLiquidAmbientCanvas() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // Ambient Electric Indigo Orb (Upper Right)
            Positioned(
              top: 40,
              right: -60,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6366F1).withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Ambient Liquid Emerald Orb (Mid Left)
            Positioned(
              top: 380,
              left: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF10B981).withValues(alpha: 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Ambient Liquid Radiant Amber Orb (Mid Right)
            Positioned(
              top: 720,
              right: -70,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFF8A00).withValues(alpha: 0.13),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Ambient Liquid Coral Rose Orb (Lower Left)
            Positioned(
              bottom: 160,
              left: -50,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFF43F5E).withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Ambient Liquid Violet Orb (Bottom Center)
            Positioned(
              bottom: -40,
              right: 40,
              child: Container(
                width: 290,
                height: 290,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF8B5CF6).withValues(alpha: 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
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
    final normalized = res.replaceAll('_', ' ').trim().toUpperCase();

    if (normalized.contains('FULL') && normalized.contains('PRESENT')) {
      badgeColor = colors.present;
      badgeBg = colors.presentBg;
    } else if (normalized.contains('HALF') || normalized.contains('PARTIAL')) {
      badgeColor = colors.warning;
      badgeBg = colors.warningBg;
    } else if (normalized.contains('ABSENT')) {
      badgeColor = colors.absent;
      badgeBg = colors.absentBg;
    } else if (normalized.contains('OD') || normalized.contains('DUTY')) {
      badgeColor = colors.od;
      badgeBg = colors.odBg;
    }

    return GlassCard(
      variant: GlassCardVariant.standard,
      enableBlur: true,
      blur: 16,
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

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.background,
      drawer: _buildStudentDrawer(context, studentService),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: tabs,
        ),
      ),
      bottomNavigationBar: Padding(
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentDrawer(BuildContext context, StudentService studentService) {
    final colors = context.colors;
    final summary = studentService.summary;
    final studentName = (summary?.fullName != null && summary!.fullName.isNotEmpty)
        ? summary.fullName
        : 'Student';
    final regNo = (summary?.registerNumber != null && summary!.registerNumber.isNotEmpty)
        ? summary.registerNumber
        : '2024CS101';
    final className = (summary?.className != null && summary!.className!.isNotEmpty)
        ? summary.className!
        : 'B.Tech Computer Science';

    return Drawer(
      backgroundColor: colors.glassSurfaceStrong,
      surfaceTintColor: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Column(
          children: [
            // Drawer Header with Frosted Pearl Liquid Glass & student credentials
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.15),
                        borderRadius: AppRadius.pillBorder,
                        border: Border.all(color: colors.accent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'STUDENT PORTAL',
                        style: TextStyle(
                          color: colors.accentStrong,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  studentName,
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
                      regNo,
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
                        className,
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
                  subtitle: 'Attendance overview & analytics',
                  isSelected: _currentIndex == 0,
                  colors: colors,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 0);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.assessment_rounded,
                  title: 'Attendance Report',
                  subtitle: 'Subject-wise breakdown',
                  isSelected: _currentIndex == 1,
                  colors: colors,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 1);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.calendar_today_rounded,
                  title: 'Class Timetable',
                  subtitle: 'Daily class schedule',
                  isSelected: _currentIndex == 2,
                  colors: colors,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 2);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.person_rounded,
                  title: 'Student Profile',
                  subtitle: 'Personal & academic information',
                  isSelected: _currentIndex == 3,
                  colors: colors,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 3);
                  },
                ),
                const SizedBox(height: 12),
                Divider(color: colors.border.withValues(alpha: 0.5), height: 1),
                const SizedBox(height: 12),
                _buildDrawerSectionHeader('STUDENT SERVICES', colors),
                _buildDrawerItem(
                  icon: Icons.face_retouching_natural_rounded,
                  title: 'Biometric Face Enrollment',
                  subtitle: 'Register face for camera attendance',
                  isSelected: false,
                  colors: colors,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BiometricEnrollmentScreen(),
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
                Consumer<ThemeService>(
                  builder: (context, themeService, _) {
                    final isDark = themeService.isDarkMode;
                    return _buildDrawerItem(
                      icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      title: isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
                      subtitle: isDark ? 'Warm Cream & Roasted Espresso' : 'Deep Obsidian & Liquid Glass',
                      isSelected: false,
                      colors: colors,
                      onTap: () {
                        themeService.toggleTheme();
                      },
                    );
                  },
                ),
                if (Navigator.canPop(context)) ...[
                  _buildDrawerItem(
                    icon: Icons.palette_outlined,
                    title: 'Design Studio Gallery',
                    subtitle: 'Browse all UI role screens',
                    isSelected: false,
                    colors: colors,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                  ),
                ],
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
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: colors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colors.error.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded, color: colors.error, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Sign Out',
                            style: TextStyle(
                              color: colors.error,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
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
            color: isSelected ? colors.textPrimary : colors.textSecondary,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 11,
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.present,
                  boxShadow: [
                    BoxShadow(
                      color: colors.present.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              )
            : null,
        onTap: onTap,
        dense: true,
      ),
    );
  }
}
