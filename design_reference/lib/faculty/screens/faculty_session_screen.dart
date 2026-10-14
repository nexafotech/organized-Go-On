import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../widgets/widgets.dart';
import '../../services/faculty_service.dart';
import 'image_preview_screen.dart';

class FacultySessionScreen extends StatefulWidget {
  const FacultySessionScreen({Key? key}) : super(key: key);

  @override
  State<FacultySessionScreen> createState() => _FacultySessionScreenState();
}

class _FacultySessionScreenState extends State<FacultySessionScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FacultyService>(context, listen: false).checkActiveSession();
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final colors = context.colors;
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        final bytes = await pickedFile.readAsBytes();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ImagePreviewScreen(
              initialImage: File(pickedFile.path),
              initialBytes: bytes,
              initialName: pickedFile.name,
              isFromCamera: source == ImageSource.camera,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: colors.error,
        ),
      );
    }
  }

  void _showOdReasonDialog(int studentId, String studentName) {
    final colors = context.colors;
    final typography = context.typography;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        title: Text(
          'Mark OD: $studentName',
          style: typography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Provide reason for On-Duty (OD) status:',
              style: typography.bodySmall.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'OD Reason',
                hintText: 'e.g. Sports Event / Symposium',
                border: OutlineInputBorder(borderRadius: AppRadius.mediumBorder),
                filled: true,
                fillColor: colors.surfaceMuted,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: colors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
            ),
            onPressed: () async {
              final reason = reasonController.text.trim();
              Navigator.pop(ctx);
              final facultyService = Provider.of<FacultyService>(context, listen: false);
              try {
                await facultyService.markAttendance(
                  studentId: studentId,
                  status: 'OD',
                  odReason: reason.isNotEmpty ? reason : 'On-Duty Approved',
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(facultyService.errorMessage ?? e.toString()),
                    backgroundColor: colors.error,
                  ),
                );
              }
            },
            child: const Text('Mark OD', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _markStatus(int studentId, String status, String studentName) async {
    final colors = context.colors;
    if (status == 'OD') {
      _showOdReasonDialog(studentId, studentName);
      return;
    }

    final facultyService = Provider.of<FacultyService>(context, listen: false);
    try {
      await facultyService.markAttendance(studentId: studentId, status: status);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(facultyService.errorMessage ?? e.toString()),
          backgroundColor: colors.error,
        ),
      );
    }
  }

  void _confirmCompleteSession() {
    final colors = context.colors;
    final typography = context.typography;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        title: Row(
          children: [
            Icon(Icons.lock_clock_rounded, color: colors.present, size: 24),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Complete Session',
              style: typography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to complete and finalize this attendance session? Once finalized, the session will be locked.',
          style: typography.bodyMedium.copyWith(color: colors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: colors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.present,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _completeSession();
            },
            child: const Text('Complete & Finalize', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _completeSession() async {
    final colors = context.colors;
    final facultyService = Provider.of<FacultyService>(context, listen: false);
    try {
      await facultyService.completeSession();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Attendance session completed and finalized successfully.'),
              ),
            ],
          ),
          backgroundColor: colors.present,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(facultyService.errorMessage ?? 'Failed to complete session: $e'),
          backgroundColor: colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final facultyService = Provider.of<FacultyService>(context);
    final roster = facultyService.roster;

    int presentCount = roster.where((r) => r.attendanceStatus == 'PRESENT').length;
    int absentCount = roster.where((r) => r.attendanceStatus == 'ABSENT').length;
    int odCount = roster.where((r) => r.attendanceStatus == 'OD').length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Active Session #${facultyService.activeSessionId ?? ""}'),
      ),
      body: Column(
        children: [
          // Session Toolbar Actions (Camera, Gallery, Group Photo)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.glassSurfaceStrong,
              border: Border(bottom: BorderSide(color: colors.glassBorder)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: colors.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: const Icon(Icons.groups_rounded, size: 20),
                    label: const Text('TAKE GROUP PHOTO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () => _pickPhoto(ImageSource.camera),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.glassBorder),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: Icon(Icons.camera_alt_rounded, size: 18, color: colors.primary),
                    label: const Text('CAMERA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () => _pickPhoto(ImageSource.camera),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.glassBorder),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: Icon(Icons.photo_library_rounded, size: 18, color: colors.primary),
                    label: const Text('GALLERY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () => _pickPhoto(ImageSource.gallery),
                  ),
                ],
              ),
            ),
          ),

          // Attendance Counter Summary Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              border: Border(bottom: BorderSide(color: colors.glassBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(
                  'Total: ${roster.length}',
                  style: typography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
                Text(
                  'Present: $presentCount',
                  style: typography.bodyMedium.copyWith(color: colors.present, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Absent: $absentCount',
                  style: typography.bodyMedium.copyWith(color: colors.error, fontWeight: FontWeight.bold),
                ),
                Text(
                  'OD: $odCount',
                  style: typography.bodyMedium.copyWith(color: colors.warning, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Student Roster List
          Expanded(
            child: roster.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'No enrolled students in roster',
                        style: TextStyle(color: colors.textMuted, fontSize: 14),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    itemCount: roster.length,
                    itemBuilder: (ctx, idx) {
                      final student = roster[idx];
                      final isPresent = student.attendanceStatus == 'PRESENT';
                      final isAbsent = student.attendanceStatus == 'ABSENT';
                      final isOd = student.attendanceStatus == 'OD';

                      Color cardBorder = colors.glassBorder;
                      if (isPresent) {
                        cardBorder = colors.present.withValues(alpha: 0.35);
                      } else if (isAbsent) {
                        cardBorder = colors.error.withValues(alpha: 0.35);
                      } else if (isOd) {
                        cardBorder = colors.warning.withValues(alpha: 0.35);
                      }

                      return GlassCard(
                        variant: GlassCardVariant.standard,
                        enableBlur: false, // Smooth scroll list rule
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        borderColor: cardBorder,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student.fullName,
                                    style: typography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Roll: ${student.rollNumber}${student.odReason != null ? " | Reason: ${student.odReason}" : ""}',
                                    style: typography.caption.copyWith(color: colors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.check_circle_rounded,
                                    color: isPresent ? colors.present : colors.textMuted.withValues(alpha: 0.5),
                                    size: 26,
                                  ),
                                  tooltip: 'Mark Present',
                                  onPressed: () => _markStatus(student.studentId, 'PRESENT', student.fullName),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.cancel_rounded,
                                    color: isAbsent ? colors.error : colors.textMuted.withValues(alpha: 0.5),
                                    size: 26,
                                  ),
                                  tooltip: 'Mark Absent',
                                  onPressed: () => _markStatus(student.studentId, 'ABSENT', student.fullName),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.card_membership_rounded,
                                    color: isOd ? colors.warning : colors.textMuted.withValues(alpha: 0.5),
                                    size: 26,
                                  ),
                                  tooltip: 'Mark OD',
                                  onPressed: () => _markStatus(student.studentId, 'OD', student.fullName),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Complete Session Footer Action
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.glassSurfaceStrong,
              border: Border(top: BorderSide(color: colors.glassBorder)),
              boxShadow: AppGlass.shadowElevated,
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.present,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                  ),
                  icon: const Icon(Icons.check_box_rounded),
                  label: const Text(
                    'COMPLETE ATTENDANCE SESSION',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  onPressed: facultyService.isLoading ? null : _confirmCompleteSession,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
