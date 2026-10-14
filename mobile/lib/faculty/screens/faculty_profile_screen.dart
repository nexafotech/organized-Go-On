import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/api_config.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/theme_service.dart';
import '../../widgets/widgets.dart';
import '../../services/auth_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/widgets/change_password_dialog.dart';

class FacultyProfileScreen extends StatelessWidget {
  const FacultyProfileScreen({Key? key}) : super(key: key);

  void _confirmLogout(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: colors.error, size: 24),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Confirm Sign Out',
              style: typography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out of your faculty account?',
          style: typography.bodyMedium.copyWith(color: colors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: colors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
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
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
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
          child: GlassCard(
            variant: GlassCardVariant.standard,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_off_outlined, size: 56, color: colors.textMuted),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Faculty details unavailable',
                  style: typography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Please sign in to view your profile details.',
                  textAlign: TextAlign.center,
                  style: typography.bodySmall.copyWith(color: colors.textMuted),
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
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Faculty Profile Header Card
          GlassCard(
            variant: GlassCardVariant.hero,
            padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: colors.heroChip,
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'F',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: colors.onHero,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  user.fullName.isNotEmpty ? user.fullName : user.username,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colors.onHero,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Identifier: ${user.username}',
                  style: TextStyle(color: colors.onHeroSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: AppSpacing.sm),
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
                      const SizedBox(width: 4),
                      Text(
                        user.isActive ? 'Active Faculty Member' : 'Account Disabled',
                        style: TextStyle(
                          color: user.isActive ? colors.present : colors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Faculty Account Details
          GlassCard(
            variant: GlassCardVariant.standard,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  child: Text(
                    'Account Details',
                    style: typography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                ),
                Divider(height: 1, color: colors.glassBorder),
                _buildInfoTile(context, 'Full Name', user.fullName.isNotEmpty ? user.fullName : user.username, Icons.badge_outlined),
                Divider(height: 1, indent: 56, color: colors.glassBorder),
                _buildInfoTile(context, 'Username / Employee ID', user.username, Icons.person_pin_outlined),
                Divider(height: 1, indent: 56, color: colors.glassBorder),
                _buildInfoTile(context, 'Email Address', user.email.isNotEmpty ? user.email : 'Not specified', Icons.email_outlined),
                Divider(height: 1, indent: 56, color: colors.glassBorder),
                _buildInfoTile(context, 'Role Designation', user.role, Icons.work_outline_rounded),
                Divider(height: 1, indent: 56, color: colors.glassBorder),
                _buildInfoTile(context, 'Account Status', user.isActive ? 'Active' : 'Disabled', Icons.verified_user_outlined),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Session Information Card
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
                    style: typography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                ),
                Divider(height: 1, color: colors.glassBorder),
                _buildInfoTile(context, 'Authenticated Role', user.role, Icons.security_rounded),
                Divider(height: 1, indent: 56, color: colors.glassBorder),
                _buildInfoTile(context, 'Backend Server', ApiConfig.baseUrl, Icons.dns_outlined),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Appearance / Theme Preferences Card
          GlassCard(
            variant: GlassCardVariant.standard,
            padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Appearance & Theme',
                  style: typography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Toggle between warm cream and obsidian liquid glass styles across the application.',
                  style: typography.bodySmall.copyWith(color: colors.textSecondary),
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
                                    'Obsidian Dark',
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

          // Security Actions
          GlassCard(
            variant: GlassCardVariant.standard,
            padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Account Actions',
                  style: typography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.onPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                  ),
                  icon: const Icon(Icons.key_rounded, size: 20),
                  label: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => ChangePasswordDialog.show(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.error,
                    side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                  ),
                  icon: Icon(Icons.logout_rounded, size: 20, color: colors.error),
                  label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _confirmLogout(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String label, String value, IconData icon) {
    final colors = context.colors;
    final typography = context.typography;

    return Material(
      type: MaterialType.transparency,
      child: ListTile(
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
          style: typography.caption.copyWith(color: colors.textMuted, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          value,
          style: typography.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: colors.textPrimary),
        ),
      ),
    );
  }
}
