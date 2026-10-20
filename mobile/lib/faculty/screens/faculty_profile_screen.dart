import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/theme_service.dart';
import '../../widgets/widgets.dart';
import '../../services/auth_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/widgets/change_password_dialog.dart';
import '../widgets/faculty_edit_profile_sheet.dart';

class FacultyProfileScreen extends StatelessWidget {
  const FacultyProfileScreen({Key? key}) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    if (user == null) {
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
                'Faculty details unavailable',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Please sign in to view your profile details.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                text: 'Go to Login',
                icon: Icons.login_rounded,
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    final isAdvisor = user.isClassAdvisor;
    final employeeIdDisplay = (user.employeeId != null && user.employeeId!.isNotEmpty)
        ? user.employeeId!
        : user.username;

    return Stack(
      children: [
        AppScaffold.buildLiquidAmbientCanvas(context),
        RefreshIndicator(
          color: colors.primary,
          backgroundColor: colors.surface,
          onRefresh: () async {
            // Authoritatively refresh faculty user info from backend
            await authService.refreshCurrentUser();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Redesigned Faculty Profile Header Card (Student Portal reference design)
                    GlassCard(
                      variant: GlassCardVariant.elevated,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xl),
                      child: Column(
                        children: [
                          UserAvatarWidget(
                            avatarId: user.avatarId,
                            fallbackSeed: user.username.isNotEmpty ? user.username : user.fullName,
                            radius: 46,
                            borderWidth: 2.0,
                            borderColor: colors.borderStrong.withValues(alpha: 0.4),
                            showEditBadge: true,
                            onEditTap: () {
                              AvatarPickerSheet.show(
                                context: context,
                                currentAvatarId: user.avatarId ?? '',
                                userSeed: user.username,
                                onSave: (id) => authService.updateFacultyAvatar(id),
                              );
                            },
                            onTap: () {
                              AvatarPickerSheet.show(
                                context: context,
                                currentAvatarId: user.avatarId ?? '',
                                userSeed: user.username,
                                onSave: (id) => authService.updateFacultyAvatar(id),
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            user.fullName.isNotEmpty ? user.fullName : user.username,
                            textAlign: TextAlign.center,
                            style: typography.titleLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Identifier: ${user.username}',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: user.isActive ? colors.presentBg : colors.errorBg,
                                  borderRadius: AppRadius.pillBorder,
                                  border: Border.all(
                                    color: user.isActive ? colors.present : colors.error,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      user.isActive ? Icons.check_circle : Icons.cancel,
                                      size: 14,
                                      color: user.isActive ? colors.present : colors.error,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        user.isActive ? 'Active Faculty Member' : 'Account Disabled',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: user.isActive ? colors.present : colors.error,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () => FacultyEditProfileSheet.show(context: context, user: user),
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
                                        'Edit Profile',
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

                    // 2. Organized Institutional & Account Information Card
                    GlassCard(
                      variant: GlassCardVariant.standard,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Account Details',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => FacultyEditProfileSheet.show(context: context, user: user),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit_outlined, size: 14, color: colors.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Edit',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: colors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: colors.glassBorder),
                          _buildInfoTile(context, 'Full Name', user.fullName.isNotEmpty ? user.fullName : user.username, Icons.badge_outlined),
                          Divider(height: 1, indent: 56, color: colors.glassBorder),
                          _buildInfoTile(context, 'Username / Employee ID', employeeIdDisplay, Icons.pin_outlined),
                          Divider(height: 1, indent: 56, color: colors.glassBorder),
                          _buildInfoTile(context, 'College Email', user.email.isNotEmpty ? user.email : 'Not specified', Icons.email_outlined),
                          Divider(height: 1, indent: 56, color: colors.glassBorder),
                          _buildInfoTile(context, 'Contact Phone', (user.phone != null && user.phone!.trim().isNotEmpty) ? user.phone! : 'Not specified', Icons.phone_outlined),
                          Divider(height: 1, indent: 56, color: colors.glassBorder),
                          _buildInfoTile(context, 'Department', (user.department != null && user.department!.trim().isNotEmpty) ? user.department! : 'Not assigned', Icons.business_outlined),
                          Divider(height: 1, indent: 56, color: colors.glassBorder),
                          _buildInfoTile(context, 'Designation & Role', user.role, Icons.work_outline_rounded),
                          Divider(height: 1, indent: 56, color: colors.glassBorder),
                          _buildInfoTile(
                            context,
                            'Class Advisor Assignment',
                            isAdvisor ? 'Class Advisor (${user.advisedClassName ?? "Assigned Class"})' : 'Standard Faculty',
                            Icons.supervisor_account_outlined,
                          ),
                          Divider(height: 1, indent: 56, color: colors.glassBorder),
                          _buildInfoTile(context, 'Account Status', user.isActive ? 'Active' : 'Disabled', Icons.verified_user_outlined),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // 3. Session & Security Information Card
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
                          _buildInfoTile(context, 'Authenticated Role', isAdvisor ? 'CLASS ADVISOR' : 'FACULTY', Icons.security_rounded),
                          Divider(height: 1, indent: 56, color: colors.glassBorder),
                          _buildInfoTile(
                            context,
                            'Advisory Authority',
                            isAdvisor ? 'Full Class Attendance & Timetable Access' : 'Standard Subject Attendance Access',
                            Icons.admin_panel_settings_outlined,
                          ),
                          Divider(height: 1, indent: 56, color: colors.glassBorder),
                          _buildInfoTile(context, 'Session Security', 'Active Session (JWT Token Verified)', Icons.lock_clock_outlined),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // 4. Appearance & Theme Switcher Card (Identical to Student Portal)
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
                                            Flexible(
                                              child: Text(
                                                'Warm Light',
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: !isDark ? colors.onPrimary : colors.textSecondary,
                                                ),
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
                                            Flexible(
                                              child: Text(
                                                'Obsidian Dark',
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: isDark ? colors.onPrimary : colors.textSecondary,
                                                ),
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

                    // 5. Account Actions Card
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
                            onPressed: () => FacultyEditProfileSheet.show(context: context, user: user),
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
                            label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
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
