import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/student_model.dart';
import '../../services/student_service.dart';
import '../avatar/user_avatar_widget.dart';
import '../avatar/avatar_picker_sheet.dart';
import '../common/app_buttons.dart';

/// EditProfileSheet — Comprehensive bottom sheet / dialog allowing students to edit
/// their personal information (Full Name, Email Address, Contact Phone Number) and Avatar,
/// while displaying verified institution records (Register Number, Department, Class, Semester) as read-only.
class EditProfileSheet extends StatefulWidget {
  final StudentSummaryModel summary;
  final StudentService studentService;

  const EditProfileSheet({
    Key? key,
    required this.summary,
    required this.studentService,
  }) : super(key: key);

  static Future<void> show({
    required BuildContext context,
    required StudentSummaryModel summary,
    required StudentService studentService,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    if (isDesktop) {
      return showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: EditProfileSheet(
            summary: summary,
            studentService: studentService,
          ),
        ),
      );
    }
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditProfileSheet(
        summary: summary,
        studentService: studentService,
      ),
    );
  }

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  late String _currentAvatarId;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.summary.fullName);
    _emailController = TextEditingController(text: widget.summary.email ?? '');
    _phoneController = TextEditingController(text: widget.summary.phone ?? '');
    _currentAvatarId = widget.summary.avatarId ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleChooseAvatar() async {
    final chosen = await AvatarPickerSheet.selectAvatar(
      context: context,
      currentAvatarId: _currentAvatarId,
      userSeed: widget.summary.registerNumber,
    );
    if (chosen != null && mounted) {
      setState(() {
        _currentAvatarId = chosen;
      });
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final newName = _nameController.text.trim();
    final newEmail = _emailController.text.trim();
    final newPhone = _phoneController.text.trim();

    try {
      final success = await widget.studentService.updateProfileDetails(
        fullName: newName.isNotEmpty ? newName : null,
        email: newEmail,
        phone: newPhone,
        avatarId: _currentAvatarId.isNotEmpty ? _currentAvatarId : null,
      );

      if (!mounted) return;

      if (success) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Profile details updated successfully!',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0B7A55),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to save profile changes. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = e is ApiException ? e.message : 'Failed to update profile. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.90;

    final avatarItem = AvatarItemModel.findById(_currentAvatarId);

    return Container(
      constraints: BoxConstraints(
        maxWidth: 640,
        maxHeight: maxHeight,
      ),
      margin: isDesktop ? EdgeInsets.zero : EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: colors.isDark ? const Color(0xFF161922) : const Color(0xFFFBFBFA),
        borderRadius: isDesktop
            ? BorderRadius.circular(28)
            : const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: colors.glassBorderStrong,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.isDark ? Colors.black.withValues(alpha: 0.35) : const Color(0x242B1A13),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Drag Handle (mobile only)
          if (!isDesktop)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textMuted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          // 2. Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.manage_accounts_rounded, color: colors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Profile Details',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Update personal information & avatar',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: colors.textSecondary, size: 22),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.8),

          // 3. Scrollable Form Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Avatar Selection Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.glassSurfaceStrong,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.25),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _handleChooseAvatar,
                            child: Stack(
                              children: [
                                UserAvatarWidget(
                                  avatarId: _currentAvatarId,
                                  fallbackSeed: widget.summary.registerNumber,
                                  radius: 36,
                                  showEditBadge: false,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: colors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: colors.surface, width: 2),
                                    ),
                                    child: Icon(
                                      Icons.palette_rounded,
                                      color: colors.onPrimary,
                                      size: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  avatarItem.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Tap avatar or button to change style',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: colors.primary,
                                    side: BorderSide(color: colors.primary.withValues(alpha: 0.45)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: _handleChooseAvatar,
                                  icon: const Icon(Icons.palette_outlined, size: 14),
                                  label: const Text('Change Avatar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Section: Editable Personal Information
                    Row(
                      children: [
                        Icon(Icons.person_rounded, size: 18, color: colors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Personal Details',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: colors.primary,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Full Name Field
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'Enter your full name',
                      icon: Icons.badge_outlined,
                      colors: colors,
                      typography: typography,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Full name cannot be empty';
                        }
                        if (val.trim().length < 2) {
                          return 'Full name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Email Field
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      hint: 'student@college.edu',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      colors: colors,
                      typography: typography,
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          final email = val.trim();
                          final emailRegExp = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
                          if (!emailRegExp.hasMatch(email)) {
                            return 'Please enter a valid email address';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Contact Phone Field
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Contact Phone Number',
                      hint: '+91 98765 43210',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      colors: colors,
                      typography: typography,
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          final clean = val.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
                          if (clean.length < 7 || clean.length > 15) {
                            return 'Please enter a valid contact number';
                          }
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Section: Read-Only University Records
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: colors.border.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lock_outline_rounded, size: 16, color: colors.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Institutional Records (Locked)',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: colors.border),
                                ),
                                child: Text(
                                  'Admin Only',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildReadOnlyRow(
                            label: 'Register Number',
                            value: widget.summary.registerNumber,
                            icon: Icons.pin_outlined,
                            colors: colors,
                          ),
                          const SizedBox(height: 6),
                          _buildReadOnlyRow(
                            label: 'Class & Section',
                            value: widget.summary.className ?? 'Not assigned',
                            icon: Icons.school_outlined,
                            colors: colors,
                          ),
                          const SizedBox(height: 6),
                          _buildReadOnlyRow(
                            label: 'Department',
                            value: widget.summary.department ?? 'N/A',
                            icon: Icons.business_outlined,
                            colors: colors,
                          ),
                          const SizedBox(height: 6),
                          _buildReadOnlyRow(
                            label: 'Academic Semester',
                            value: widget.summary.semester != null
                                ? (widget.summary.semester!.toLowerCase().contains('semester')
                                    ? widget.summary.semester!
                                    : 'Semester ${widget.summary.semester}')
                                : 'Semester 1',
                            icon: Icons.calendar_today_outlined,
                            colors: colors,
                          ),
                        ],
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: colors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.error.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded, color: colors.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: colors.error,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Actions: Cancel & Save Changes
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.textPrimary,
                              side: BorderSide(color: colors.border),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: PrimaryButton(
                            text: 'Save Changes',
                            icon: Icons.check_rounded,
                            isLoading: _isSaving,
                            onPressed: _handleSave,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required AppColors colors,
    required AppTypography typography,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: typography.bodyMedium.copyWith(color: colors.textPrimary),
          validator: validator,
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.surfaceMuted,
            hintText: hint,
            hintStyle: typography.bodyMedium.copyWith(color: colors.textMuted),
            prefixIcon: Icon(icon, size: 20, color: colors.textSecondary),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.primary, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.error, width: 1.4),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.error, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyRow({
    required String label,
    required String value,
    required IconData icon,
    required AppColors colors,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: colors.textMuted),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
