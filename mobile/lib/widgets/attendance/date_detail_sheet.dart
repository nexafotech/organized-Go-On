import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/student_model.dart';
import 'period_status_chip.dart';

class DateDetailSheet extends StatelessWidget {
  final DateWiseEntryModel entry;

  const DateDetailSheet({Key? key, required this.entry}) : super(key: key);

  static void show(BuildContext context, DateWiseEntryModel entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DateDetailSheet(entry: entry),
    );
  }

  Color _getDailyResultColor(String? result, AppColors colors) {
    switch (result?.toUpperCase()) {
      case 'FULL_DAY_PRESENT':
        return colors.present;
      case 'HALF_DAY_PRESENT':
        return colors.warning;
      case 'FULL_DAY_ABSENT':
        return colors.absent;
      case 'OD':
        return colors.od;
      default:
        return colors.textMuted;
    }
  }

  Widget _buildPeriodRow(PeriodEntryModel p, BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.glassSurfaceSubtle,
        borderRadius: AppRadius.mediumBorder,
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.glassSurface,
              borderRadius: AppRadius.smallBorder,
              border: Border.all(color: colors.glassBorder),
            ),
            child: Text(
              p.periodName ?? 'P${p.periodNumber ?? 0}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.subjectName ?? (p.subjectCode ?? 'No Subject Assigned'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (p.subjectCode != null && p.subjectCode!.isNotEmpty)
                  Text(
                    p.subjectCode!,
                    style: TextStyle(fontSize: 11, color: colors.textMuted),
                  ),
                if (p.odReason != null && p.odReason!.isNotEmpty)
                  Text(
                    'OD Reason: ${p.odReason}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.od,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PeriodStatusChip(
            status: p.status,
            odReason: p.odReason,
            showLabel: true,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final morningPeriods = entry.periods.where((p) => (p.periodNumber ?? 0) <= 4).toList();
    final afternoonPeriods = entry.periods.where((p) => (p.periodNumber ?? 0) >= 5).toList();
    final dailyColor = _getDailyResultColor(entry.dailyResult, colors);

    return ClipRRect(
      borderRadius: AppRadius.sheetBorder,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: AppGlass.blurSheet, sigmaY: AppGlass.blurSheet),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
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
            children: [
              // Drag Handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.glassBorderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.date,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Daily Attendance Detail',
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                  ],
                ),
                if (entry.dailyResult != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: dailyColor.withValues(alpha: 0.15),
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(color: dailyColor, width: 1.2),
                    ),
                    child: Text(
                      entry.dailyResult!.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: dailyColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 24, color: colors.border),

          // Scrollable periods list
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Morning Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MORNING SESSION (P1–P4)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (entry.morningSummary != null)
                        Text(
                          entry.morningSummary!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (morningPeriods.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No morning periods recorded.', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                    )
                  else
                    ...morningPeriods.map((p) => _buildPeriodRow(p, context)),

                  const SizedBox(height: 12),

                  // Afternoon Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'AFTERNOON SESSION (P5–P7)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (entry.afternoonSummary != null)
                        Text(
                          entry.afternoonSummary!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (afternoonPeriods.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No afternoon periods recorded.', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                    )
                  else
                    ...afternoonPeriods.map((p) => _buildPeriodRow(p, context)),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
      ),
    );
  }
}
