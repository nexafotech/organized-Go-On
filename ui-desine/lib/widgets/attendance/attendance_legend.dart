import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../common/app_card.dart';

class AttendanceLegend extends StatelessWidget {
  final bool compact;

  const AttendanceLegend({Key? key, this.compact = false}) : super(key: key);

  Widget _buildLegendItem(
    BuildContext context, {
    required String code,
    required String label,
    required Color color,
    required Color bgColor,
    IconData? icon,
    String? note,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.glassSurfaceSubtle,
        borderRadius: AppRadius.smallBorder,
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
            ),
            child: Text(
              code,
              style: typography.numericCell.copyWith(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: typography.bodySmall.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              '($note)',
              style: typography.caption.copyWith(
                color: colors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return GlassCard(
      variant: GlassCardVariant.muted,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: AppIconSize.statusChip, color: colors.textMuted),
              const SizedBox(width: 6),
              Text(
                'ATTENDANCE STATUS LEGEND',
                style: typography.caption.copyWith(
                  color: colors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 2,
            runSpacing: 2,
            children: [
              _buildLegendItem(
                context,
                code: 'P',
                label: 'Present',
                color: colors.present,
                bgColor: colors.presentBg,
                icon: Icons.check_rounded,
              ),
              _buildLegendItem(
                context,
                code: 'A',
                label: 'Absent',
                color: colors.absent,
                bgColor: colors.absentBg,
                icon: Icons.close_rounded,
              ),
              _buildLegendItem(
                context,
                code: 'OD',
                label: 'On Duty',
                color: colors.od,
                bgColor: colors.odBg,
                note: 'Counted as Present',
                icon: Icons.badge_outlined,
              ),
              _buildLegendItem(
                context,
                code: 'HD-P',
                label: 'Half Day Present',
                color: colors.warning,
                bgColor: colors.warningBg,
              ),
              _buildLegendItem(
                context,
                code: 'HD-A',
                label: 'Half Day Absent',
                color: colors.error,
                bgColor: colors.errorBg,
              ),
              _buildLegendItem(
                context,
                code: 'L',
                label: 'Lunch Break',
                color: colors.lunch,
                bgColor: colors.lunchBg,
                note: '12:50-13:40 Not Counted',
                icon: Icons.restaurant_rounded,
              ),
              _buildLegendItem(
                context,
                code: '-',
                label: 'Not Entered',
                color: colors.notEntered,
                bgColor: colors.notEnteredBg,
                icon: Icons.remove_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
