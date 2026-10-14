import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_tokens.dart';
import '../../widgets/widgets.dart';
import '../../models/faculty_attendance_model.dart';
import '../../services/faculty_service.dart';
import '../widgets/batch_photo_picker_dialog.dart';

class FacultyClassAdvisorEntryScreen extends StatefulWidget {
  final int timetableEntryId;
  final String date;
  final String dayOfWeek;
  final String periodName;
  final int periodNumber;
  final String periodTime;
  final String subjectCode;
  final String subjectName;
  final String className;
  final String subjectFacultyName;

  const FacultyClassAdvisorEntryScreen({
    Key? key,
    required this.timetableEntryId,
    required this.date,
    required this.dayOfWeek,
    required this.periodName,
    required this.periodNumber,
    required this.periodTime,
    required this.subjectCode,
    required this.subjectName,
    required this.className,
    required this.subjectFacultyName,
  }) : super(key: key);

  @override
  State<FacultyClassAdvisorEntryScreen> createState() =>
      _FacultyClassAdvisorEntryScreenState();
}

class _FacultyClassAdvisorEntryScreenState
    extends State<FacultyClassAdvisorEntryScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  final List<StudentRosterItem> _students = [];
  String? _lastUpdatedAt;
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
      final response = await facultyService.fetchClassAdvisorRoster(
        widget.timetableEntryId,
        widget.date,
      );

      setState(() {
        _students.clear();
        _lastUpdatedAt = response.lastUpdatedAt;
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
            'Unable to load class roster. Please check your connection.';
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
      'Symposium / Hackathon',
      'NSS / NCC Camp',
      'Placement Drive',
      'Official College Duty',
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
                'Roll: ${student.rollNumber}',
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
                    reason.isNotEmpty ? reason : 'Class Advisor OD Approved';
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

    final unmarkedCount =
        _students.where((s) => s.attendanceStatus == 'UNMARKED').length;
    if (unmarkedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot submit: $unmarkedCount student${unmarkedCount > 1 ? "s remain" : " remains"} unmarked. Please mark all students before saving.',
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

    final records = _students.map((s) {
      return {
        'student_id': s.studentId,
        'status': s.attendanceStatus,
        if (s.odReason != null && s.odReason!.isNotEmpty)
          'od_reason': s.odReason,
      };
    }).toList();

    try {
      final facultyService =
          Provider.of<FacultyService>(context, listen: false);
      final response = await facultyService.submitClassAdvisorAttendance(
        timetableEntryId: widget.timetableEntryId,
        date: widget.date,
        records: records,
        expectedLastUpdated: _lastUpdatedAt,
      );

      setState(() {
        _isSubmitting = false;
      });

      if (!mounted) return;

      // Show summary dialog
      if (response.dailySummary != null) {
        await _showDailySummaryDialog(response.dailySummary!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: colors.present,
          ),
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (!mounted) return;
      if (e.statusCode == 409) {
        // Concurrency conflict
        _showConflictDialog(e.message);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: colors.error,
          ),
        );
      }
    } catch (_) {
      setState(() {
        _isSubmitting = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to submit attendance. Check connection.'),
          backgroundColor: colors.error,
        ),
      );
    }
  }

  void _showConflictDialog(String message) {
    final colors = context.colors;
    final typography = context.typography;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        title: Row(
          children: [
            Icon(Icons.sync_problem_rounded, color: colors.warning, size: 24),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Concurrency Conflict',
              style: typography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: typography.bodyMedium.copyWith(color: colors.textPrimary),
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
            ),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reload Latest Roster', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              _loadRoster();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showDailySummaryDialog(ClassDailySummaryResponse summary) async {
    final colors = context.colors;
    final typography = context.typography;

    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        title: Row(
          children: [
            Icon(Icons.verified_rounded, color: colors.present, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Attendance Saved — Daily Summary',
                style: typography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Class: ${summary.className} | Date: ${summary.date}',
                style: typography.caption.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: AppRadius.mediumBorder,
                  border: Border.all(color: colors.glassBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryStat('Full Day Present', '${summary.fullDayPresentCount}', colors.present),
                        _buildSummaryStat('Half-Day Present', '${summary.halfDayPresentCount}', colors.present),
                        _buildSummaryStat('Full Day Absent', '${summary.fullDayAbsentCount}', colors.error),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryStat('On Duty (OD)', '${summary.odCount}', colors.warning),
                        _buildSummaryStat('Partial / Mixed', '${summary.partialCount}', colors.warning),
                        _buildSummaryStat('Not Entered', '${summary.notEnteredCount}', colors.textMuted),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.warningBg,
                  borderRadius: AppRadius.smallBorder,
                  border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.restaurant, size: 16, color: colors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lunch Break: ${summary.lunchInterval} • Not counted',
                        style: TextStyle(fontSize: 11, color: colors.warning, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    final typography = context.typography;
    final colors = context.colors;

    return Column(
      children: [
        Text(
          value,
          style: typography.numericLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: typography.caption.copyWith(color: colors.textMuted)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final filtered = _students.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.fullName.toLowerCase().contains(q) ||
          s.rollNumber.toLowerCase().contains(q);
    }).toList();

    final presentCount = _students.where((s) => s.attendanceStatus == 'PRESENT').length;
    final absentCount = _students.where((s) => s.attendanceStatus == 'ABSENT').length;
    final odCount = _students.where((s) => s.attendanceStatus == 'OD').length;
    final unmarkedCount = _students.where((s) => s.attendanceStatus == 'UNMARKED').length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Advisor: P${widget.periodNumber} ${widget.subjectCode}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload Roster',
            onPressed: _isLoading || _isSubmitting ? null : _loadRoster,
          ),
        ],
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
                          Icon(Icons.error_outline_rounded, size: 48, color: colors.error),
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
                    // Header Banner
                    GlassCard(
                      variant: GlassCardVariant.hero,
                      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                      padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colors.heroChip,
                                  borderRadius: AppRadius.smallBorder,
                                ),
                                child: Text(
                                  'P${widget.periodNumber}',
                                  style: TextStyle(
                                    color: colors.accentOnHero,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  '${widget.subjectName} (${widget.subjectCode})',
                                  style: typography.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colors.onHero,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Class: ${widget.className} | Teacher: ${widget.subjectFacultyName}',
                            style: TextStyle(fontSize: 12, color: colors.onHeroSecondary),
                          ),
                          Text(
                            'Date: ${widget.date} (${widget.dayOfWeek}) | Time: ${widget.periodTime}',
                            style: TextStyle(fontSize: 11, color: colors.onHeroSecondary),
                          ),
                        ],
                      ),
                    ),

                    // Counter Bar & Quick Actions
                    GlassCard(
                      variant: GlassCardVariant.standard,
                      margin: const EdgeInsets.all(AppSpacing.md),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildCounterChip('TOTAL', '${_students.length}', colors.textPrimary),
                              _buildCounterChip('PRESENT', '$presentCount', colors.present),
                              _buildCounterChip('ABSENT', '$absentCount', colors.error),
                              _buildCounterChip('OD', '$odCount', colors.warning),
                              _buildCounterChip('UNMARKED', '$unmarkedCount', colors.textMuted),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1, color: colors.glassBorder),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Search roll no or name...',
                                    prefixIcon: Icon(Icons.search, size: 18, color: colors.textMuted),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                    border: OutlineInputBorder(borderRadius: AppRadius.pillBorder, borderSide: BorderSide(color: colors.glassBorder)),
                                    enabledBorder: OutlineInputBorder(borderRadius: AppRadius.pillBorder, borderSide: BorderSide(color: colors.glassBorder)),
                                    focusedBorder: OutlineInputBorder(borderRadius: AppRadius.pillBorder, borderSide: BorderSide(color: colors.primary, width: 1.5)),
                                    filled: true,
                                    fillColor: colors.glassSurfaceStrong,
                                  ),
                                  onChanged: (val) => setState(() => _searchQuery = val),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.primary,
                                  side: BorderSide(color: colors.primary),
                                  shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                onPressed: _openBatchPhotoPicker,
                                icon: const Icon(Icons.add_a_photo_outlined, size: 14),
                                label: const Text('Batch Photos', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 4),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.present,
                                  side: BorderSide(color: colors.present),
                                  shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                onPressed: () => _markAll('PRESENT'),
                                child: const Text('All Present', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 4),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.error,
                                  side: BorderSide(color: colors.error),
                                  shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                onPressed: () => _markAll('ABSENT'),
                                child: const Text('All Absent', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Student Roster
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 90),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final student = filtered[index];
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            borderColor: cardBorder,
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
                                      if (isOd && student.odReason != null)
                                        Text(
                                          'OD: ${student.odReason}',
                                          style: TextStyle(fontSize: 10, color: colors.warning, fontWeight: FontWeight.w600),
                                        ),
                                    ],
                                  ),
                                ),
                                // Segmented selector: P / A / OD
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildSelectBtn('P', isPresent, colors.present, () => _setStatus(student, 'PRESENT')),
                                    const SizedBox(width: 4),
                                    _buildSelectBtn('A', isAbsent, colors.error, () => _setStatus(student, 'ABSENT')),
                                    const SizedBox(width: 4),
                                    _buildSelectBtn('OD', isOd, colors.warning, () => _setStatus(student, 'OD')),
                                  ],
                                ),
                              ],
                            ),
                          );
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
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded, size: 20),
                    label: Text(
                      _isSubmitting ? 'SAVING...' : 'SAVE ATTENDANCE AS CLASS ADVISOR',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                    ),
                    onPressed: _isSubmitting ? null : _submitAttendance,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCounterChip(String label, String count, Color color) {
    final typography = context.typography;
    final colors = context.colors;

    return Column(
      children: [
        Text(count, style: typography.numericLarge.copyWith(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: typography.caption.copyWith(fontSize: 10, color: colors.textMuted)),
      ],
    );
  }

  Widget _buildSelectBtn(String label, bool isSelected, Color activeColor, VoidCallback onTap) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smallBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : colors.surfaceMuted,
          borderRadius: AppRadius.smallBorder,
          border: Border.all(color: isSelected ? activeColor : colors.glassBorder),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
