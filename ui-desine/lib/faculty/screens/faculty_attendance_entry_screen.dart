import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_tokens.dart';
import '../../widgets/widgets.dart';
import '../../models/faculty_attendance_model.dart';
import '../../services/faculty_service.dart';
import '../widgets/batch_photo_picker_dialog.dart';

class FacultyAttendanceEntryScreen extends StatefulWidget {
  final int timetableEntryId;
  final String date;
  final String dayOfWeek;
  final String periodName;
  final String periodTime;
  final String subjectCode;
  final String subjectName;
  final String className;

  const FacultyAttendanceEntryScreen({
    Key? key,
    required this.timetableEntryId,
    required this.date,
    required this.dayOfWeek,
    required this.periodName,
    required this.periodTime,
    required this.subjectCode,
    required this.subjectName,
    required this.className,
  }) : super(key: key);

  @override
  State<FacultyAttendanceEntryScreen> createState() =>
      _FacultyAttendanceEntryScreenState();
}

class _FacultyAttendanceEntryScreenState
    extends State<FacultyAttendanceEntryScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  final List<StudentRosterItem> _students = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  Future<void> _loadRoster() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final facultyService =
          Provider.of<FacultyService>(context, listen: false);
      final response = await facultyService.fetchAttendanceRoster(
        widget.timetableEntryId,
        widget.date,
      );

      setState(() {
        _students.clear();
        for (final s in response.roster) {
          _students.add(s);
        }
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to load student roster. Please check your connection.';
      });
    }
  }

  Future<void> _openBatchPhotoPicker() async {
    final result = await BatchPhotoPickerDialog.show(
      context,
      timetableEntryId: widget.timetableEntryId,
      date: widget.date,
      periodName: widget.periodName,
      className: widget.className,
      subjectName: widget.subjectName,
    );

    if (result != null && mounted) {
      final recognizedMap = {
        for (var r in result.recognizedStudents) r.studentId: r
      };

      setState(() {
        for (var s in _students) {
          if (recognizedMap.containsKey(s.studentId)) {
            final rec = recognizedMap[s.studentId]!;
            s.attendanceStatus = 'PRESENT';
            s.recognizedInBatch = true;
            s.recognitionEvidence =
                'Recognized in ${rec.recognizedInPhotosCount} photo${rec.recognizedInPhotosCount > 1 ? 's' : ''} (${rec.bestConfidence.toStringAsFixed(1)}%)';
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Batch Recognition: ${result.uniqueRecognizedCount} student${result.uniqueRecognizedCount == 1 ? '' : 's'} recognized as Present across ${result.photosProcessed} photo${result.photosProcessed == 1 ? '' : 's'}. Remaining students remain Unmarked.',
          ),
          backgroundColor: context.colors.present,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _markAll(String status) {
    setState(() {
      for (final s in _students) {
        s.attendanceStatus = status;
        if (status != 'OD') {
          s.odReason = null;
        }
      }
    });
  }

  void _setStatus(StudentRosterItem student, String status) {
    if (status == 'OD') {
      _showOdReasonDialog(student);
    } else {
      setState(() {
        student.attendanceStatus = status;
        student.odReason = null;
      });
    }
  }

  void _showOdReasonDialog(StudentRosterItem student) {
    final colors = context.colors;
    final typography = context.typography;
    final controller = TextEditingController(text: student.odReason ?? '');
    final presets = [
      'Sports Event',
      'Symposium',
      'Hackathon',
      'NSS / NCC Camp',
      'Official Duty',
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        title: Text(
          'Mark OD: ${student.fullName}',
          style: typography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Roll Number: ${student.rollNumber}',
                style: typography.bodySmall.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Quick Presets:',
                style: typography.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: presets.map((p) {
                  return ActionChip(
                    label: Text(p, style: const TextStyle(fontSize: 11)),
                    backgroundColor: colors.surfaceMuted,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                    onPressed: () {
                      controller.text = p;
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Reason for On-Duty (OD)',
                  hintText: 'Enter reason or select preset',
                  border: OutlineInputBorder(borderRadius: AppRadius.mediumBorder),
                  filled: true,
                  fillColor: colors.surfaceMuted,
                ),
              ),
            ],
          ),
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
            onPressed: () {
              final reason = controller.text.trim();
              Navigator.pop(ctx);
              setState(() {
                student.attendanceStatus = 'OD';
                student.odReason =
                    reason.isNotEmpty ? reason : 'On-Duty Approved';
              });
            },
            child: const Text('Confirm OD', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAttendance() async {
    final colors = context.colors;
    if (_students.isEmpty) return;

    final unmarkedCount =
        _students.where((s) => s.attendanceStatus == 'UNMARKED').length;
    if (unmarkedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot submit: $unmarkedCount student${unmarkedCount > 1 ? "s remain" : " remains"} unmarked. Please mark all students as Present, Absent, or OD.',
          ),
          backgroundColor: colors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final records = _students.map((s) {
        return {
          'student_id': s.studentId,
          'status': s.attendanceStatus,
          if (s.odReason != null && s.odReason!.isNotEmpty)
            'od_reason': s.odReason,
        };
      }).toList();

      final facultyService =
          Provider.of<FacultyService>(context, listen: false);
      await facultyService.submitAttendanceWindow(
        timetableEntryId: widget.timetableEntryId,
        date: widget.date,
        records: records,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Attendance submitted successfully.'),
          backgroundColor: colors.present,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });

      String userMessage = e.message;
      if (e.statusCode == 403) {
        userMessage = 'You are not authorized to mark attendance for this class.';
      } else if (e.message.toLowerCase().contains('not open yet') ||
          e.message.toLowerCase().contains('ends at')) {
        userMessage = e.message;
      } else if (e.message.toLowerCase().contains('already recorded')) {
        userMessage = 'Attendance has already been recorded for this period.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMessage),
          backgroundColor: colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to submit attendance. Check your connection.'),
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

    final filtered = _students.where((s) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return s.fullName.toLowerCase().contains(query) ||
          s.rollNumber.toLowerCase().contains(query);
    }).toList();

    final presentCount =
        _students.where((s) => s.attendanceStatus == 'PRESENT').length;
    final absentCount =
        _students.where((s) => s.attendanceStatus == 'ABSENT').length;
    final odCount =
        _students.where((s) => s.attendanceStatus == 'OD').length;
    final unmarkedCount =
        _students.where((s) => s.attendanceStatus == 'UNMARKED').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: GlassCard(
                      variant: GlassCardVariant.standard,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: colors.error,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: typography.bodyMedium.copyWith(color: colors.textPrimary),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          PrimaryButton(
                            text: 'Retry',
                            icon: Icons.refresh_rounded,
                            onPressed: _loadRoster,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Header card with slot info
                    _buildHeaderCard(),

                    // Summary and Quick Actions bar
                    _buildSummaryAndActions(
                        presentCount, absentCount, odCount, unmarkedCount),

                    // Search input
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by roll number or name...',
                          prefixIcon: Icon(Icons.search, size: 20, color: colors.textMuted),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.pillBorder,
                            borderSide: BorderSide(color: colors.glassBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: AppRadius.pillBorder,
                            borderSide: BorderSide(color: colors.glassBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppRadius.pillBorder,
                            borderSide: BorderSide(color: colors.primary, width: 1.5),
                          ),
                          filled: true,
                          fillColor: colors.glassSurfaceStrong,
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                          });
                        },
                      ),
                    ),

                    // Roster list
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No matching students found.',
                                style: TextStyle(color: colors.textMuted),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                0,
                                AppSpacing.md,
                                90,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, idx) {
                                return _buildStudentCard(filtered[idx], idx + 1);
                              },
                            ),
                    ),
                  ],
                ),
      bottomSheet: _isLoading || _errorMessage != null
          ? null
          : Container(
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
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.pillBorder,
                      ),
                    ),
                    onPressed: _isSubmitting ? null : _submitAttendance,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Submit Attendance',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    final colors = context.colors;
    final typography = context.typography;

    return GlassCard(
      variant: GlassCardVariant.hero,
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.heroChip,
                  borderRadius: AppRadius.smallBorder,
                ),
                child: Text(
                  widget.periodName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.accentOnHero,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  widget.periodTime,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.onHero,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.heroChip,
                    borderRadius: AppRadius.pillBorder,
                  ),
                  child: Text(
                    '${widget.dayOfWeek}, ${widget.date}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colors.onHeroSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${widget.subjectName} (${widget.subjectCode})',
            style: typography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.onHero,
            ),
            softWrap: true,
          ),
          const SizedBox(height: 3),
          Text(
            widget.className,
            style: TextStyle(
              fontSize: 12,
              color: colors.onHeroSecondary,
            ),
            softWrap: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryAndActions(
      int presentCount, int absentCount, int odCount, int unmarkedCount) {
    final colors = context.colors;
    final total = _students.length;

    return GlassCard(
      variant: GlassCardVariant.standard,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCounter('Total', '$total', colors.textPrimary),
              _buildStatCounter('Present', '$presentCount', colors.present),
              _buildStatCounter('Absent', '$absentCount', colors.error),
              _buildStatCounter('OD', '$odCount', colors.warning),
              _buildStatCounter('Unmarked', '$unmarkedCount', colors.textMuted),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: colors.glassBorder),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: BorderSide(color: colors.primary),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                ),
                onPressed: _openBatchPhotoPicker,
                icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                label: const Text(
                  'Batch Photos',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.present,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: BorderSide(color: colors.present),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                ),
                onPressed: () => _markAll('PRESENT'),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text(
                  'All Present',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: BorderSide(color: colors.error),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                ),
                onPressed: () => _markAll('ABSENT'),
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text(
                  'All Absent',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCounter(String label, String count, Color color) {
    final typography = context.typography;
    final colors = context.colors;

    return Column(
      children: [
        Text(
          count,
          style: typography.numericLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: typography.caption.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }

  Widget _buildStudentCard(StudentRosterItem student, int index) {
    final colors = context.colors;
    final typography = context.typography;
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
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: cardBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '#$index',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
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
                      softWrap: true,
                    ),
                    Text(
                      student.rollNumber,
                      style: typography.caption.copyWith(color: colors.textMuted),
                    ),
                    if (student.recognizedInBatch && isPresent)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.face_retouching_natural, size: 12, color: colors.present),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                student.recognitionEvidence ?? 'Recognized via Photo',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colors.present,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Segmented Action Chips: P, A, OD
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatusButton(
                    label: 'P',
                    isSelected: isPresent,
                    selectedColor: colors.present,
                    onTap: () => _setStatus(student, 'PRESENT'),
                  ),
                  const SizedBox(width: 6),
                  _buildStatusButton(
                    label: 'A',
                    isSelected: isAbsent,
                    selectedColor: colors.error,
                    onTap: () => _setStatus(student, 'ABSENT'),
                  ),
                  const SizedBox(width: 6),
                  _buildStatusButton(
                    label: 'OD',
                    isSelected: isOd,
                    selectedColor: colors.warning,
                    onTap: () => _setStatus(student, 'OD'),
                  ),
                ],
              ),
            ],
          ),
          if (isOd && student.odReason != null && student.odReason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: () => _showOdReasonDialog(student),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.warningBg,
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 12, color: colors.warning),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'OD: ${student.odReason!}',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit, size: 10, color: colors.warning),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusButton({
    required String label,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smallBorder,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : colors.surfaceMuted,
          borderRadius: AppRadius.smallBorder,
          border: Border.all(
            color: isSelected ? selectedColor : colors.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
