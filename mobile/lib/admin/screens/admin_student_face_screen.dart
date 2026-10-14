import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/theme_service.dart';
import '../../models/admin_biometric_model.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/widgets.dart';
import '../../auth/screens/login_screen.dart';
import 'admin_notification_screen.dart';

class AdminStudentFaceScreen extends StatefulWidget {
  const AdminStudentFaceScreen({Key? key}) : super(key: key);

  @override
  State<AdminStudentFaceScreen> createState() => _AdminStudentFaceScreenState();
}

class _AdminStudentFaceScreenState extends State<AdminStudentFaceScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _filterState = 'ALL'; // 'ALL', 'ENROLLED', 'PENDING'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final adminService = Provider.of<AdminService>(context, listen: false);
    await Future.wait([
      adminService.fetchSummary(),
      adminService.fetchStudents(
        search: _searchController.text.trim(),
        enrolledOnly: _filterState == 'ALL' ? null : (_filterState == 'ENROLLED'),
      ),
    ]);
  }

  void _onSearchChanged(String value) {
    final adminService = Provider.of<AdminService>(context, listen: false);
    adminService.fetchStudents(
      search: value.trim(),
      enrolledOnly: _filterState == 'ALL' ? null : (_filterState == 'ENROLLED'),
    );
  }

  void _setFilter(String filter) {
    setState(() {
      _filterState = filter;
    });
    final adminService = Provider.of<AdminService>(context, listen: false);
    adminService.fetchStudents(
      search: _searchController.text.trim(),
      enrolledOnly: filter == 'ALL' ? null : (filter == 'ENROLLED'),
    );
  }

  void _confirmSignOut() {
    final colors = context.colors;
    final typography = context.typography;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBorder,
          side: BorderSide(color: colors.glassBorderStrong),
        ),
        title: Text(
          'Confirm Sign Out',
          style: typography.titleLarge.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to sign out of the Admin Terminal?',
          style: typography.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: typography.labelLarge.copyWith(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final authService = Provider.of<AuthService>(context, listen: false);
              await authService.restoreSession();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STUDENT DETAILS MODAL / BOTTOM SHEET
  // ============================================================
  void _openStudentDetails(AdminStudentBioModel student) {
    final adminService = Provider.of<AdminService>(context, listen: false);
    adminService.fetchStudentDetail(student.studentId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StudentDetailsSheet(
        initialStudent: student,
        onAddFace: () {
          Navigator.of(ctx).pop();
          _startEnrollmentFlow(student, isReplace: false);
        },
        onAddMultiplePhotos: () {
          Navigator.of(ctx).pop();
          _pickAndUploadPhotos(student, isReplace: false);
        },
        onViewDataset: () {
          Navigator.of(ctx).pop();
          _openStudentDataset(student);
        },
        onReplaceFace: () {
          Navigator.of(ctx).pop();
          _confirmReplaceFace(student);
        },
        onReplaceDataset: () {
          Navigator.of(ctx).pop();
          _confirmReplaceDataset(student);
        },
        onRemoveFace: () {
          Navigator.of(ctx).pop();
          _confirmRemoveFace(student);
        },
      ),
    );
  }

  void _openStudentDataset(AdminStudentBioModel student) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _StudentDatasetDialog(student: student),
    ).then((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  Future<void> _pickAndUploadPhotos(AdminStudentBioModel student, {required bool isReplace}) async {
    final colors = context.colors;
    try {
      final List<XFile> pickedList = await _picker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );

      if (pickedList.isEmpty || !mounted) return;

      final fileRecords = <({String filename, List<int> bytes})>[];
      for (final f in pickedList) {
        final b = await f.readAsBytes();
        fileRecords.add((filename: f.name, bytes: b));
      }

      final adminService = Provider.of<AdminService>(context, listen: false);
      final res = await adminService.enrollStudentPhotos(
        studentId: student.studentId,
        files: fileRecords,
        isReplace: isReplace,
      );

      if (!mounted) return;
      if (res != null) {
        showDialog(
          context: context,
          builder: (ctx) => _MultiPhotoResultDialog(result: res),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(adminService.errorMessage ?? 'Multi-photo enrollment failed'),
            backgroundColor: colors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick photos: $e'),
          backgroundColor: colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmReplaceDataset(AdminStudentBioModel student) async {
    final colors = context.colors;
    final typography = context.typography;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBorder,
          side: BorderSide(color: colors.glassBorderStrong),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.warning, size: 28),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Replace All Dataset Photos',
                style: typography.titleLarge.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Replace canonical face photo dataset for:',
              style: typography.bodyMedium.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: AppRadius.smallBorder,
                border: Border.all(color: colors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.fullName,
                    style: typography.titleMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                  ),
                  Text(
                    'Roll No: ${student.rollNumber}',
                    style: typography.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'All current photos in data/student_faces/${student.rollNumber}/ and database face templates will be replaced with your new selection.',
              style: typography.bodySmall.copyWith(color: colors.error, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: typography.labelLarge.copyWith(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Replace Dataset'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _pickAndUploadPhotos(student, isReplace: true);
    }
  }

  // ============================================================
  // ENROLLMENT / REPLACEMENT WORKFLOW
  // ============================================================
  Future<void> _confirmReplaceFace(AdminStudentBioModel student) async {
    final colors = context.colors;
    final typography = context.typography;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBorder,
          side: BorderSide(color: colors.glassBorderStrong),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.warning, size: 28),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Replace Face Enrollment',
                style: typography.titleLarge.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Replace existing face enrollment for:',
              style: typography.bodyMedium.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: AppRadius.smallBorder,
                border: Border.all(color: colors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.fullName,
                    style: typography.titleMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                  ),
                  Text(
                    'Roll No: ${student.rollNumber}',
                    style: typography.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                  if (student.className != null)
                    Text(
                      'Class: ${student.className}',
                      style: typography.bodySmall.copyWith(color: colors.textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'The previous biometric profile will be replaced with the new photo once confirmed.',
              style: typography.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: typography.labelLarge.copyWith(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _startEnrollmentFlow(student, isReplace: true);
    }
  }

  Future<void> _confirmRemoveFace(AdminStudentBioModel student) async {
    final colors = context.colors;
    final typography = context.typography;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBorder,
          side: BorderSide(color: colors.glassBorderStrong),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: colors.error, size: 28),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Remove Face Enrollment',
                style: typography.titleLarge.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remove face enrollment for:',
              style: typography.bodyMedium.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: AppRadius.smallBorder,
                border: Border.all(color: colors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.fullName,
                    style: typography.titleMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                  ),
                  Text(
                    'Roll No: ${student.rollNumber}',
                    style: typography.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'This will make the student unavailable for face recognition until another face is enrolled.',
              style: typography.bodySmall.copyWith(color: colors.error, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: typography.labelLarge.copyWith(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove Face'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final adminService = Provider.of<AdminService>(context, listen: false);
      final success = await adminService.resetStudentFace(student.studentId);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Face enrollment removed for ${student.fullName}'),
            backgroundColor: colors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(adminService.errorMessage ?? 'Failed to remove face enrollment'),
            backgroundColor: colors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _startEnrollmentFlow(AdminStudentBioModel student, {required bool isReplace}) async {
    final colors = context.colors;

    // 1. Choose Image Source (Camera or Gallery)
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ImageSourceSheet(student: student),
    );

    if (source == null || !mounted) return;

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );

      if (picked == null || !mounted) return;

      final Uint8List bytes = await picked.readAsBytes();

      // 2. Open Preview & Confirmation Dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _EnrollmentPreviewDialog(
          student: student,
          imageBytes: bytes,
          filename: picked.name,
          isReplace: isReplace,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to access image: $e'),
          backgroundColor: colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openFolderEnrollmentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _FolderEnrollmentDialog(),
    ).then((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final adminService = context.watch<AdminService>();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.hero,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GoOnLogo(size: 30),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin Face Management',
                    overflow: TextOverflow.ellipsis,
                    style: typography.titleMedium.copyWith(color: colors.onHero, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Institutional Biometric Control',
                    overflow: TextOverflow.ellipsis,
                    style: typography.caption.copyWith(color: colors.onHeroSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_shared_rounded),
            color: colors.onHero,
            tooltip: 'Folder Face Enrollment',
            onPressed: _openFolderEnrollmentDialog,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_rounded),
            color: colors.onHero,
            tooltip: 'Push Notifications & Reminders',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminNotificationScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: colors.onHero,
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
          SafeThemeConsumer(
            builder: (context, themeService, _) {
              final isDark = themeService.isDarkMode;
              return IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: isDark ? const Color(0xFFF59E0B) : colors.onHero,
                ),
                tooltip: isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
                onPressed: () => themeService.toggleTheme(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            color: colors.onHero,
            tooltip: 'Sign Out',
            onPressed: _confirmSignOut,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. OVERVIEW HERO CARD
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
              child: GlassCard(
                variant: GlassCardVariant.hero,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.xs + 2),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [colors.accent, colors.primary],
                            ),
                            borderRadius: AppRadius.smallBorder,
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Biometric Roster & Controls',
                                style: typography.titleMedium.copyWith(
                                  fontSize: 14,
                                  color: colors.onHero,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Single source of truth face enrollment',
                                style: typography.caption.copyWith(color: colors.onHeroSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (adminService.overview != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.surfaceMuted.withValues(alpha: 0.15),
                              borderRadius: AppRadius.pillBorder,
                              border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              '${adminService.overview!.modelName} (${adminService.overview!.dimension}-d)',
                              style: typography.caption.copyWith(color: colors.accentOnHero, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Quick Stats Bar
                    Row(
                      children: [
                        _buildQuickStat(
                          label: 'Total Students',
                          value: '${adminService.overview?.totalStudents ?? adminService.students.length}',
                          color: colors.onHero,
                          colors: colors,
                          typography: typography,
                        ),
                        Container(width: 1, height: 28, color: colors.glassBorderStrong),
                        _buildQuickStat(
                          label: 'Enrolled',
                          value: '${adminService.overview?.enrolledCount ?? adminService.students.where((s) => s.enrolled).length}',
                          color: colors.success,
                          colors: colors,
                          typography: typography,
                        ),
                        Container(width: 1, height: 28, color: colors.glassBorderStrong),
                        _buildQuickStat(
                          label: 'Pending',
                          value: '${adminService.overview?.pendingCount ?? adminService.students.where((s) => !s.enrolled).length}',
                          color: colors.warning,
                          colors: colors,
                          typography: typography,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // FOLDER ENROLLMENT QUICK ACTION
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              child: GlassCard(
                variant: GlassCardVariant.elevated,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(Icons.folder_shared_rounded, color: colors.accent, size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Folder Face Enrollment',
                            style: typography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                          Text(
                            'Enroll complete folder (Identity = Register No)',
                            style: typography.caption.copyWith(color: colors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                      ),
                      icon: const Icon(Icons.drive_folder_upload_rounded, size: 16),
                      label: const Text('Batch Enroll', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: _openFolderEnrollmentDialog,
                    ),
                  ],
                ),
              ),
            ),

            // 2. SEARCH & FILTER BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: typography.bodyMedium.copyWith(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search student name or roll number...',
                      hintStyle: typography.bodyMedium.copyWith(color: colors.textMuted),
                      prefixIcon: Icon(Icons.search_rounded, color: colors.textMuted),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              color: colors.textMuted,
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: colors.surfaceElevated,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.cardBorder,
                        borderSide: BorderSide(color: colors.glassBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.cardBorder,
                        borderSide: BorderSide(color: colors.glassBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.cardBorder,
                        borderSide: BorderSide(color: colors.accent, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Filter Chips
                  Row(
                    children: [
                      _buildFilterChip('ALL', 'All Students', colors, typography),
                      const SizedBox(width: AppSpacing.xs),
                      _buildFilterChip('ENROLLED', 'Enrolled Only', colors, typography),
                      const SizedBox(width: AppSpacing.xs),
                      _buildFilterChip('PENDING', 'Pending Only', colors, typography),
                    ],
                  ),
                ],
              ),
            ),

            // 3. STUDENT LIST
            Expanded(
              child: adminService.isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                      ),
                    )
                  : adminService.students.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_search_rounded, size: 48, color: colors.textMuted),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'No matching student records found',
                                style: typography.bodyMedium.copyWith(color: colors.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: colors.accent,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xl),
                            itemCount: adminService.students.length,
                            itemBuilder: (ctx, index) {
                              final student = adminService.students[index];
                              return _StudentBioCard(
                                student: student,
                                onTap: () => _openStudentDetails(student),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat({
    required String label,
    required String value,
    required Color color,
    required AppColors colors,
    required AppTypography typography,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: typography.titleMedium.copyWith(fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: typography.caption.copyWith(color: colors.onHeroSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, AppColors colors, AppTypography typography) {
    final isSelected = _filterState == key;
    return GestureDetector(
      onTap: () => _setFilter(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : colors.surfaceMuted,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: isSelected ? colors.primary : colors.glassBorder,
          ),
        ),
        child: Text(
          label,
          style: typography.caption.copyWith(
            color: isSelected ? colors.onPrimary : colors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// STUDENT CARD WIDGET (LIGHTWEIGHT GLASS — NO HEAVY BLUR)
// ============================================================
class _StudentBioCard extends StatelessWidget {
  final AdminStudentBioModel student;
  final VoidCallback onTap;

  const _StudentBioCard({
    Key? key,
    required this.student,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardBorder,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceElevated.withValues(alpha: 0.95),
              borderRadius: AppRadius.cardBorder,
              border: Border.all(color: colors.glassBorder),
              boxShadow: AppElevation.e1,
            ),
            child: Row(
              children: [
                // Initials Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: student.enrolled
                      ? colors.success.withValues(alpha: 0.15)
                      : colors.warning.withValues(alpha: 0.15),
                  child: Text(
                    student.fullName.isNotEmpty ? student.fullName[0] : 'S',
                    style: typography.titleMedium.copyWith(
                      fontSize: 14,
                      color: student.enrolled ? colors.success : colors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Student info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            student.rollNumber,
                            style: typography.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          if (student.className != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.surfaceMuted,
                                borderRadius: AppRadius.pillBorder,
                              ),
                              child: Text(
                                student.className!,
                                style: typography.caption.copyWith(color: colors.textMuted, fontSize: 10),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        student.fullName,
                        style: typography.bodySmall.copyWith(color: colors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Status Badge
                _buildStatusPill(colors, typography),
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.chevron_right_rounded, color: colors.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(AppColors colors, AppTypography typography) {
    if (student.enrolled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.success.withValues(alpha: 0.12),
          borderRadius: AppRadius.pillBorder,
          border: Border.all(color: colors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: colors.success, size: 12),
            const SizedBox(width: 4),
            Text(
              'ENROLLED',
              style: typography.caption.copyWith(color: colors.success, fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.warning.withValues(alpha: 0.12),
          borderRadius: AppRadius.pillBorder,
          border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, color: colors.warning, size: 12),
            const SizedBox(width: 4),
            Text(
              'NOT ENROLLED',
              style: typography.caption.copyWith(color: colors.warning, fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ],
        ),
      );
    }
  }
}

// ============================================================
// STUDENT DETAILS BOTTOM SHEET
// ============================================================
class _StudentDetailsSheet extends StatelessWidget {
  final AdminStudentBioModel initialStudent;
  final VoidCallback onAddFace;
  final VoidCallback onAddMultiplePhotos;
  final VoidCallback onViewDataset;
  final VoidCallback onReplaceFace;
  final VoidCallback onReplaceDataset;
  final VoidCallback onRemoveFace;

  const _StudentDetailsSheet({
    Key? key,
    required this.initialStudent,
    required this.onAddFace,
    required this.onAddMultiplePhotos,
    required this.onViewDataset,
    required this.onReplaceFace,
    required this.onReplaceDataset,
    required this.onRemoveFace,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final adminService = context.watch<AdminService>();
    final detail = adminService.selectedStudentDetail;

    final bool isEnrolled = detail?.enrolled ?? initialStudent.enrolled;
    final int templateCount = detail?.templateCount ?? initialStudent.templateCount;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: colors.glassBorderStrong),
        boxShadow: AppElevation.e3,
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.glassBorderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Student Header
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isEnrolled
                    ? colors.success.withValues(alpha: 0.15)
                    : colors.warning.withValues(alpha: 0.15),
                child: Text(
                  initialStudent.fullName.isNotEmpty ? initialStudent.fullName[0] : 'S',
                  style: typography.titleMedium.copyWith(
                    color: isEnrolled ? colors.success : colors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      initialStudent.fullName,
                      style: typography.titleMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Roll No: ${initialStudent.rollNumber} • ${initialStudent.className ?? "Class Section"}',
                      style: typography.bodySmall.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Status Surface
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: AppRadius.cardBorder,
              border: Border.all(color: colors.glassBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Face Status:',
                      style: typography.bodyMedium.copyWith(color: colors.textSecondary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isEnrolled
                            ? colors.success.withValues(alpha: 0.15)
                            : colors.warning.withValues(alpha: 0.15),
                        borderRadius: AppRadius.pillBorder,
                        border: Border.all(
                          color: isEnrolled ? colors.success : colors.warning,
                        ),
                      ),
                      child: Text(
                        isEnrolled ? 'ENROLLED' : 'NOT ENROLLED',
                        style: typography.caption.copyWith(
                          color: isEnrolled ? colors.success : colors.warning,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Biometric Templates:',
                      style: typography.bodySmall.copyWith(color: colors.textMuted),
                    ),
                    Text(
                      '$templateCount profile template(s)',
                      style: typography.bodySmall.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dataset Directory:',
                      style: typography.bodySmall.copyWith(color: colors.textMuted),
                    ),
                    Flexible(
                      child: Text(
                        'data/student_faces/${initialStudent.rollNumber}/',
                        style: typography.caption.copyWith(color: colors.accent, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (initialStudent.lastEnrollmentAt != null || detail?.lastEnrollmentTime != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Last Enrolled:',
                        style: typography.bodySmall.copyWith(color: colors.textMuted),
                      ),
                      Text(
                        (detail?.lastEnrollmentTime ?? initialStudent.lastEnrollmentAt ?? '').split('T').first,
                        style: typography.bodySmall.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Primary Actions
          if (!isEnrolled && templateCount == 0) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
              ),
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text(
                'ENROLL MULTIPLE PHOTOS',
                style: typography.labelLarge.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              onPressed: onAddMultiplePhotos,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.glassBorderStrong),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
                    ),
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: Text('Camera Capture', style: typography.labelMedium.copyWith(fontWeight: FontWeight.w600)),
                    onPressed: onAddFace,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.accent,
                      side: BorderSide(color: colors.accent.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
                    ),
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: Text('View Dataset', style: typography.labelMedium.copyWith(fontWeight: FontWeight.w600)),
                    onPressed: onViewDataset,
                  ),
                ),
              ],
            ),
          ] else ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
              ),
              icon: const Icon(Icons.photo_library_rounded),
              label: Text(
                'VIEW FACE DATASET ($templateCount)',
                style: typography.labelLarge.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              onPressed: onViewDataset,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.accent,
                      side: BorderSide(color: colors.accent, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
                    ),
                    icon: const Icon(Icons.add_photo_alternate_rounded),
                    label: Text(
                      'ADD PHOTOS',
                      style: typography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    onPressed: onAddMultiplePhotos,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.warning,
                      side: BorderSide(color: colors.warning.withValues(alpha: 0.8), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
                    ),
                    icon: const Icon(Icons.sync_rounded),
                    label: Text(
                      'REPLACE',
                      style: typography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    onPressed: onReplaceDataset,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.error,
                    side: BorderSide(color: colors.error.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
                  ),
                  onPressed: onRemoveFace,
                  child: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// PHASE 7.8: CANONICAL DATASET VIEWER & MANAGEMENT DIALOG
// ============================================================
class _StudentDatasetDialog extends StatefulWidget {
  final AdminStudentBioModel student;

  const _StudentDatasetDialog({Key? key, required this.student}) : super(key: key);

  @override
  State<_StudentDatasetDialog> createState() => _StudentDatasetDialogState();
}

class _StudentDatasetDialogState extends State<_StudentDatasetDialog> {
  final ImagePicker _picker = ImagePicker();
  StudentDatasetViewModel? _dataset;
  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDataset();
  }

  Future<void> _loadDataset() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final adminService = Provider.of<AdminService>(context, listen: false);
    final data = await adminService.fetchStudentDataset(widget.student.studentId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (data != null) {
        _dataset = data;
      } else {
        _error = adminService.errorMessage ?? 'Failed to load student dataset';
      }
    });
  }

  Future<void> _pickAndUpload({required bool isReplace}) async {
    final colors = context.colors;
    final typography = context.typography;

    if (isReplace) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: colors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.cardBorder,
            side: BorderSide(color: colors.glassBorderStrong),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: colors.warning, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Replace Entire Dataset',
                  style: typography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            'This will permanently delete all existing photos and biometric templates for ${widget.student.fullName} (${widget.student.rollNumber}) and replace them with the new photos.',
            style: typography.bodyMedium.copyWith(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.warning,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Confirm Replace'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      final pickedList = await _picker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );

      if (pickedList.isEmpty || !mounted) return;

      setState(() => _isActionLoading = true);

      final fileRecords = <({String filename, List<int> bytes})>[];
      for (final f in pickedList) {
        final b = await f.readAsBytes();
        fileRecords.add((filename: f.name, bytes: b));
      }

      final adminService = Provider.of<AdminService>(context, listen: false);
      final res = await adminService.enrollStudentPhotos(
        studentId: widget.student.studentId,
        files: fileRecords,
        isReplace: isReplace,
      );

      if (!mounted) return;
      setState(() => _isActionLoading = false);

      if (res != null) {
        await _loadDataset();
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => _MultiPhotoResultDialog(result: res),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(adminService.errorMessage ?? 'Multi-photo upload failed'),
            backgroundColor: colors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload photos: $e'),
          backgroundColor: colors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Dialog(
      backgroundColor: colors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: BorderSide(color: colors.glassBorderStrong),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.15),
                      borderRadius: AppRadius.smallBorder,
                    ),
                    child: Icon(Icons.perm_identity_rounded, color: colors.primary, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.student.fullName,
                          style: typography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Roll No: ${widget.student.rollNumber} • ${widget.student.className ?? "Class Section"}',
                          style: typography.caption.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    color: colors.textSecondary,
                    tooltip: 'Reload Dataset',
                    onPressed: _isLoading || _isActionLoading ? null : _loadDataset,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: colors.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Dataset Info & Path Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: AppRadius.smallBorder,
                  border: Border.all(color: colors.glassBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.folder_shared_outlined, size: 16, color: colors.accent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'data/student_faces/${widget.student.rollNumber}/',
                            style: typography.caption.copyWith(
                              color: colors.accent,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            borderRadius: AppRadius.pillBorder,
                          ),
                          child: Text(
                            '${_dataset?.photoCount ?? 0} Stored Photos',
                            style: typography.caption.copyWith(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.success.withValues(alpha: 0.12),
                            borderRadius: AppRadius.pillBorder,
                          ),
                          child: Text(
                            '${_dataset?.templateCount ?? 0} Active Templates',
                            style: typography.caption.copyWith(color: colors.success, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Action Toolbar
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.smallBorder),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                      label: const Text('Add Photos'),
                      onPressed: _isActionLoading ? null : () => _pickAndUpload(isReplace: false),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.warning,
                      side: BorderSide(color: colors.warning.withValues(alpha: 0.6)),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.smallBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: const Text('Replace All'),
                    onPressed: _isActionLoading ? null : () => _pickAndUpload(isReplace: true),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Body: Gallery or Loading
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(strokeWidth: 2.5, color: colors.accent),
                            const SizedBox(height: AppSpacing.sm),
                            Text('Loading dataset photos...', style: typography.caption),
                          ],
                        ),
                      )
                    : _isActionLoading
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(strokeWidth: 2.5, color: colors.primary),
                                const SizedBox(height: AppSpacing.sm),
                                Text('Processing face embeddings & storing photos...', style: typography.caption),
                              ],
                            ),
                          )
                        : _error != null
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.error_outline_rounded, color: colors.error, size: 36),
                                    const SizedBox(height: 8),
                                    Text(_error!, style: typography.caption.copyWith(color: colors.error)),
                                    const SizedBox(height: 12),
                                    ElevatedButton(
                                      onPressed: _loadDataset,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            : (_dataset?.photos.isEmpty ?? true)
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.no_photography_outlined, size: 48, color: colors.textMuted),
                                        const SizedBox(height: AppSpacing.sm),
                                        Text(
                                          'No face photos stored in canonical folder yet.',
                                          style: typography.bodyMedium.copyWith(color: colors.textSecondary),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Tap "+ Add Photos" above to select and enroll photos.',
                                          style: typography.caption.copyWith(color: colors.textMuted),
                                        ),
                                      ],
                                    ),
                                  )
                                : GridView.builder(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: 0.88,
                                    ),
                                    itemCount: _dataset!.photos.length,
                                    itemBuilder: (ctx, idx) {
                                      final photo = _dataset!.photos[idx];
                                      return _StudentPhotoThumbnail(
                                        studentId: widget.student.studentId,
                                        photo: photo,
                                        onDeleteSuccess: _loadDataset,
                                      );
                                    },
                                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PHOTO THUMBNAIL CARD WITH PER-PHOTO REMOVAL
// ============================================================
class _StudentPhotoThumbnail extends StatefulWidget {
  final int studentId;
  final StudentPhotoItemModel photo;
  final VoidCallback onDeleteSuccess;

  const _StudentPhotoThumbnail({
    Key? key,
    required this.studentId,
    required this.photo,
    required this.onDeleteSuccess,
  }) : super(key: key);

  @override
  State<_StudentPhotoThumbnail> createState() => _StudentPhotoThumbnailState();
}

class _StudentPhotoThumbnailState extends State<_StudentPhotoThumbnail> {
  Uint8List? _bytes;
  bool _isLoading = true;
  bool _isDeleting = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final adminService = Provider.of<AdminService>(context, listen: false);
    final raw = await adminService.fetchStudentPhotoImageBytes(widget.studentId, widget.photo.embeddingId);
    if (!mounted) return;
    if (raw != null && raw.isNotEmpty) {
      setState(() {
        _bytes = Uint8List.fromList(raw);
        _isLoading = false;
      });
    } else {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmDelete() async {
    final colors = context.colors;
    final typography = context.typography;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBorder,
          side: BorderSide(color: colors.glassBorderStrong),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: colors.error, size: 24),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Delete Face Photo',
                style: typography.titleLarge.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Delete photo "${widget.photo.filename}"?\n\nThis will remove the file from data/student_faces/ and purge its biometric template from the database.',
          style: typography.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Photo'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isDeleting = true);
      final adminService = Provider.of<AdminService>(context, listen: false);
      final ok = await adminService.deleteStudentPhoto(
        studentId: widget.studentId,
        embeddingId: widget.photo.embeddingId,
      );
      if (!mounted) return;
      setState(() => _isDeleting = false);
      if (ok) {
        widget.onDeleteSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(adminService.errorMessage ?? 'Failed to delete photo'),
            backgroundColor: colors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: AppRadius.smallBorder,
        border: Border.all(color: colors.glassBorderStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image container
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent))
                    : _hasError || _bytes == null
                        ? Center(
                            child: Icon(Icons.broken_image_rounded, color: colors.textMuted, size: 36),
                          )
                        : GestureDetector(
                            onTap: () {
                              if (_bytes != null) {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => _PhotoZoomDialog(
                                    bytes: _bytes!,
                                    filename: widget.photo.filename,
                                  ),
                                );
                              }
                            },
                            child: Image.memory(
                              _bytes!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
              ),

              // Bottom metadata bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                color: colors.surfaceElevated.withValues(alpha: 0.9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.photo.filename,
                      style: typography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.photo.createdAt != null
                              ? widget.photo.createdAt!.split('T').first
                              : 'ID: ${widget.photo.embeddingId}',
                          style: typography.caption.copyWith(fontSize: 10, color: colors.textMuted),
                        ),
                        if (widget.photo.qualityScore != null)
                          Text(
                            'Q: ${(widget.photo.qualityScore! * 100).toInt()}%',
                            style: typography.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colors.success,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Top right Delete button overlay
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isDeleting ? null : _confirmDelete,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: _isDeleting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PHOTO ZOOM / DETAIL DIALOG
// ============================================================
class _PhotoZoomDialog extends StatelessWidget {
  final Uint8List bytes;
  final String filename;

  const _PhotoZoomDialog({
    Key? key,
    required this.bytes,
    required this.filename,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Dialog(
      backgroundColor: colors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    filename,
                    style: typography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 460),
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ============================================================
// MULTI-PHOTO ENROLLMENT RESULT REPORT DIALOG
// ============================================================
class _MultiPhotoResultDialog extends StatelessWidget {
  final MultiPhotoEnrollResponseModel result;

  const _MultiPhotoResultDialog({Key? key, required this.result}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Dialog(
      backgroundColor: colors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: BorderSide(color: colors.glassBorderStrong),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    result.validEnrolled > 0 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                    color: result.validEnrolled > 0 ? colors.success : colors.warning,
                    size: 26,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enrollment Results',
                          style: typography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${result.fullName} (${result.rollNumber})',
                          style: typography.caption.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Summary Stats Box
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: AppRadius.smallBorder,
                  border: Border.all(color: colors.glassBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat('Total', '${result.totalFiles}', colors.textPrimary, typography),
                    _buildStat('Enrolled', '${result.validEnrolled}', colors.success, typography),
                    _buildStat('Rejected', '${result.rejected}', colors.error, typography),
                    if (result.replacedOldCount > 0)
                      _buildStat('Replaced', '${result.replacedOldCount}', colors.accent, typography),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              Text(
                result.message,
                style: typography.caption.copyWith(color: colors.textSecondary),
              ),

              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1),

              // Items breakdown list
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: result.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final item = result.items[idx];
                    final isEnrolled = item.status == 'ENROLLED';
                    final isDuplicate = item.status == 'SKIPPED_DUPLICATE';

                    Color statusColor = colors.error;
                    IconData statusIcon = Icons.cancel_outlined;

                    if (isEnrolled) {
                      statusColor = colors.success;
                      statusIcon = Icons.check_circle_outline_rounded;
                    } else if (isDuplicate) {
                      statusColor = colors.warning;
                      statusIcon = Icons.copy_rounded;
                    } else if (item.status == 'REJECTED_MULTI_FACE') {
                      statusColor = colors.warning;
                      statusIcon = Icons.groups_rounded;
                    }

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: Icon(statusIcon, color: statusColor, size: 20),
                      title: Text(
                        item.filename,
                        style: typography.bodySmall.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        item.reason ?? item.status,
                        style: typography.caption.copyWith(color: statusColor),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: AppRadius.pillBorder,
                        ),
                        child: Text(
                          item.status,
                          style: typography.caption.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color, AppTypography typography) {
    return Column(
      children: [
        Text(
          value,
          style: typography.titleMedium.copyWith(fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: typography.caption.copyWith(fontSize: 10)),
      ],
    );
  }
}

// ============================================================
// IMAGE SOURCE SELECTOR SHEET
// ============================================================
class _ImageSourceSheet extends StatelessWidget {
  final AdminStudentBioModel student;

  const _ImageSourceSheet({Key? key, required this.student}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: colors.glassBorderStrong),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.glassBorderStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Enroll Face for ${student.fullName}',
            style: typography.titleMedium.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
          ),
          Text(
            'Roll No: ${student.rollNumber}',
            style: typography.caption.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colors.accent.withValues(alpha: 0.15),
              child: Icon(Icons.photo_library_rounded, color: colors.accent),
            ),
            title: Text('Upload Photo from Gallery', style: typography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            subtitle: Text('Select an existing clear face image', style: typography.caption),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          const SizedBox(height: AppSpacing.xs),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colors.primary.withValues(alpha: 0.15),
              child: Icon(Icons.camera_alt_rounded, color: colors.primary),
            ),
            title: Text('Capture Photo with Camera', style: typography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            subtitle: Text('Take a new front-facing photo', style: typography.caption),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

// ============================================================
// IMAGE PREVIEW & CONFIRMATION DIALOG
// ============================================================
class _EnrollmentPreviewDialog extends StatefulWidget {
  final AdminStudentBioModel student;
  final Uint8List imageBytes;
  final String filename;
  final bool isReplace;

  const _EnrollmentPreviewDialog({
    Key? key,
    required this.student,
    required this.imageBytes,
    required this.filename,
    required this.isReplace,
  }) : super(key: key);

  @override
  State<_EnrollmentPreviewDialog> createState() => _EnrollmentPreviewDialogState();
}

class _EnrollmentPreviewDialogState extends State<_EnrollmentPreviewDialog> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final adminService = context.watch<AdminService>();

    return Dialog(
      backgroundColor: colors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: BorderSide(color: colors.glassBorderStrong),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Text(
                widget.isReplace ? 'REPLACE STUDENT FACE' : 'ADD STUDENT FACE',
                style: typography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Verify image and student details before submitting',
                style: typography.caption.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),

              // Image Preview
              Center(
                child: ClipRRect(
                  borderRadius: AppRadius.cardBorder,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      border: Border.all(color: colors.accent, width: 1.5),
                    ),
                    child: Image.memory(
                      widget.imageBytes,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Student Identity Details
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: AppRadius.smallBorder,
                  border: Border.all(color: colors.glassBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Student: ', style: typography.bodySmall.copyWith(color: colors.textMuted)),
                        Expanded(
                          child: Text(
                            widget.student.fullName,
                            style: typography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text('Roll No: ', style: typography.bodySmall.copyWith(color: colors.textMuted)),
                        Text(
                          widget.student.rollNumber,
                          style: typography.bodySmall.copyWith(fontWeight: FontWeight.w600, color: colors.textPrimary),
                        ),
                      ],
                    ),
                    if (widget.student.className != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text('Class: ', style: typography.bodySmall.copyWith(color: colors.textMuted)),
                          Text(
                            widget.student.className!,
                            style: typography.bodySmall.copyWith(color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Qualitative Validation Feedback Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.12),
                  borderRadius: AppRadius.smallBorder,
                  border: Border.all(color: colors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: colors.success, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Image ready for biometric processing',
                        style: typography.caption.copyWith(color: colors.success, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              // Error banner if any
              if (adminService.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: 0.12),
                    borderRadius: AppRadius.smallBorder,
                    border: Border.all(color: colors.error.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    adminService.errorMessage!,
                    style: typography.caption.copyWith(color: colors.error, fontWeight: FontWeight.w600),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),

              // Action Buttons
              if (adminService.isActionLoading)
                Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                      ),
                      const SizedBox(height: 8),
                      Text('Processing biometric features...', style: typography.caption),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel', style: typography.labelLarge.copyWith(color: colors.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                        ),
                        onPressed: () async {
                          final success = await adminService.enrollStudentFace(
                            studentId: widget.student.studentId,
                            imageBytes: widget.imageBytes,
                            filename: widget.filename,
                            isReplace: widget.isReplace,
                          );

                          if (!mounted) return;
                          if (success) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '✓ Face enrolled successfully for ${widget.student.fullName}. Student is now available for face-recognition attendance.',
                                ),
                                backgroundColor: colors.success,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                        child: Text(
                          widget.isReplace ? 'Confirm Replace' : 'Confirm Enrollment',
                          style: typography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderEnrollmentDialog extends StatefulWidget {
  const _FolderEnrollmentDialog({Key? key}) : super(key: key);

  @override
  State<_FolderEnrollmentDialog> createState() => _FolderEnrollmentDialogState();
}

class _FolderEnrollmentDialogState extends State<_FolderEnrollmentDialog> {
  final TextEditingController _pathController = TextEditingController(
    text: r'C:\Users\Abishek\OneDrive\Desktop\all in\Attendance_Marker\dataset',
  );
  bool _replace = false;
  bool _isScanning = false;
  bool _isEnrolling = false;
  Map<String, dynamic>? _manifest;
  Map<String, dynamic>? _batchResult;
  String? _error;

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _scanManifest() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      setState(() => _error = 'Please provide a folder path');
      return;
    }

    setState(() {
      _isScanning = true;
      _error = null;
      _batchResult = null;
    });

    final adminService = Provider.of<AdminService>(context, listen: false);
    final res = await adminService.previewFolderPath(path);

    if (!mounted) return;
    setState(() {
      _isScanning = false;
      if (res != null) {
        _manifest = res;
      } else {
        _error = adminService.errorMessage ?? 'Failed to inspect folder';
      }
    });
  }

  Future<void> _executeEnrollment() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) return;

    setState(() {
      _isEnrolling = true;
      _error = null;
    });

    final adminService = Provider.of<AdminService>(context, listen: false);
    final res = await adminService.enrollFolderPath(
      folderPath: path,
      replace: _replace,
    );

    if (!mounted) return;
    setState(() {
      _isEnrolling = false;
      if (res != null) {
        _batchResult = res;
      } else {
        _error = adminService.errorMessage ?? 'Enrollment failed';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Dialog(
      backgroundColor: colors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: BorderSide(color: colors.glassBorderStrong),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.15),
                      borderRadius: AppRadius.smallBorder,
                    ),
                    child: Icon(Icons.folder_shared_rounded, color: colors.accent, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Folder Face Enrollment',
                          style: typography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Folder Name = Student Register Number',
                          style: typography.caption.copyWith(color: colors.accent),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: colors.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Content Area (Scrollable)
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Instructions Card
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          borderRadius: AppRadius.smallBorder,
                          border: Border.all(color: colors.glassBorder),
                        ),
                        child: Text(
                          'Identity is strictly mapped from each folder\'s name (Register Number). Individual photo filenames are completely ignored.',
                          style: typography.caption.copyWith(color: colors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Folder Path Input
                      Text(
                        'Server / Host Directory Path',
                        style: typography.labelMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _pathController,
                              style: typography.bodySmall.copyWith(color: colors.textPrimary),
                              decoration: InputDecoration(
                                hintText: r'e.g. C:\path\to\dataset',
                                hintStyle: typography.bodySmall.copyWith(color: colors.textMuted),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: AppRadius.smallBorder),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.surfaceElevated,
                              foregroundColor: colors.accent,
                              side: BorderSide(color: colors.accent),
                              shape: RoundedRectangleBorder(borderRadius: AppRadius.smallBorder),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onPressed: _isScanning || _isEnrolling ? null : _scanManifest,
                            child: _isScanning
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Scan Manifest'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Replace Checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: _replace,
                            activeColor: colors.primary,
                            onChanged: (val) {
                              setState(() => _replace = val ?? false);
                            },
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _replace = !_replace),
                              child: Text(
                                'Replace existing biometric templates (Overwrites previous samples)',
                                style: typography.caption.copyWith(color: colors.textSecondary),
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: colors.error.withValues(alpha: 0.1),
                            borderRadius: AppRadius.smallBorder,
                            border: Border.all(color: colors.error.withValues(alpha: 0.4)),
                          ),
                          child: Text(_error!, style: typography.caption.copyWith(color: colors.error)),
                        ),
                      ],

                      // Pre-flight Manifest View
                      if (_manifest != null && _batchResult == null) ...[
                        const SizedBox(height: AppSpacing.md),
                        _buildManifestCard(colors, typography),
                      ],

                      // Enrollment In-Progress Spinner
                      if (_isEnrolling) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: colors.primary),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Processing facial quality & 128-d embeddings...',
                                style: typography.bodySmall.copyWith(color: colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Batch Results View
                      if (_batchResult != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        _buildResultsCard(colors, typography),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Close', style: typography.labelLarge.copyWith(color: colors.textSecondary)),
                  ),
                  if (_manifest != null && _batchResult == null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: const Text('Start Enrollment'),
                      onPressed: _isEnrolling ? null : _executeEnrollment,
                    ),
                  ],
                  if (_batchResult != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManifestCard(dynamic colors, dynamic typography) {
    final students = (_manifest!['students'] as List<dynamic>?) ?? [];
    final totalImages = _manifest!['total_image_files'] ?? 0;
    final totalFolders = _manifest!['total_folders'] ?? 0;
    final foundCount = _manifest!['students_found_in_db'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: colors.glassBorderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Manifest Preview', style: typography.labelLarge.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary)),
              Text('$foundCount / $totalFolders Students Matched', style: typography.caption.copyWith(color: colors.accent)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Found $totalImages candidate image(s) across $totalFolders student folder(s)', style: typography.caption.copyWith(color: colors.textSecondary)),
          const Divider(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: students.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final st = students[idx] as Map<String, dynamic>;
                final exists = st['exists_in_db'] == true;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    exists ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                    color: exists ? colors.success : colors.error,
                    size: 20,
                  ),
                  title: Text(
                    '${st['roll_number']} - ${st['full_name'] ?? 'Unknown'}',
                    style: typography.bodySmall.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${st['image_files_count']} photos • Current: ${st['current_template_count']} templates',
                    style: typography.caption.copyWith(color: colors.textSecondary),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCard(dynamic colors, dynamic typography) {
    final succ = _batchResult!['successful_students'] ?? 0;
    final fail = _batchResult!['failed_students'] ?? 0;
    final embs = _batchResult!['total_embeddings_created'] ?? 0;
    final students = (_batchResult!['students'] as List<dynamic>?) ?? [];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: colors.success.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: colors.success, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Enrollment Complete',
                  style: typography.labelLarge.copyWith(fontWeight: FontWeight.bold, color: colors.success),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$embs template(s) generated across $succ successful student(s) ($fail failed/skipped).',
            style: typography.caption.copyWith(color: colors.textSecondary),
          ),
          const Divider(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: students.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final st = students[idx] as Map<String, dynamic>;
                final status = st['status']?.toString() ?? '';
                final isOk = status == 'SUCCESS' || status == 'PARTIAL_SUCCESS';
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isOk ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                    color: isOk ? colors.success : colors.warning,
                    size: 18,
                  ),
                  title: Text(
                    '${st['roll_number']} (${st['full_name'] ?? 'N/A'})',
                    style: typography.bodySmall.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Enrolled: ${st['valid_enrolled']} • Status: $status • ${st['message'] ?? ''}',
                    style: typography.caption.copyWith(color: colors.textSecondary),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
