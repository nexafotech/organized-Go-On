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
  }) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5.5),
      decoration: BoxDecoration(
        color: colors.glassSurfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.isDark ? colors.glassBorderStrong : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: color.withValues(alpha: 0.65), width: 1.0),
            ),
            child: Text(
              code,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (icon != null) ...[
            const SizedBox(width: 5),
            Icon(icon, size: 12.5, color: color),
          ],
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'ATTENDANCE STATUS LEGEND',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  'Academic Policy',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
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
                icon: Icons.badge_outlined,
              ),
              _buildLegendItem(
                context,
                code: 'HD-P',
                label: 'Half Day Present',
                color: colors.warning,
                bgColor: colors.warningBg,
                icon: Icons.star_half_rounded,
              ),
              _buildLegendItem(
                context,
                code: 'HD-A',
                label: 'Half Day Absent',
                color: colors.error,
                bgColor: colors.errorBg,
                icon: Icons.hourglass_bottom_rounded,
              ),
              _buildLegendItem(
                context,
                code: 'L',
                label: 'Lunch Break',
                color: colors.lunch,
                bgColor: colors.lunchBg,
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: colors.glassSurfaceSubtle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colors.isDark ? colors.glassBorderStrong : const Color(0xFFE2E8F0),
                width: 0.9,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.policy_outlined, size: 13, color: colors.primary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Policy: On Duty (OD) is credited as Present. Lunch Interval (12:50 PM – 01:40 PM) is non-teaching and strictly excluded from calculation denominators.',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: colors.textMuted,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
