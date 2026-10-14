import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.glassSurfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.glassBorderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.7), width: 1.1),
            ),
            child: Text(
              code,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(width: 5),
            Text(
              '($note)',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 10,
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.glassSurfaceStrong,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.glassBorderStrong,
          width: 1.2,
        ),
        boxShadow: AppGlass.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'ATTENDANCE STATUS LEGEND',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
