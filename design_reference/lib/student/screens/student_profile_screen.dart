import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/theme_service.dart';
import '../../models/student_model.dart';
import '../../services/auth_service.dart';
import '../../services/student_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/widgets/change_password_dialog.dart';
import 'biometric_enrollment_screen.dart';

enum ProfileViewMode {
  referenceDesign, // Exact match to Image 1 (Anna K., 04, Connect Card, 23/07)
  studentProfile,  // Student's Academic Profile in Image 1 Editorial Style
}

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({Key? key}) : super(key: key);

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  ProfileViewMode _viewMode = ProfileViewMode.referenceDesign;

  // Customizable Profile State
  String? _customName;
  String? _customRegion = 'India, IN';
  String? _customAbout;
  List<String>? _customInterests;
  String? _customDepartment;
  String? _customRegNo;
  String? _customBrandText = 'NGI';
  int _attendanceGraphTab = 2; // 0: DAILY, 1: WEEKLY, 2: TERM

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
    final studentService = Provider.of<StudentService>(context);
    final summary = studentService.summary;

    final isRef = _viewMode == ProfileViewMode.referenceDesign;
    final displayName = _customName ?? (isRef ? 'Anna K.' : (summary?.fullName ?? 'Aarav Sharma'));
    final roleTitle = 'REGION';
    final locationText = _customRegion ?? 'India, IN';
    final bioText = _customAbout ?? (isRef
        ? 'Product designer focused on minimal systems, thoughtful details, and human-centred design.'
        : 'Undergraduate scholar in Information Technology specializing in distributed architectures, minimal systems, thoughtful details, and human-centred design.');
    final interests = _customInterests ?? (isRef
        ? ['Architecture', 'Typography', 'Photography', 'Design']
        : ['Algorithms', 'Networks', 'Cloud Systems', 'AI / ML', 'Design']);
    final stat1Label = isRef ? 'CONNECTIONS' : 'ATTENDANCE';
    final stat1Val = isRef ? '23' : '${summary?.percentage.toStringAsFixed(1) ?? "88.8"}%';
    final stat2Label = isRef ? 'MOMENTS' : 'COURSES';
    final stat2Val = isRef ? '07' : '07';

    final isDark = colors.isDark;
    final primaryTextColor = isDark ? colors.textPrimary : const Color(0xFF1F1D1A);
    final secondaryTextColor = isDark ? colors.textSecondary : const Color(0xFF2E2A27);
    final mutedTextColor = isDark ? colors.textMuted : const Color(0xFF7A7269);
    final borderColor = isDark ? colors.divider : const Color(0xFFDDD5CA);
    final pillBg = isDark ? colors.surfaceElevated : const Color(0xFFE5DFD5);

    return Scaffold(
      backgroundColor: isDark ? colors.background : const Color(0xFFF4F0EB), // Exact warm linen oat or deep obsidian
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─────────────────────────────────────────────────────────────
              // 1. TOP BAR: PROFILE / 01 + MODE TOGGLE
              // ─────────────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'PROFILE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: mutedTextColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Preset toggle pill
                      InkWell(
                        onTap: () {
                          setState(() {
                            _viewMode = _viewMode == ProfileViewMode.referenceDesign
                                ? ProfileViewMode.studentProfile
                                : ProfileViewMode.referenceDesign;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: pillBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isRef ? Icons.photo_camera_front_outlined : Icons.school_outlined,
                                size: 13,
                                color: secondaryTextColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isRef ? 'Show Academic Profile' : 'Show Image 1 Ref',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '01',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: mutedTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Hairline rule under header
              Container(
                height: 1,
                color: borderColor,
              ),
              const SizedBox(height: 24),

              // ─────────────────────────────────────────────────────────────
              // 2. HERO IDENTITY SECTION (PHOTO + 04 + NAME)
              // ─────────────────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Portrait Photo Frame
                  _buildPortraitPhoto(isRef, colors),
                  const SizedBox(width: 24),

                  // Right: NGI Modular Geometric Typography + Active Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        NgiModularBrandWidget(
                          text: _customBrandText ?? 'NGI',
                          colors: colors,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ACTIVE NOW',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 13,
                              color: secondaryTextColor,
                            ),
                            children: [
                              const TextSpan(text: 'Visible in '),
                              TextSpan(
                                text: isRef ? '350' : '350',
                                style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor),
                              ),
                              const TextSpan(text: ' m'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Name in large bold sans
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle: REGION
              Text(
                roleTitle,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: mutedTextColor,
                ),
              ),
              const SizedBox(height: 6),

              // Location / Region with Arrow
              InkWell(
                onTap: () => _showEditProfileSheet(context, summary),
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      locationText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_outward_rounded, size: 14, color: secondaryTextColor),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Hairline rule
              Container(height: 1, color: borderColor),
              const SizedBox(height: 22),

              // ─────────────────────────────────────────────────────────────
              // 3. ABOUT SECTION
              // ─────────────────────────────────────────────────────────────
              Text(
                'ABOUT',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: mutedTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                bioText,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 22),

              // ─────────────────────────────────────────────────────────────
              // 4. INTERESTS SECTION
              // ─────────────────────────────────────────────────────────────
              Text(
                'INTERESTS',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: mutedTextColor,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 24,
                runSpacing: 10,
                children: interests.map((tag) {
                  return Text(
                    tag,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: secondaryTextColor,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 26),

              // ─────────────────────────────────────────────────────────────
              // 5. ATTENDANCE ANALYTICS GRAPH CARD (IMAGE 2 REPLICA)
              // ─────────────────────────────────────────────────────────────
              _buildAttendanceGraphCard(context, summary, colors),
              const SizedBox(height: 26),

              // ─────────────────────────────────────────────────────────────
              // 6. BOTTOM STATS: CONNECTIONS 23 / MOMENTS 07
              // ─────────────────────────────────────────────────────────────
              Container(height: 1, color: borderColor),
              const SizedBox(height: 16),
              Row(
                children: [
                  // Left Stat: CONNECTIONS 23
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stat1Label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: mutedTextColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              stat1Val,
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w400,
                                letterSpacing: -0.5,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_outward_rounded, size: 16, color: primaryTextColor),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Center hairline vertical divider
                  Container(
                    width: 1,
                    height: 54,
                    color: borderColor,
                  ),
                  const SizedBox(width: 24),

                  // Right Stat: MOMENTS 07
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stat2Label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: mutedTextColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              stat2Val,
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w400,
                                letterSpacing: -0.5,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_outward_rounded, size: 16, color: primaryTextColor),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: borderColor),
              const SizedBox(height: 28),

              // ─────────────────────────────────────────────────────────────
              // 7. ACADEMIC CREDENTIALS TABLE (EDITORIAL MINIMALIST)
              // ─────────────────────────────────────────────────────────────
              Text(
                'INSTITUTIONAL RECORD',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: mutedTextColor,
                ),
              ),
              const SizedBox(height: 14),
              _buildCredentialRow('REGISTER NUMBER', _customRegNo ?? (summary?.registerNumber ?? '7376222IT101'), colors),
              _buildCredentialRow('COLLEGE EMAIL', summary?.email ?? 'aarav.sharma@college.edu', colors),
              _buildCredentialRow('CLASS SECTION', summary?.className ?? 'B.Tech IT - Year III (Section B)', colors),
              _buildCredentialRow('DEPARTMENT', _customDepartment ?? (summary?.department ?? 'Information Technology'), colors),
              _buildCredentialRow('ACADEMIC SEMESTER', summary?.semester ?? '5', colors),
              _buildCredentialRow('SESSION ROLE', 'STUDENT', colors),
              _buildCredentialRow('REGION', locationText, colors),
              Consumer<ThemeService>(
                builder: (context, themeService, _) {
                  return _buildInteractiveThemeRow(
                    label: 'APP THEME',
                    isDark: themeService.isDarkMode,
                    onToggle: () => themeService.toggleTheme(),
                    colors: colors,
                  );
                },
              ),
              const SizedBox(height: 28),

              // ─────────────────────────────────────────────────────────────
              // 8. APPEARANCE & THEME SWITCHER
              // ─────────────────────────────────────────────────────────────
              Text(
                'APPEARANCE & THEME',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: mutedTextColor,
                ),
              ),
              const SizedBox(height: 14),
              Consumer<ThemeService>(
                builder: (context, themeService, _) {
                  final isDarkTheme = themeService.isDarkMode;
                  return Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? colors.surfaceElevated : const Color(0xFFEFE9E0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => themeService.setThemeMode(ThemeMode.light),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                color: !isDarkTheme
                                    ? (isDark ? colors.primary : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: !isDarkTheme
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.light_mode_rounded,
                                    size: 16,
                                    color: !isDarkTheme
                                        ? const Color(0xFFD97706)
                                        : mutedTextColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Warm Light',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: !isDarkTheme
                                          ? const Color(0xFF221F1D)
                                          : mutedTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: InkWell(
                            onTap: () => themeService.setThemeMode(ThemeMode.dark),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                color: isDarkTheme
                                    ? colors.surfaceElevated
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: isDarkTheme
                                    ? Border.all(color: colors.accent.withValues(alpha: 0.45), width: 1.2)
                                    : null,
                                boxShadow: isDarkTheme
                                    ? [
                                        BoxShadow(
                                          color: colors.accent.withValues(alpha: 0.20),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.dark_mode_rounded,
                                    size: 16,
                                    color: isDarkTheme
                                        ? colors.accent
                                        : mutedTextColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Obsidian Dark',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: isDarkTheme
                                          ? colors.textPrimary
                                          : mutedTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),

              // ─────────────────────────────────────────────────────────────
              // 9. SECURITY & ACCOUNT ACTIONS
              // ─────────────────────────────────────────────────────────────
              Text(
                'ACCOUNT ACTIONS',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: mutedTextColor,
                ),
              ),
              const SizedBox(height: 14),

              // Biometric Face Enrollment (Primary Espresso / Pearl Pill)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? colors.primary : const Color(0xFF221F1D),
                    foregroundColor: isDark ? colors.onPrimary : Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BiometricEnrollmentScreen()),
                    );
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.face_retouching_natural_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Biometric Face Enrollment',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Edit Profile Details (Secondary Action Pill)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isDark ? colors.surfaceElevated : Colors.white.withValues(alpha: 0.8),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: borderColor),
                  ),
                  onPressed: () => _showEditProfileSheet(context, summary),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_note_rounded, size: 20, color: secondaryTextColor),
                      const SizedBox(width: 8),
                      Text(
                        'Edit Profile Details',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Change Password (Minimal Outlined Pill)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isDark ? colors.surfaceElevated : Colors.white.withValues(alpha: 0.6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: borderColor),
                  ),
                  onPressed: () => ChangePasswordDialog.show(context),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.key_rounded, size: 18, color: secondaryTextColor),
                      const SizedBox(width: 8),
                      Text(
                        'Change Password',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Sign Out (Muted Terracotta Danger Button)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? colors.error.withValues(alpha: 0.12) : const Color(0xFFBA5A31).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? colors.error.withValues(alpha: 0.35) : const Color(0xFFBA5A31).withValues(alpha: 0.35),
                    width: 1.1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _confirmLogout(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, size: 18, color: isDark ? colors.error : const Color(0xFFBA5A31)),
                          const SizedBox(width: 8),
                          Text(
                            'Sign Out',
                            style: TextStyle(
                              color: isDark ? colors.error : const Color(0xFFBA5A31),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EDIT PROFILE MODAL BOTTOM SHEET
  // ─────────────────────────────────────────────────────────────────────────
  void _showEditProfileSheet(BuildContext context, StudentSummaryModel? summary) {
    final colors = context.colors;
    final isDark = colors.isDark;
    final isRef = _viewMode == ProfileViewMode.referenceDesign;

    final currentName = _customName ?? (isRef ? 'Anna K.' : (summary?.fullName ?? 'Aarav Sharma'));
    final currentRegion = _customRegion ?? 'India, IN';
    final currentAbout = _customAbout ?? (isRef
        ? 'Product designer focused on minimal systems, thoughtful details, and human-centred design.'
        : 'Undergraduate scholar in Information Technology specializing in distributed architectures, minimal systems, thoughtful details, and human-centred design.');
    final currentInterests = (_customInterests ?? (isRef
        ? ['Architecture', 'Typography', 'Photography', 'Design']
        : ['Algorithms', 'Networks', 'Cloud Systems', 'AI / ML', 'Design'])).join(', ');
    final currentDept = _customDepartment ?? (summary?.department ?? 'Information Technology');
    final currentRegNo = _customRegNo ?? (summary?.registerNumber ?? '7376222IT101');

    final nameController = TextEditingController(text: currentName);
    final regionController = TextEditingController(text: currentRegion);
    final brandController = TextEditingController(text: _customBrandText ?? 'NGI');
    final aboutController = TextEditingController(text: currentAbout);
    final interestsController = TextEditingController(text: currentInterests);
    final deptController = TextEditingController(text: currentDept);
    final regNoController = TextEditingController(text: currentRegNo);

    final regionPresets = ['India, IN', 'Tamil Nadu, IN', 'Delhi, IN', 'Bengaluru, IN', 'Mumbai, IN', 'Kerala, IN', 'Hyderabad, IN'];
    final brandPresets = ['NGI', 'LABS', 'IIT', 'NIT'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? colors.surfaceElevated : const Color(0xFFF5F1EB),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: isDark ? colors.glassBorderStrong : const Color(0xFFDDD5CA),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 28,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? colors.textMuted : const Color(0xFFB0A89E),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EDIT PROFILE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: isDark ? colors.textSecondary : const Color(0xFF7A7269),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Update identity & region details',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? colors.textMuted : const Color(0xFF5A5249),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Field 1: Full Name
                    _buildEditLabel('FULL NAME', isDark, colors),
                    const SizedBox(height: 6),
                    _buildEditTextField(nameController, 'Enter full name', isDark, colors, Icons.person_outline_rounded),
                    const SizedBox(height: 16),

                    // Field 2: Region
                    _buildEditLabel('REGION', isDark, colors),
                    const SizedBox(height: 6),
                    _buildEditTextField(regionController, 'e.g. India, IN', isDark, colors, Icons.location_on_outlined),
                    const SizedBox(height: 8),

                    // Quick region preset chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: regionPresets.map((preset) {
                        final isSelected = regionController.text.trim() == preset;
                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              regionController.text = preset;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? colors.accent.withValues(alpha: 0.25) : const Color(0xFF221F1D))
                                  : (isDark ? colors.surface : const Color(0xFFE5DFD5)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? (isDark ? colors.accent : const Color(0xFF221F1D))
                                    : (isDark ? colors.divider : const Color(0xFFCDC6BC)),
                              ),
                            ),
                            child: Text(
                              preset,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? (isDark ? colors.accent : Colors.white)
                                    : (isDark ? colors.textSecondary : const Color(0xFF4A443E)),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Field 3: Modular Brand Monogram (NGI)
                    _buildEditLabel('MODULAR BRAND MONOGRAM', isDark, colors),
                    const SizedBox(height: 6),
                    _buildEditTextField(brandController, 'e.g. NGI', isDark, colors, Icons.token_outlined),
                    const SizedBox(height: 8),

                    // Quick brand preset chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: brandPresets.map((preset) {
                        final isSelected = brandController.text.trim().toUpperCase() == preset;
                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              brandController.text = preset;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? colors.accent.withValues(alpha: 0.25) : const Color(0xFF221F1D))
                                  : (isDark ? colors.surface : const Color(0xFFE5DFD5)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? (isDark ? colors.accent : const Color(0xFF221F1D))
                                    : (isDark ? colors.divider : const Color(0xFFCDC6BC)),
                              ),
                            ),
                            child: Text(
                              preset,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? (isDark ? colors.accent : Colors.white)
                                    : (isDark ? colors.textSecondary : const Color(0xFF4A443E)),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Field 4: Department / Specialization
                    _buildEditLabel('DEPARTMENT / SPECIALIZATION', isDark, colors),
                    const SizedBox(height: 6),
                    _buildEditTextField(deptController, 'e.g. Information Technology', isDark, colors, Icons.school_outlined),
                    const SizedBox(height: 16),

                    // Field 4: Register Number
                    _buildEditLabel('REGISTER NUMBER', isDark, colors),
                    const SizedBox(height: 6),
                    _buildEditTextField(regNoController, 'e.g. 7376222IT101', isDark, colors, Icons.badge_outlined),
                    const SizedBox(height: 16),

                    // Field 5: About / Bio
                    _buildEditLabel('ABOUT / BIO', isDark, colors),
                    const SizedBox(height: 6),
                    _buildEditTextField(aboutController, 'Write a short bio...', isDark, colors, Icons.notes_rounded, maxLines: 3),
                    const SizedBox(height: 16),

                    // Field 6: Interests
                    _buildEditLabel('INTERESTS (COMMA SEPARATED)', isDark, colors),
                    const SizedBox(height: 6),
                    _buildEditTextField(interestsController, 'e.g. AI / ML, Cloud Systems, Design', isDark, colors, Icons.tag_rounded),
                    const SizedBox(height: 24),

                    // Actions Row
                    Row(
                      children: [
                        // Reset button
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              side: BorderSide(color: isDark ? colors.divider : const Color(0xFFCDC6BC)),
                            ),
                            onPressed: () {
                              setState(() {
                                _customName = null;
                                _customRegion = 'India, IN';
                                _customBrandText = 'NGI';
                                _customAbout = null;
                                _customInterests = null;
                                _customDepartment = null;
                                _customRegNo = null;
                              });
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Profile details reset to defaults'),
                                  backgroundColor: isDark ? colors.surfaceElevated : const Color(0xFF221F1D),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                            child: Text(
                              'Reset',
                              style: TextStyle(
                                color: isDark ? colors.textSecondary : const Color(0xFF4A443E),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Save button
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? colors.primary : const Color(0xFF221F1D),
                              foregroundColor: isDark ? colors.onPrimary : Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () {
                              final newName = nameController.text.trim();
                              final newRegion = regionController.text.trim();
                              final newBrand = brandController.text.trim();
                              final newAbout = aboutController.text.trim();
                              final newDept = deptController.text.trim();
                              final newRegNo = regNoController.text.trim();
                              final rawInterests = interestsController.text.trim();
                              final parsedInterests = rawInterests.isNotEmpty
                                  ? rawInterests.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
                                  : null;

                              setState(() {
                                if (newName.isNotEmpty) _customName = newName;
                                if (newRegion.isNotEmpty) _customRegion = newRegion;
                                if (newBrand.isNotEmpty) _customBrandText = newBrand.toUpperCase();
                                if (newAbout.isNotEmpty) _customAbout = newAbout;
                                if (newDept.isNotEmpty) _customDepartment = newDept;
                                if (newRegNo.isNotEmpty) _customRegNo = newRegNo;
                                if (parsedInterests != null && parsedInterests.isNotEmpty) {
                                  _customInterests = parsedInterests;
                                }
                              });

                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 18),
                                      SizedBox(width: 10),
                                      Text('Profile details updated successfully!'),
                                    ],
                                  ),
                                  backgroundColor: isDark ? colors.surfaceElevated : const Color(0xFF221F1D),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_rounded, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Save Details',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
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
            );
          },
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      regionController.dispose();
      brandController.dispose();
      aboutController.dispose();
      interestsController.dispose();
      deptController.dispose();
      regNoController.dispose();
    });
  }

  Widget _buildEditLabel(String text, bool isDark, AppColors colors) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: isDark ? colors.textMuted : const Color(0xFF7A7269),
      ),
    );
  }

  Widget _buildEditTextField(
    TextEditingController controller,
    String hint,
    bool isDark,
    AppColors colors,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? colors.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? colors.glassBorderStrong : const Color(0xFFDDD5CA)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? colors.textPrimary : const Color(0xFF1F1D1A),
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          prefixIcon: maxLines == 1
              ? Icon(icon, size: 18, color: isDark ? colors.textMuted : const Color(0xFF8C8276))
              : Padding(
                  padding: const EdgeInsets.only(top: 12, left: 14, right: 8),
                  child: Icon(icon, size: 18, color: isDark ? colors.textMuted : const Color(0xFF8C8276)),
                ),
          prefixIconConstraints: maxLines == 1 ? const BoxConstraints(minWidth: 42) : const BoxConstraints(minWidth: 42, maxHeight: 42),
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 13,
            color: isDark ? colors.textMuted : const Color(0xFFA59E93),
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PORTRAIT PHOTO WIDGET (MONOCHROME EDITORIAL)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPortraitPhoto(bool isRef, AppColors colors) {
    final isDark = colors.isDark;
    return Container(
      width: 140,
      height: 175,
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceElevated : const Color(0xFFD6D0C5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? colors.glassBorderStrong : const Color(0xFFCDC6BC), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Elegant portrait background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? const [Color(0xFF2E2A3C), Color(0xFF1E1C27)]
                      : const [Color(0xFFE5DFD4), Color(0xFFB5ADA0)],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isRef ? Icons.person_rounded : Icons.face_rounded,
                      size: 64,
                      color: isDark ? colors.textPrimary : const Color(0xFF2E2A27).withValues(alpha: 0.8),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.accent.withValues(alpha: 0.2)
                            : const Color(0xFF2E2A27).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isRef ? 'EDITORIAL' : 'VERIFIED ID',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: isDark ? colors.accent : const Color(0xFF2E2A27),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ATTENDANCE DOT-MATRIX GRAPH CARD (EXACT REPLICA OF ATTACHED IMAGE 2)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAttendanceGraphCard(BuildContext context, StudentSummaryModel? summary, AppColors colors) {
    final isDark = colors.isDark;
    final primaryTextColor = isDark ? colors.textPrimary : const Color(0xFF1F1D1A);
    final mutedTextColor = isDark ? colors.textMuted : const Color(0xFF7A7269);
    final borderColor = isDark ? colors.glassBorderStrong : const Color(0xFFCDC6BC);
    final cardBg = isDark ? colors.surfaceElevated : const Color(0xFFEBE5DC);
    final dividerColor = isDark ? colors.divider : const Color(0xFFDDD5CA);

    // Dynamic metrics based on selected tab: DAILY (0), WEEKLY (1), TERM (2)
    final String metricTag;
    final String metricVal;
    final String leftLabel;
    final String rightLabel;
    final List<int> leftCols;
    final List<int> rightCols;

    switch (_attendanceGraphTab) {
      case 0:
        metricTag = 'DAILY ATTENDANCE';
        metricVal = '+94.0 %';
        leftLabel = 'YESTERDAY  85.7%';
        rightLabel = 'TODAY  100% (7/7)';
        leftCols = const [2, 3, 4, 5, 4, 3, 2, 3, 2, 3, 2, 1, 2, 2, 1, 2];
        rightCols = const [3, 4, 5, 10, 8, 7, 6, 5, 4, 4, 3, 2, 1, 2, 3, 4, 5, 3, 4, 3, 2, 1];
        break;
      case 1:
        metricTag = 'WEEKLY ATTENDANCE';
        metricVal = '+92.4 %';
        leftLabel = 'PREV WEEKS  83.8%';
        rightLabel = 'THIS WEEK  95.8%';
        leftCols = const [2, 3, 4, 6, 8, 5, 3, 2, 3, 4, 4, 3, 2, 1, 2, 3];
        rightCols = const [3, 4, 6, 12, 10, 9, 8, 7, 6, 6, 5, 4, 2, 3, 3, 6, 5, 4, 6, 5, 4, 3];
        break;
      case 2:
      default:
        metricTag = 'TERM ATTENDANCE';
        final currPct = summary?.percentage ?? 88.8;
        metricVal = '+${currPct.toStringAsFixed(1)} %';
        leftLabel = 'TERM 1  81.5%';
        rightLabel = 'TERM 2  ${currPct > 81.5 ? currPct.toStringAsFixed(1) : "89.4"}%';
        // Exact column distribution matching the uploaded Image 2 (June spike!)
        leftCols = const [1, 2, 4, 5, 7, 4, 2, 1, 3, 4, 3, 2, 1, 1, 2, 2];
        rightCols = const [4, 5, 6, 11, 9, 8, 7, 6, 5, 5, 4, 3, 1, 2, 2, 5, 4, 3, 5, 4, 3, 2];
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row: Metric + Timeframe Tabs ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Metric Label & Big Percentage
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metricTag,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: mutedTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metricVal,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.5,
                      color: primaryTextColor,
                      height: 1.15,
                    ),
                  ),
                ],
              ),

              // Right: DAILY / WEEKLY / TERM Interactive Filter Tabs
              Container(
                decoration: BoxDecoration(
                  color: isDark ? colors.background.withValues(alpha: 0.5) : const Color(0xFFDDD6CB).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: dividerColor.withValues(alpha: 0.6)),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildGraphTabItem('DAILY', 0, isDark, colors),
                    _buildGraphTabItem('WEEKLY', 1, isDark, colors),
                    _buildGraphTabItem('TERM', 2, isDark, colors),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Hairline separator under header
          Container(height: 1, color: dividerColor),
          const SizedBox(height: 16),

          // ── Dot Matrix Graphic Canvas ──
          LayoutBuilder(
            builder: (ctx, constraints) {
              final w = constraints.maxWidth;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 94,
                    width: w,
                    child: CustomPaint(
                      size: Size(w, 94),
                      painter: _AttendanceDotMatrixChartPainter(
                        leftColumns: leftCols,
                        rightColumns: rightCols,
                        leftColor: isDark ? const Color(0xFF5A5369) : const Color(0xFFBBB3A7),
                        rightColor: isDark ? const Color(0xFFF7F5F0) : const Color(0xFF221E1B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Baseline Labels Aligned with Dot Clusters ──
                  Row(
                    children: [
                      SizedBox(
                        width: w * 0.40,
                        child: Text(
                          leftLabel,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: mutedTextColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      SizedBox(width: w * 0.08),
                      Expanded(
                        child: Text(
                          rightLabel,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGraphTabItem(String label, int index, bool isDark, AppColors colors) {
    final isSelected = _attendanceGraphTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          _attendanceGraphTab = index;
        });
      },
      borderRadius: BorderRadius.circular(7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? colors.surfaceElevated : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: 1.0,
            color: isSelected
                ? (isDark ? colors.textPrimary : const Color(0xFF1F1D1A))
                : (isDark ? colors.textMuted : const Color(0xFF7A7269)),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CREDENTIAL ROW HELPER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCredentialRow(String label, String value, AppColors colors) {
    final isDark = colors.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? colors.divider : const Color(0xFFE2DBD0), width: 0.9)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: isDark ? colors.textMuted : const Color(0xFF7A7269),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? colors.textPrimary : const Color(0xFF1F1D1A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveThemeRow({
    required String label,
    required bool isDark,
    required VoidCallback onToggle,
    required AppColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.isDark ? colors.divider : const Color(0xFFE2DBD0),
            width: 0.9,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: colors.isDark ? colors.textMuted : const Color(0xFF7A7269),
            ),
          ),
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceElevated
                    : const Color(0xFFEBE4D8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? colors.accent.withValues(alpha: 0.5)
                      : const Color(0xFFD6CABE),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    size: 13,
                    color: isDark ? colors.accent : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isDark ? 'Obsidian Dark' : 'Warm Light',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? colors.textPrimary : const Color(0xFF221F1D),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.swap_horiz_rounded,
                    size: 14,
                    color: isDark ? colors.accent : const Color(0xFF7A7269),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DOT MATRIX WIDGET & PAINTER (IMAGE 1 REPLICA)
// ─────────────────────────────────────────────────────────────────────────────
class DotMatrixWidget extends StatelessWidget {
  final int rows;
  final int columns;
  final double dotSize;
  final double spacing;
  final Color color;

  const DotMatrixWidget({
    Key? key,
    this.rows = 13,
    this.columns = 14,
    this.dotSize = 3.2,
    this.spacing = 4.2,
    this.color = const Color(0xFF2E2A27),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: columns * (dotSize + spacing) - spacing,
      height: rows * (dotSize + spacing) - spacing,
      child: CustomPaint(
        painter: _DotMatrixPainter(
          rows: rows,
          columns: columns,
          dotSize: dotSize,
          spacing: spacing,
          color: color,
        ),
      ),
    );
  }
}

class _DotMatrixPainter extends CustomPainter {
  final int rows;
  final int columns;
  final double dotSize;
  final double spacing;
  final Color color;

  _DotMatrixPainter({
    required this.rows,
    required this.columns,
    required this.dotSize,
    required this.spacing,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final radius = dotSize / 2;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns; c++) {
        final cx = c * (dotSize + spacing) + radius;
        final cy = r * (dotSize + spacing) + radius;
        canvas.drawCircle(Offset(cx, cy), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotMatrixPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.rows != rows ||
        oldDelegate.columns != columns ||
        oldDelegate.dotSize != dotSize ||
        oldDelegate.spacing != spacing;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODULAR BRAND WIDGET & GLYPH PAINTER (EXACT REPLICA OF ATTACHED DESIGN)
// ─────────────────────────────────────────────────────────────────────────────
class NgiModularBrandWidget extends StatelessWidget {
  final String text;
  final AppColors colors;
  final double height;

  const NgiModularBrandWidget({
    Key? key,
    this.text = 'NGI',
    required this.colors,
    this.height = 68.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = colors.isDark;
    final chars = text.trim().toUpperCase().split('');
    final effectiveChars = chars.isEmpty ? ['N', 'G', 'I'] : chars;
    final cellCount = effectiveChars.length;
    final cellWidth = height * 0.88;
    final totalWidth = cellWidth * cellCount;

    final panelBg = isDark ? const Color(0xFF23202E) : const Color(0xFFE5E0D7);
    final borderColor = isDark ? const Color(0xFF3E394E) : const Color(0xFFCDC6BC);
    final dividerColor = isDark ? const Color(0xFF353043) : const Color(0xFFD8D2C7);
    final glyphColor = isDark ? const Color(0xFFF7F5F0) : const Color(0xFF1B1917);
    const orangeMarkerColor = Color(0xFFFF6D00); // Technical CAD Orange Registration Marks

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        width: totalWidth,
        height: height,
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: borderColor, width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Letter cells with dividers
            Row(
              children: List.generate(cellCount, (index) {
                final char = effectiveChars[index];
                return Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: index < cellCount - 1
                          ? Border(right: BorderSide(color: dividerColor, width: 1.0))
                          : null,
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: Size(cellWidth, height),
                        painter: _ModularGlyphPainter(
                          char: char,
                          color: glyphColor,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),

            // Corner Registration Marks (Signature CAD orange square marks from reference image)
            // Top-Left
            const Positioned(
              top: 3.5,
              left: 3.5,
              child: SizedBox(
                width: 3.5,
                height: 3.5,
                child: ColoredBox(color: orangeMarkerColor),
              ),
            ),
            // Bottom-Left
            const Positioned(
              bottom: 3.5,
              left: 3.5,
              child: SizedBox(
                width: 3.5,
                height: 3.5,
                child: ColoredBox(color: orangeMarkerColor),
              ),
            ),
            // Top-Right
            const Positioned(
              top: 3.5,
              right: 3.5,
              child: SizedBox(
                width: 3.5,
                height: 3.5,
                child: ColoredBox(color: orangeMarkerColor),
              ),
            ),
            // Bottom-Right
            const Positioned(
              bottom: 3.5,
              right: 3.5,
              child: SizedBox(
                width: 3.5,
                height: 3.5,
                child: ColoredBox(color: orangeMarkerColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModularGlyphPainter extends CustomPainter {
  final String char;
  final Color color;

  _ModularGlyphPainter({
    required this.char,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final padX = size.width * 0.16;
    final padY = size.height * 0.15;
    final rw = size.width - 2 * padX;
    final rh = size.height - 2 * padY;
    final stroke = rw * 0.28;
    final r = stroke * 0.65;
    final c = stroke * 0.75; // 45° chamfer cut size

    switch (char.toUpperCase()) {
      case 'N':
        _paintN(canvas, paint, padX, padY, rw, rh, stroke, r, c);
        break;
      case 'G':
        _paintG(canvas, paint, padX, padY, rw, rh, stroke, r, c);
        break;
      case 'I':
        _paintI(canvas, paint, padX, padY, rw, rh, stroke, r, c);
        break;
      case 'L':
        _paintL(canvas, paint, padX, padY, rw, rh, stroke, r, c);
        break;
      case 'A':
        _paintA(canvas, paint, padX, padY, rw, rh, stroke, r, c);
        break;
      case 'B':
        _paintB(canvas, paint, padX, padY, rw, rh, stroke, r, c);
        break;
      case 'S':
        _paintS(canvas, paint, padX, padY, rw, rh, stroke, r, c);
        break;
      default:
        _paintDefault(canvas, paint, padX, padY, rw, rh, stroke, r);
        break;
    }
  }

  void _paintN(Canvas canvas, Paint paint, double px, double py, double rw, double rh, double stroke, double r, double c) {
    // Left vertical stem: rounded top-left, chamfered bottom-left
    final leftStem = Path()
      ..moveTo(px, py + r)
      ..arcToPoint(Offset(px + r, py), radius: Radius.circular(r))
      ..lineTo(px + stroke, py)
      ..lineTo(px + stroke, py + rh)
      ..lineTo(px + c, py + rh)
      ..lineTo(px, py + rh - c)
      ..close();

    // Right vertical stem: chamfered top-right, rounded bottom-right
    final rightStem = Path()
      ..moveTo(px + rw - stroke, py)
      ..lineTo(px + rw - c, py)
      ..lineTo(px + rw, py + c)
      ..lineTo(px + rw, py + rh - r)
      ..arcToPoint(Offset(px + rw - r, py + rh), radius: Radius.circular(r))
      ..lineTo(px + rw - stroke, py + rh)
      ..close();

    // Diagonal band connecting top-left to bottom-right
    final diag = Path()
      ..moveTo(px + stroke, py)
      ..lineTo(px + stroke + stroke * 0.45, py)
      ..lineTo(px + rw, py + rh - stroke * 0.45)
      ..lineTo(px + rw, py + rh)
      ..lineTo(px + rw - stroke, py + rh)
      ..lineTo(px + rw - stroke - stroke * 0.45, py + rh)
      ..lineTo(px, py + stroke * 0.45)
      ..lineTo(px, py)
      ..close();

    final path1 = Path.combine(PathOperation.union, leftStem, rightStem);
    final fullN = Path.combine(PathOperation.union, path1, diag);
    canvas.drawPath(fullN, paint);
  }

  void _paintG(Canvas canvas, Paint paint, double px, double py, double rw, double rh, double stroke, double r, double c) {
    final path = Path()
      // Top right gap
      ..moveTo(px + rw, py + stroke)
      ..lineTo(px + rw - r * 0.5, py)
      ..lineTo(px + r, py)
      // Rounded top-left
      ..arcToPoint(Offset(px, py + r), radius: Radius.circular(r))
      ..lineTo(px, py + rh - r)
      // Rounded bottom-left
      ..arcToPoint(Offset(px + r, py + rh), radius: Radius.circular(r))
      ..lineTo(px + rw - c, py + rh)
      // Signature 45° chamfer cut at bottom-right (from LABS reference)
      ..lineTo(px + rw, py + rh - c)
      // Up right side to spur
      ..lineTo(px + rw, py + rh * 0.48)
      // Horizontal spur moving into center
      ..lineTo(px + rw * 0.48, py + rh * 0.48)
      ..lineTo(px + rw * 0.48, py + rh * 0.48 + stroke * 0.85)
      ..lineTo(px + rw - stroke, py + rh * 0.48 + stroke * 0.85)
      // Down to inner bottom
      ..lineTo(px + rw - stroke, py + rh - stroke)
      ..lineTo(px + stroke + r * 0.5, py + rh - stroke)
      // Inner bottom-left rounded fillet
      ..arcToPoint(Offset(px + stroke, py + rh - stroke - r * 0.5), radius: Radius.circular(r * 0.5))
      ..lineTo(px + stroke, py + stroke + r * 0.5)
      // Inner top-left rounded fillet
      ..arcToPoint(Offset(px + stroke + r * 0.5, py + stroke), radius: Radius.circular(r * 0.5))
      ..lineTo(px + rw, py + stroke)
      ..close();

    canvas.drawPath(path, paint);
  }

  void _paintI(Canvas canvas, Paint paint, double px, double py, double rw, double rh, double stroke, double r, double c) {
    // Central vertical column
    final iStem = Path()
      ..addRect(Rect.fromLTWH(px + (rw - stroke) / 2, py, stroke, rh));

    // Top modular cap: rounded top-left, chamfered top-right, inner chamfers to stem
    final topCap = Path()
      ..moveTo(px, py + r)
      ..arcToPoint(Offset(px + r, py), radius: Radius.circular(r))
      ..lineTo(px + rw - c, py)
      ..lineTo(px + rw, py + c)
      ..lineTo(px + rw, py + stroke * 0.85)
      ..lineTo(px + (rw + stroke) / 2 + c * 0.6, py + stroke * 0.85)
      ..lineTo(px + (rw + stroke) / 2, py + stroke * 0.85 + c * 0.6)
      ..lineTo(px + (rw - stroke) / 2, py + stroke * 0.85 + c * 0.6)
      ..lineTo(px + (rw - stroke) / 2 - c * 0.6, py + stroke * 0.85)
      ..lineTo(px, py + stroke * 0.85)
      ..close();

    // Bottom modular cap: chamfered bottom-left, rounded bottom-right, inner chamfers to stem
    final bottomCap = Path()
      ..moveTo(px, py + rh - stroke * 0.85)
      ..lineTo(px + (rw - stroke) / 2 - c * 0.6, py + rh - stroke * 0.85)
      ..lineTo(px + (rw - stroke) / 2, py + rh - stroke * 0.85 - c * 0.6)
      ..lineTo(px + (rw + stroke) / 2, py + rh - stroke * 0.85 - c * 0.6)
      ..lineTo(px + (rw + stroke) / 2 + c * 0.6, py + rh - stroke * 0.85)
      ..lineTo(px + rw, py + rh - stroke * 0.85)
      ..lineTo(px + rw, py + rh - r)
      ..arcToPoint(Offset(px + rw - r, py + rh), radius: Radius.circular(r))
      ..lineTo(px + c, py + rh)
      ..lineTo(px, py + rh - c)
      ..close();

    final path1 = Path.combine(PathOperation.union, iStem, topCap);
    final fullI = Path.combine(PathOperation.union, path1, bottomCap);
    canvas.drawPath(fullI, paint);
  }

  void _paintL(Canvas canvas, Paint paint, double px, double py, double rw, double rh, double stroke, double r, double c) {
    final path = Path()
      ..moveTo(px, py + r)
      ..arcToPoint(Offset(px + r, py), radius: Radius.circular(r))
      ..lineTo(px + stroke, py)
      ..lineTo(px + stroke, py + rh - stroke - c)
      ..lineTo(px + stroke + c, py + rh - stroke)
      ..lineTo(px + rw - r, py + rh - stroke)
      ..arcToPoint(Offset(px + rw, py + rh - stroke + r), radius: Radius.circular(r))
      ..lineTo(px + rw, py + rh - r)
      ..arcToPoint(Offset(px + rw - r, py + rh), radius: Radius.circular(r))
      ..lineTo(px + r, py + rh)
      ..arcToPoint(Offset(px, py + rh - r), radius: Radius.circular(r))
      ..close();

    canvas.drawPath(path, paint);
  }

  void _paintA(Canvas canvas, Paint paint, double px, double py, double rw, double rh, double stroke, double r, double c) {
    final path = Path()
      ..moveTo(px, py + rh)
      ..lineTo(px + stroke, py + rh)
      ..lineTo(px + stroke, py + rh * 0.45)
      ..lineTo(px + rw * 0.35, py + stroke)
      ..lineTo(px + rw * 0.65, py + stroke)
      ..lineTo(px + rw - stroke, py + rh * 0.45)
      ..lineTo(px + rw - stroke, py + rh)
      ..lineTo(px + rw, py + rh)
      ..lineTo(px + rw, py + rh * 0.38)
      ..lineTo(px + rw * 0.72, py + r)
      ..arcToPoint(Offset(px + rw * 0.72 - r, py), radius: Radius.circular(r))
      ..lineTo(px + rw * 0.28 + r, py)
      ..arcToPoint(Offset(px + rw * 0.28, py + r), radius: Radius.circular(r))
      ..lineTo(px, py + rh * 0.38)
      ..close();

    canvas.drawPath(path, paint);
  }

  void _paintB(Canvas canvas, Paint paint, double px, double py, double rw, double rh, double stroke, double r, double c) {
    final path = Path()
      ..moveTo(px, py)
      ..lineTo(px + rw - r, py)
      ..arcToPoint(Offset(px + rw, py + r), radius: Radius.circular(r))
      ..lineTo(px + rw, py + rh * 0.45 - r)
      ..arcToPoint(Offset(px + rw - r, py + rh * 0.45), radius: Radius.circular(r))
      ..lineTo(px + rw - r, py + rh * 0.55)
      ..lineTo(px + rw, py + rh * 0.55 + r)
      ..lineTo(px + rw, py + rh - c)
      ..lineTo(px + rw - c, py + rh)
      ..lineTo(px, py + rh)
      ..close();

    final hole1 = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(px + stroke, py + stroke * 0.75, rw - stroke * 1.8, rh * 0.45 - stroke * 1.2),
        Radius.circular(r * 0.5),
      ));

    final hole2 = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(px + stroke, py + rh * 0.55 + stroke * 0.2, rw - stroke * 1.8, rh * 0.45 - stroke * 1.2),
        Radius.circular(r * 0.5),
      ));

    final fullB = Path.combine(PathOperation.difference, Path.combine(PathOperation.difference, path, hole1), hole2);
    canvas.drawPath(fullB, paint);
  }

  void _paintS(Canvas canvas, Paint paint, double px, double py, double rw, double rh, double stroke, double r, double c) {
    final path = Path()
      ..moveTo(px, py + rh * 0.35)
      ..lineTo(px + stroke, py + rh * 0.35)
      ..lineTo(px + stroke, py + stroke + r * 0.5)
      ..arcToPoint(Offset(px + stroke + r * 0.5, py + stroke), radius: Radius.circular(r * 0.5))
      ..lineTo(px + rw - r, py + stroke)
      ..arcToPoint(Offset(px + rw, py + stroke + r), radius: Radius.circular(r))
      ..lineTo(px + rw, py + rh * 0.48)
      ..lineTo(px + c, py + rh * 0.58)
      ..lineTo(px, py + rh * 0.65)
      ..lineTo(px, py + rh - r)
      ..arcToPoint(Offset(px + r, py + rh), radius: Radius.circular(r))
      ..lineTo(px + rw - c, py + rh)
      ..lineTo(px + rw, py + rh - c)
      ..lineTo(px + rw, py + rh * 0.65)
      ..lineTo(px + rw - stroke, py + rh * 0.65)
      ..lineTo(px + rw - stroke, py + rh - stroke)
      ..lineTo(px + stroke + r * 0.5, py + rh - stroke)
      ..arcToPoint(Offset(px + stroke, py + rh - stroke - r * 0.5), radius: Radius.circular(r * 0.5))
      ..lineTo(px + stroke, py + rh * 0.52)
      ..lineTo(px + rw - c, py + rh * 0.42)
      ..lineTo(px + rw, py + rh * 0.35)
      ..lineTo(px + rw, py + r)
      ..arcToPoint(Offset(px + rw - r, py), radius: Radius.circular(r))
      ..lineTo(px + r, py)
      ..arcToPoint(Offset(px, py + r), radius: Radius.circular(r))
      ..close();

    canvas.drawPath(path, paint);
  }

  void _paintDefault(Canvas canvas, Paint paint, double px, double py, double rw, double rh, double stroke, double r) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(px, py, rw, rh),
        Radius.circular(r),
      ));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ModularGlyphPainter oldDelegate) {
    return oldDelegate.char != char || oldDelegate.color != color;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ATTENDANCE DOT MATRIX CHART PAINTER (EXACT REPLICA OF ATTACHED IMAGE 2)
// ─────────────────────────────────────────────────────────────────────────────
class _AttendanceDotMatrixChartPainter extends CustomPainter {
  final List<int> leftColumns;
  final List<int> rightColumns;
  final Color leftColor;
  final Color rightColor;

  _AttendanceDotMatrixChartPainter({
    required this.leftColumns,
    required this.rightColumns,
    required this.leftColor,
    required this.rightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final leftPaint = Paint()
      ..color = leftColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final rightPaint = Paint()
      ..color = rightColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final totalWidth = size.width;
    final leftWidth = totalWidth * 0.40;
    final gapWidth = totalWidth * 0.08;
    final rightWidth = totalWidth * 0.52;

    final stepA = leftColumns.length > 1 ? leftWidth / (leftColumns.length - 1) : leftWidth;
    final startXB = leftWidth + gapWidth;
    final stepB = rightColumns.length > 1 ? rightWidth / (rightColumns.length - 1) : rightWidth;

    // Dot diameter ~ 4.2px, radius ~ 2.1px
    final dotRadius = (stepB * 0.26).clamp(1.8, 2.5);
    final verticalPitch = dotRadius * 2.85;
    final baselineY = size.height - 4.0;

    // Draw Left Cluster (Muted Previous Period / Term 1 dots)
    for (int col = 0; col < leftColumns.length; col++) {
      final cx = col * stepA;
      final count = leftColumns[col];
      for (int row = 0; row < count; row++) {
        final cy = baselineY - (row * verticalPitch);
        if (cy >= 0) {
          canvas.drawCircle(Offset(cx, cy), dotRadius, leftPaint);
        }
      }
    }

    // Draw Right Cluster (Solid Current Period / Term 2 dots)
    for (int col = 0; col < rightColumns.length; col++) {
      final cx = startXB + col * stepB;
      final count = rightColumns[col];
      for (int row = 0; row < count; row++) {
        final cy = baselineY - (row * verticalPitch);
        if (cy >= 0) {
          canvas.drawCircle(Offset(cx, cy), dotRadius, rightPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AttendanceDotMatrixChartPainter oldDelegate) {
    return oldDelegate.leftColor != leftColor ||
        oldDelegate.rightColor != rightColor ||
        oldDelegate.leftColumns != leftColumns ||
        oldDelegate.rightColumns != rightColumns;
  }
}

