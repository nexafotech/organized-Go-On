import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/theme_service.dart';
import '../../services/auth_service.dart';
import '../../services/student_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/widgets/change_password_dialog.dart';
import '../../widgets/widgets.dart';
import 'biometric_enrollment_screen.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({Key? key}) : super(key: key);

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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final studentService = Provider.of<StudentService>(context);
    final summary = studentService.summary;

    if (studentService.isLoading && summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (summary == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_off_outlined, size: 48, color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Student profile details unavailable',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Unable to retrieve your student information from the server.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                text: 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: () => studentService.fetchStudentSummary(),
              ),
            ],
          ),
        ),
      );
    }

    final semesterDisplay = summary.semester != null
        ? (summary.semester!.toLowerCase().contains('semester')
            ? summary.semester!
            : 'Semester ${summary.semester}')
        : 'Semester 1';

    return Stack(
      children: [
        AppScaffold.buildLiquidAmbientCanvas(context),
        RefreshIndicator(
          color: colors.primary,
          backgroundColor: colors.surface,
          onRefresh: () => studentService.fetchStudentSummary(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Student Profile Header Card
                GlassCard(
                  variant: GlassCardVariant.elevated,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      UserAvatarWidget(
                        avatarId: summary.avatarId,
                        fallbackSeed: summary.registerNumber,
                        radius: 42,
                        showEditBadge: true,
                        onEditTap: () {
                          AvatarPickerSheet.show(
                            context: context,
                            currentAvatarId: summary.avatarId ?? '',
                            userSeed: summary.registerNumber,
                            onSave: (id) => studentService.updateAvatar(id),
                          );
                        },
                        onTap: () {
                          AvatarPickerSheet.show(
                            context: context,
                            currentAvatarId: summary.avatarId ?? '',
                            userSeed: summary.registerNumber,
                            onSave: (id) => studentService.updateAvatar(id),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        summary.fullName,
                        textAlign: TextAlign.center,
                        style: typography.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reg No: ${summary.registerNumber}',
                        style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: summary.isActive ? colors.presentBg : colors.errorBg,
                              borderRadius: AppRadius.pillBorder,
                              border: Border.all(
                                color: summary.isActive ? colors.present : colors.error,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  summary.isActive ? Icons.check_circle : Icons.cancel,
                                  size: 14,
                                  color: summary.isActive ? colors.present : colors.error,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  summary.isActive ? 'Active Student' : 'Account Disabled',
                                  style: TextStyle(
                                    color: summary.isActive ? colors.present : colors.error,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              AvatarPickerSheet.show(
                                context: context,
                                currentAvatarId: summary.avatarId ?? '',
                                userSeed: summary.registerNumber,
                                onSave: (id) => studentService.updateAvatar(id),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colors.primary.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_rounded, size: 12, color: colors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Edit Avatar',
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Academic & Student Information
                GlassCard(
                  variant: GlassCardVariant.standard,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                        child: Text(
                          'Academic Details',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      Divider(height: 1, color: colors.glassBorder),
                      _buildInfoTile(context, 'Full Name', summary.fullName, Icons.badge_outlined),
                      Divider(height: 1, indent: 56, color: colors.glassBorder),
                      _buildInfoTile(context, 'Register Number', summary.registerNumber, Icons.pin_outlined),
                      Divider(height: 1, indent: 56, color: colors.glassBorder),
                      _buildInfoTile(context, 'College Email', summary.email ?? 'Not specified', Icons.email_outlined),
                      Divider(height: 1, indent: 56, color: colors.glassBorder),
                      _buildInfoTile(context, 'Contact Phone', (summary.phone != null && summary.phone!.trim().isNotEmpty) ? summary.phone! : 'Not specified', Icons.phone_outlined),
                      Divider(height: 1, indent: 56, color: colors.glassBorder),
                      _buildInfoTile(context, 'Class Section', summary.className ?? 'Not assigned', Icons.school_outlined),
                      Divider(height: 1, indent: 56, color: colors.glassBorder),
                      _buildInfoTile(context, 'Department', summary.department ?? 'N/A', Icons.business_outlined),
                      Divider(height: 1, indent: 56, color: colors.glassBorder),
                      _buildInfoTile(context, 'Academic Semester', semesterDisplay, Icons.calendar_today_outlined),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Session & Server Information
                GlassCard(
                  variant: GlassCardVariant.standard,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                        child: Text(
                          'Session Information',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      Divider(height: 1, color: colors.glassBorder),
                      _buildInfoTile(context, 'User Role', 'STUDENT', Icons.security_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Appearance & Theme Switcher
                GlassCard(
                  variant: GlassCardVariant.standard,
                  padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Appearance & Theme',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Toggle between warm cream and obsidian liquid glass styles across the application.',
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SafeThemeConsumer(
                        builder: (context, themeService, _) {
                          final isDark = themeService.isDarkMode;
                          return Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => themeService.setThemeMode(ThemeMode.light),
                                  borderRadius: AppRadius.pillBorder,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: !isDark ? colors.primary : colors.glassSurfaceSubtle,
                                      borderRadius: AppRadius.pillBorder,
                                      border: Border.all(
                                        color: !isDark ? colors.primary : colors.glassBorder,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.light_mode_rounded,
                                          size: 16,
                                          color: !isDark ? colors.onPrimary : colors.textSecondary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Warm Light',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: !isDark ? colors.onPrimary : colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: InkWell(
                                  onTap: () => themeService.setThemeMode(ThemeMode.dark),
                                  borderRadius: AppRadius.pillBorder,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? colors.primary : colors.glassSurfaceSubtle,
                                      borderRadius: AppRadius.pillBorder,
                                      border: Border.all(
                                        color: isDark ? colors.primary : colors.glassBorder,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.dark_mode_rounded,
                                          size: 16,
                                          color: isDark ? colors.onPrimary : colors.textSecondary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Obsidian Abyss',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isDark ? colors.onPrimary : colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Security & Actions
                GlassCard(
                  variant: GlassCardVariant.standard,
                  padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Account Actions',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SecondaryButton(
                        text: 'Edit Profile Details',
                        icon: Icons.edit_note_rounded,
                        isFullWidth: true,
                        onPressed: () {
                          EditProfileSheet.show(
                            context: context,
                            summary: summary,
                            studentService: studentService,
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      PrimaryButton(
                        text: 'Biometric Face Enrollment',
                        icon: Icons.face_retouching_natural_rounded,
                        isFullWidth: true,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const BiometricEnrollmentScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SecondaryButton(
                        text: 'Change Password',
                        icon: Icons.key_rounded,
                        isFullWidth: true,
                        onPressed: () => ChangePasswordDialog.show(context),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.error,
                          side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: Icon(Icons.logout_rounded, size: 20, color: colors.error),
                        label: const Text('Sign Out'),
                        onPressed: () => _confirmLogout(context),
                      ),
                    ],
                  ),
                ),
                // Safe bottom clearance for floating navigation bar
                const SizedBox(height: 110),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(BuildContext context, String label, String value, IconData icon) {
    final colors = context.colors;
    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: colors.heroChip,
          borderRadius: AppRadius.smallBorder,
        ),
        child: Icon(icon, size: 20, color: colors.primary),
      ),
      title: Text(
        label,
        style: TextStyle(fontSize: 12, color: colors.textMuted, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        value,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary),
      ),
    );
  }
}
