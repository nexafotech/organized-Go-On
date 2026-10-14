import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/widgets.dart';
import '../screens/login_screen.dart';

class ChangePasswordDialog extends StatefulWidget {
  final bool isMandatory;

  const ChangePasswordDialog({Key? key, this.isMandatory = false}) : super(key: key);

  static Future<void> show(BuildContext context, {bool isMandatory = false}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (ctx) => PopScope(
        canPop: !isMandatory,
        child: ChangePasswordDialog(isMandatory: isMandatory),
      ),
    );
  }

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  bool _isSubmitting = false;
  String? _dialogError;
  String? _dialogSuccess;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _dialogError = null;
      _dialogSuccess = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      await authService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _dialogSuccess = 'Password changed successfully!';
      });

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('Password updated successfully.'),
            ],
          ),
          backgroundColor: context.colors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _dialogError = authService.errorMessage ?? 'Failed to update password. Please try again.';
      });
    }
  }

  Future<void> _handleSignOut() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: GlassCard(
          variant: GlassCardVariant.elevated,
          borderRadius: AppRadius.dialogBorder,
          borderColor: colors.glassBorderStrong,
          borderWidth: 1.2,
          padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.isMandatory
                              ? colors.warningBg
                              : colors.heroChip,
                          borderRadius: AppRadius.smallBorder,
                          border: Border.all(
                            color: widget.isMandatory
                                ? colors.warning.withValues(alpha: 0.4)
                                : colors.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          widget.isMandatory ? Icons.warning_amber_rounded : Icons.lock_reset_rounded,
                          color: widget.isMandatory ? colors.warning : colors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.isMandatory ? 'Mandatory Password Update' : 'Change Password',
                          style: typography.titleMedium.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      if (!widget.isMandatory && !_isSubmitting)
                        IconButton(
                          icon: Icon(Icons.close, color: colors.textSecondary),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Close',
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.isMandatory
                        ? 'Administration requires you to set a secure permanent password (minimum 8 characters) to proceed.'
                        : 'Enter your current password and choose a secure new password (minimum 8 characters).',
                    style: typography.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  if (_dialogError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.errorBg,
                        borderRadius: AppRadius.smallBorder,
                        border: Border.all(color: colors.error.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline, color: colors.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _dialogError!,
                              style: TextStyle(
                                color: colors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  if (_dialogSuccess != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.successBg,
                        borderRadius: AppRadius.smallBorder,
                        border: Border.all(color: colors.success.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: colors.success, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _dialogSuccess!,
                              style: TextStyle(
                                color: colors.success,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Current Password
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: !_showCurrentPassword,
                    enabled: !_isSubmitting,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      filled: true,
                      fillColor: colors.surfaceMuted.withValues(alpha: 0.5),
                      border: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.accent, width: 1.8)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showCurrentPassword ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _showCurrentPassword = !_showCurrentPassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Enter current password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // New Password
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: !_showNewPassword,
                    enabled: !_isSubmitting,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      hintText: 'Minimum 8 characters',
                      prefixIcon: const Icon(Icons.key_outlined, size: 20),
                      filled: true,
                      fillColor: colors.surfaceMuted.withValues(alpha: 0.5),
                      border: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.accent, width: 1.8)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showNewPassword ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _showNewPassword = !_showNewPassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Enter new password';
                      }
                      if (v.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      if (v == _currentPasswordController.text && _currentPasswordController.text.isNotEmpty) {
                        return 'New password cannot be same as current password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Confirm New Password
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_showConfirmPassword,
                    enabled: !_isSubmitting,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: const Icon(Icons.check_outlined, size: 20),
                      filled: true,
                      fillColor: colors.surfaceMuted.withValues(alpha: 0.5),
                      border: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.accent, width: 1.8)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Confirm your new password';
                      }
                      if (v != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Action Buttons
                  Row(
                    children: [
                      if (widget.isMandatory) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.error,
                              side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                            ),
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _isSubmitting ? null : _handleSignOut,
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.textSecondary,
                              side: BorderSide(color: colors.border),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                            ),
                            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                          ),
                          onPressed: _isSubmitting ? null : _handleSubmit,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
