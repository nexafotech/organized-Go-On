import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../widgets/widgets.dart';
import '../../models/recognition_model.dart';
import '../../services/faculty_service.dart';

class RecognitionReviewScreen extends StatefulWidget {
  final RecognitionResultModel recognitionResult;

  const RecognitionReviewScreen({
    Key? key,
    required this.recognitionResult,
  }) : super(key: key);

  @override
  State<RecognitionReviewScreen> createState() => _RecognitionReviewScreenState();
}

class _RecognitionReviewScreenState extends State<RecognitionReviewScreen> {
  // Selected high-confidence student IDs
  late Set<int> _selectedHighConfidenceIds;

  // Selected uncertain match student IDs (map from faceIndex -> selected studentId or null)
  final Map<int, int?> _uncertainSelections = {};

  bool _isConfirming = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedHighConfidenceIds = widget.recognitionResult.highConfidenceMatches
        .map((m) => m.studentId)
        .toSet();

    // Initialize uncertain matches with no pre-selection (must be explicitly reviewed)
    for (var u in widget.recognitionResult.uncertainMatches) {
      _uncertainSelections[u.faceIndex] = null;
    }
  }

  /// Get deduplicated set of all confirmed student IDs
  Set<int> _getFinalConfirmedStudentIds() {
    final Set<int> confirmed = Set.from(_selectedHighConfidenceIds);
    for (var studentId in _uncertainSelections.values) {
      if (studentId != null) {
        confirmed.add(studentId);
      }
    }
    return confirmed;
  }

  Future<void> _submitConfirmation() async {
    final colors = context.colors;
    final confirmedIds = _getFinalConfirmedStudentIds();
    if (confirmedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students selected for attendance confirmation')),
      );
      return;
    }

    setState(() {
      _isConfirming = true;
      _errorMessage = null;
    });

    final facultyService = Provider.of<FacultyService>(context, listen: false);
    try {
      await facultyService.confirmRecognition(confirmedIds.toList());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance recorded for ${confirmedIds.length} student(s)'),
          backgroundColor: colors.present,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConfirming = false;
        _errorMessage = facultyService.errorMessage ?? e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage ?? 'Failed to confirm attendance'),
          backgroundColor: colors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final result = widget.recognitionResult;
    final confirmedCount = _getFinalConfirmedStudentIds().length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Recognition Results'),
      ),
      body: Column(
        children: [
          // Summary Header Bar
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.glassSurfaceStrong,
              border: Border(bottom: BorderSide(color: colors.glassBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryBadge('Faces', '${result.facesDetected}', colors.textPrimary),
                _buildSummaryBadge('High Match', '${result.highConfidenceMatches.length}', colors.present),
                _buildSummaryBadge('Uncertain', '${result.uncertainMatches.length}', colors.warning),
                _buildSummaryBadge('Unknown', '${result.unknownFacesCount}', colors.error),
              ],
            ),
          ),

          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.errorBg,
                border: Border(bottom: BorderSide(color: colors.error.withValues(alpha: 0.3))),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: colors.error),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: typography.bodySmall.copyWith(color: colors.error),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // HIGH CONFIDENCE MATCHES SECTION
                if (result.highConfidenceMatches.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: colors.present, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'High-Confidence Matches',
                          style: typography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...result.highConfidenceMatches.map((m) {
                    final isChecked = _selectedHighConfidenceIds.contains(m.studentId);
                    return GlassCard(
                      variant: GlassCardVariant.standard,
                      enableBlur: false, // Smooth scroll list rule
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                      borderColor: isChecked ? colors.present.withValues(alpha: 0.4) : colors.glassBorder,
                      child: CheckboxListTile(
                        value: isChecked,
                        activeColor: colors.present,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
                        title: Text(
                          m.fullName,
                          style: typography.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Roll: ${m.rollNumber}',
                                style: typography.caption.copyWith(color: colors.textMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.presentBg,
                                borderRadius: AppRadius.pillBorder,
                                border: Border.all(color: colors.present.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                '${m.confidence.toStringAsFixed(1)}% match',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: colors.present,
                                ),
                              ),
                            ),
                          ],
                        ),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedHighConfidenceIds.add(m.studentId);
                            } else {
                              _selectedHighConfidenceIds.remove(m.studentId);
                            }
                          });
                        },
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // UNCERTAIN MATCHES SECTION
                if (result.uncertainMatches.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.help_outline_rounded, color: colors.warning, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Uncertain Matches (Faculty Review Required)',
                          style: typography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...result.uncertainMatches.map((u) {
                    final selectedCandidateId = _uncertainSelections[u.faceIndex];
                    return GlassCard(
                      variant: GlassCardVariant.standard,
                      enableBlur: false, // Smooth scroll list rule
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
                      borderColor: colors.warning.withValues(alpha: 0.4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colors.warningBg,
                                  borderRadius: AppRadius.smallBorder,
                                ),
                                child: Text(
                                  'Face #${u.faceIndex + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: colors.warning,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Select Candidate Identity:',
                                style: typography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (u.candidates.isEmpty)
                            Text('No close candidates found', style: TextStyle(color: colors.textMuted))
                          else
                            RadioGroup<int?>(
                              groupValue: selectedCandidateId,
                              onChanged: (val) {
                                setState(() {
                                  _uncertainSelections[u.faceIndex] = val;
                                });
                              },
                              child: Column(
                                children: [
                                  ...u.candidates.map((candidate) {
                                    return RadioListTile<int?>.adaptive(
                                      title: Text(
                                        '${candidate.fullName} (${candidate.rollNumber})',
                                        style: typography.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Confidence: ${candidate.confidence.toStringAsFixed(1)}%',
                                        style: typography.caption.copyWith(color: colors.textMuted),
                                      ),
                                      value: candidate.studentId,
                                      activeColor: colors.primary,
                                    );
                                  }),
                                  RadioListTile<int?>.adaptive(
                                    title: Text(
                                      'Mark as Unknown / Ignore',
                                      style: TextStyle(color: colors.textMuted),
                                    ),
                                    value: null,
                                    activeColor: colors.textMuted,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // UNKNOWN FACES SECTION
                if (result.unknownFacesCount > 0) ...[
                  GlassCard(
                    variant: GlassCardVariant.muted,
                    borderColor: colors.error.withValues(alpha: 0.3),
                    padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
                    child: Row(
                      children: [
                        Icon(Icons.person_off_rounded, color: colors.error, size: 24),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            '${result.unknownFacesCount} face(s) were detected but could not be matched against enrolled student records.',
                            style: typography.bodySmall.copyWith(color: colors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),

          // Confirm Attendance Footer Action Button
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
                  icon: _isConfirming
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(
                    _isConfirming
                        ? 'Confirming...'
                        : 'Confirm Attendance ($confirmedCount Selected)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                  ),
                  onPressed: _isConfirming ? null : _submitConfirmation,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBadge(String label, String value, Color color) {
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
        Text(
          label,
          style: typography.caption.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}
