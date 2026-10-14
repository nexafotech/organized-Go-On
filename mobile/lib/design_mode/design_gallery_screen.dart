import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../core/theme/theme_service.dart';
import '../widgets/widgets.dart';
import '../services/auth_service.dart';
import '../services/student_service.dart';
import '../services/faculty_service.dart';
import '../auth/screens/splash_screen.dart';
import '../auth/screens/login_screen.dart';
import '../student/screens/student_dashboard_screen.dart';
import '../student/screens/student_timetable_screen.dart';
import '../student/screens/student_attendance_report_screen.dart';
import '../student/screens/student_profile_screen.dart';
import '../student/screens/biometric_enrollment_screen.dart';
import '../faculty/screens/faculty_dashboard_screen.dart';
import '../faculty/screens/faculty_attendance_screen.dart';
import '../faculty/screens/faculty_class_advisor_screen.dart';
import '../faculty/screens/faculty_attendance_report_screen.dart';
import '../faculty/screens/faculty_notification_history_screen.dart';
import '../admin/screens/admin_student_face_screen.dart';
import '../admin/screens/admin_notification_screen.dart';
import 'design_mock_data.dart';

class DesignGalleryScreen extends StatefulWidget {
  const DesignGalleryScreen({Key? key}) : super(key: key);

  @override
  State<DesignGalleryScreen> createState() => _DesignGalleryScreenState();
}

class _DesignGalleryScreenState extends State<DesignGalleryScreen> {
  void _setupMockStudent(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    auth.setMockUser(DesignMockData.mockStudentUser);
    final studentService = Provider.of<StudentService>(context, listen: false);
    studentService.setMockData(
      summary: DesignMockData.mockStudentSummary,
      subjects: DesignMockData.mockSubjects,
      timetable: DesignMockData.mockTimetable,
      dateWise: DesignMockData.mockDateWise,
    );
  }

  void _setupMockFaculty(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    auth.setMockUser(DesignMockData.mockFacultyUser);
    final facultyService = Provider.of<FacultyService>(context, listen: false);
    facultyService.setMockData(
      schedule: DesignMockData.mockFacultySchedule,
      activeSlot: DesignMockData.mockActiveClassSlot,
      isClassAdvisor: true,
      advisedClass: DesignMockData.mockAdvisedClass,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          AppScaffold.buildLiquidAmbientCanvas(),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // Top App Bar with Liquid Glass Styling
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    decoration: BoxDecoration(
                      color: colors.glassSurfaceStrong,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.glassBorderStrong, width: 1.2),
                      boxShadow: AppGlass.shadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const GoOnLogoBadge(size: 44),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Go-On Design Studio',
                                    style: typography.headlineMedium.copyWith(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Liquid Glass UI/UX & #F6F1EA Palette Showcase',
                                    style: typography.bodySmall.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SafeThemeConsumer(
                              builder: (context, themeService, _) {
                                final isDark = themeService.isDarkMode;
                                return InkWell(
                                  onTap: () => themeService.toggleTheme(),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF262332) : const Color(0xFFEDE5DB),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isDark ? colors.accent.withValues(alpha: 0.5) : colors.borderStrong.withValues(alpha: 0.35),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                          size: 14,
                                          color: isDark ? const Color(0xFF818CF8) : const Color(0xFFBA5A31),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          isDark ? 'Dark' : 'Light',
                                          style: typography.labelMedium.copyWith(
                                            color: colors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: colors.accent.withValues(alpha: 0.12),
                                borderRadius: AppRadius.pillBorder,
                                border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                'v2.0.0+6',
                                style: typography.labelMedium.copyWith(
                                  color: colors.accentStrong,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          colors.isDark
                              ? 'Experience the deep Obsidian Liquid Glass UI design tuned for Apple VisionOS & dynamic dual-theming.'
                              : 'Experience the authentic Apple-grade Liquid Glass UI design tuned to linen-cream #F6F1EA & dynamic dual-theming.',
                          style: typography.bodyMedium.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),

                // Content Sections
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.list(
                    children: [
                      // Prominent Hero Launcher for Student Experience
                      GlassCard(
                        variant: GlassCardVariant.elevated,
                        padding: const EdgeInsets.all(18),
                        borderRadius: BorderRadius.circular(22),
                        margin: const EdgeInsets.only(bottom: 20),
                        child: InkWell(
                          onTap: () {
                            _setupMockStudent(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentDashboardScreen()));
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.primary.withValues(alpha: 0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.auto_graph_rounded, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Student Experience Live Demo',
                                          style: typography.titleMedium.copyWith(
                                            color: colors.textPrimary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: colors.presentBg,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'PRIMARY',
                                            style: TextStyle(
                                              color: colors.present,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Interactive Petal Chart, Period Completion Drainage & Multi-Ring Graph',
                                      style: typography.bodySmall.copyWith(
                                        color: colors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: colors.primary),
                            ],
                          ),
                        ),
                      ),
                      // Section: Auth Flow
                      _buildSectionHeader(context, '🔐 Authentication & Entry Screens'),
                  _buildScreenTile(
                    context,
                    title: 'Splash Screen',
                    subtitle: 'Brand logo lockup with animated loader on Espresso gradient',
                    icon: Icons.flash_on_rounded,
                    accentColor: colors.accent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SplashScreen())),
                  ),
                  _buildScreenTile(
                    context,
                    title: 'Login Screen (Student & Faculty)',
                    subtitle: 'Tabbed auth, server config modal, remember credentials',
                    icon: Icons.login_rounded,
                    accentColor: colors.info,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                  ),

                  const SizedBox(height: 24),
                  // Section: Student Experience
                  _buildSectionHeader(context, '🎓 Student Experience'),
                  _buildScreenTile(
                    context,
                    title: 'Student Dashboard',
                    subtitle: 'Attendance radial gauge, metrics cards, schedule highlights',
                    icon: Icons.dashboard_rounded,
                    accentColor: colors.success,
                    onTap: () {
                      _setupMockStudent(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentDashboardScreen()));
                    },
                  ),
                  _buildScreenTile(
                    context,
                    title: 'Student Timetable',
                    subtitle: 'Monday-to-Friday schedules, period cards, room numbers',
                    icon: Icons.calendar_month_rounded,
                    accentColor: colors.info,
                    onTap: () {
                      _setupMockStudent(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentTimetableScreen()));
                    },
                  ),
                  _buildScreenTile(
                    context,
                    title: 'Student Attendance History & Reports',
                    subtitle: 'Subject-wise progress bars, date breakdown matrix',
                    icon: Icons.analytics_rounded,
                    accentColor: colors.warning,
                    onTap: () {
                      _setupMockStudent(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentAttendanceReportScreen()));
                    },
                  ),
                  _buildScreenTile(
                    context,
                    title: 'Student Profile Screen',
                    subtitle: 'Personal details, biometric enrollment status, sign out',
                    icon: Icons.person_rounded,
                    accentColor: colors.accent,
                    onTap: () {
                      _setupMockStudent(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentProfileScreen()));
                    },
                  ),
                  _buildScreenTile(
                    context,
                    title: 'Biometric Face Enrollment Screen',
                    subtitle: 'Facial recognition capture camera interface & instructions',
                    icon: Icons.face_rounded,
                    accentColor: colors.primary,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BiometricEnrollmentScreen())),
                  ),

                  const SizedBox(height: 24),
                  // Section: Faculty Experience
                  _buildSectionHeader(context, '👨‍🏫 Faculty Experience'),
                  _buildScreenTile(
                    context,
                    title: 'Faculty Dashboard',
                    subtitle: 'Active class period banner, quick action tiles, today timetable',
                    icon: Icons.school_rounded,
                    accentColor: colors.accent,
                    onTap: () {
                      _setupMockFaculty(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FacultyDashboardScreen()));
                    },
                  ),
                  _buildScreenTile(
                    context,
                    title: 'Period Attendance Marker',
                    subtitle: 'Class selection, batch photo recognition trigger, timetable periods',
                    icon: Icons.how_to_reg_rounded,
                    accentColor: colors.success,
                    onTap: () {
                      _setupMockFaculty(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FacultyAttendanceScreen()));
                    },
                  ),
                  _buildScreenTile(
                    context,
                    title: 'Class Advisor Matrix Screen',
                    subtitle: 'Period-by-period daily student matrix and historical statistics',
                    icon: Icons.grid_view_rounded,
                    accentColor: colors.info,
                    onTap: () {
                      _setupMockFaculty(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FacultyClassAdvisorScreen()));
                    },
                  ),
                  _buildScreenTile(
                    context,
                    title: 'Attendance Report Exporter',
                    subtitle: 'Class date-range attendance reports with PDF & Excel download',
                    icon: Icons.picture_as_pdf_rounded,
                    accentColor: colors.error,
                    onTap: () {
                      _setupMockFaculty(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FacultyAttendanceReportScreen()));
                    },
                  ),
                  _buildScreenTile(
                    context,
                    title: 'Push Notifications History',
                    subtitle: 'Class announcements and automated attendance alert inbox',
                    icon: Icons.notifications_active_rounded,
                    accentColor: colors.warning,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FacultyNotificationHistoryScreen())),
                  ),

                  const SizedBox(height: 24),
                  // Section: Admin Tools
                  _buildSectionHeader(context, '⚙️ Admin Management UI'),
                  _buildScreenTile(
                    context,
                    title: 'Biometric Dataset Management',
                    subtitle: 'Student face image galleries, replace/enroll dataset dialogs',
                    icon: Icons.admin_panel_settings_rounded,
                    accentColor: colors.error,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminStudentFaceScreen())),
                  ),
                  _buildScreenTile(
                    context,
                    title: 'Notification Dispatcher Console',
                    subtitle: 'Push notification triggers, target class filters, delivery logs',
                    icon: Icons.broadcast_on_personal_rounded,
                    accentColor: colors.accent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminNotificationScreen())),
                  ),

                  const SizedBox(height: 28),
                  // Section: Design System Tokens & Swatches
                  _buildSectionHeader(context, '🎨 Design System Tokens & Primitives'),
                  _buildDesignTokensPreview(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  ),
);
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colors = context.colors;
    final typography = context.typography;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: typography.titleMedium.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildScreenTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        variant: GlassCardVariant.standard,
        padding: const EdgeInsets.all(14),
        borderRadius: AppRadius.mediumBorder,
        borderColor: colors.border.withValues(alpha: 0.5),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withValues(alpha: 0.35)),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: typography.titleMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: typography.bodySmall.copyWith(
                        color: colors.textMuted,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesignTokensPreview(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return GlassCard(
      variant: GlassCardVariant.standard,
      padding: const EdgeInsets.all(16),
      borderRadius: AppRadius.mediumBorder,
      borderColor: colors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Color Palette Tokens (#F6F1EA Canvas)', style: typography.titleMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildColorChip('Canvas #F6F1EA', const Color(0xFFF6F1EA), colors.textPrimary, borderColor: colors.borderStrong),
              _buildColorChip('Espresso #2B1A13', const Color(0xFF2B1A13), Colors.white),
              _buildColorChip('Accent Amber #B87B4B', colors.accent, Colors.white),
              _buildColorChip('Present #0B7A55', colors.present, Colors.white),
              _buildColorChip('Absent #B42318', colors.absent, Colors.white),
              _buildColorChip('OD #3D4FB8', colors.od, Colors.white),
            ],
          ),
          const SizedBox(height: 18),
          Text('Attendance Status Indicators', style: typography.titleMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildGaugePreview('Safe (>75%)', 88.5, colors.present, colors.textSecondary),
              _buildGaugePreview('Warning (70-75%)', 72.0, colors.warning, colors.textSecondary),
              _buildGaugePreview('Critical (<70%)', 48.0, colors.absent, colors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorChip(String label, Color color, Color textColor, {Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: borderColor ?? Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildGaugePreview(String label, double percentage, Color color, Color labelColor) {
    return Column(
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: percentage / 100,
                strokeWidth: 5,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Center(
                child: Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 10, color: labelColor, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
