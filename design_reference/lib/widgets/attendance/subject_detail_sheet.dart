import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/student_model.dart';

class SubjectDetailSheet extends StatelessWidget {
  final SubjectAttendanceModel subject;

  const SubjectDetailSheet({Key? key, required this.subject}) : super(key: key);

  static void show(BuildContext context, SubjectAttendanceModel subject) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SubjectDetailSheet(subject: subject),
    );
  }

  Color _getPercentageColor(double pct, AppColors colors) {
    if (pct >= 75.0) return colors.present;
    if (pct >= 65.0) return colors.warning;
    return colors.absent;
  }

  Widget _buildStatBox(String label, String value, Color color, AppColors colors) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: colors.glassSurfaceSubtle,
          borderRadius: AppRadius.mediumBorder,
          border: Border.all(color: colors.glassBorder),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: colors.textMuted,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pctColor = _getPercentageColor(subject.percentage, colors);

    return ClipRRect(
      borderRadius: AppRadius.sheetBorder,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: AppGlass.blurSheet, sigmaY: AppGlass.blurSheet),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: colors.glassSurfaceStrong,
            borderRadius: AppRadius.sheetBorder,
            border: Border(
              top: BorderSide(color: colors.glassBorderStrong),
              left: BorderSide(color: colors.glassBorder),
              right: BorderSide(color: colors.glassBorder),
            ),
            boxShadow: AppGlass.shadowFloating,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.glassBorderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.md),

          // Subject Name and Code
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.subjectName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Code: ${subject.subjectCode}',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: pctColor.withValues(alpha: 0.15),
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: pctColor, width: 1.2),
                ),
                child: Text(
                  '${subject.percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: pctColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (subject.percentage / 100.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: colors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation<Color>(pctColor),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Stats row
          Row(
            children: [
              _buildStatBox('Total', '${subject.total}', colors.textPrimary, colors),
              const SizedBox(width: 8),
              _buildStatBox('Present', '${subject.present}', colors.present, colors),
              const SizedBox(width: 8),
              _buildStatBox('Absent', '${subject.absent}', colors.absent, colors),
              const SizedBox(width: 8),
              _buildStatBox('OD', '${subject.od}', colors.od, colors),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Note on policy
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
            decoration: BoxDecoration(
              color: colors.glassSurfaceSubtle,
              borderRadius: AppRadius.mediumBorder,
              border: Border.all(color: colors.glassBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.rule_rounded, size: 18, color: colors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Subject attendance is calculated strictly per period. OD periods are counted as present.',
                    style: TextStyle(fontSize: 11, color: colors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    ),
      ),
    );
  }
}
