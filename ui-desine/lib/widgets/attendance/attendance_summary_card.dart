import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../common/app_card.dart';

class AttendanceSummaryCard extends StatelessWidget {
  final double percentage;
  final int total;
  final int present;
  final int absent;
  final int od;
  final int halfDayPresent;
  final int halfDayAbsent;
  final String status; // OK, WARNING, CRITICAL, NO_DATA
  final double minimumRequired;
  final String? calculationMode;
  final String? alertMessage;

  const AttendanceSummaryCard({
    Key? key,
    required this.percentage,
    required this.total,
    required this.present,
    required this.absent,
    required this.od,
    this.halfDayPresent = 0,
    this.halfDayAbsent = 0,
    this.status = 'OK',
    this.minimumRequired = 75.0,
    this.calculationMode = 'PERIOD',
    this.alertMessage,
  }) : super(key: key);

  Color _getStatusColor(AppColors colors) {
    switch (status.toUpperCase()) {
      case 'CRITICAL':
        return colors.error;
      case 'WARNING':
        return colors.warning;
      case 'OK':
      default:
        return colors.present;
    }
  }

  Widget _buildStatBox(String label, String value, Color color, AppColors colors) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: colors.glassSurfaceSubtle,
          borderRadius: AppRadius.mediumBorder,
          border: Border.all(color: colors.glassBorder, width: 1),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final statusColor = _getStatusColor(colors);
    final isBelow = percentage < minimumRequired && total > 0;

    return GlassCard(
      variant: GlassCardVariant.elevated,
      borderRadius: AppRadius.cardBorder,
      padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
      borderColor: isBelow ? colors.error.withValues(alpha: 0.5) : colors.glassBorderStrong,
      borderWidth: isBelow ? 1.5 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row with Title and Policy / Status Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OVERALL ATTENDANCE',
                    style: typography.caption.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Min Requirement: ${minimumRequired.toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: statusColor, width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      status == 'OK'
                          ? Icons.check_circle_rounded
                          : (status == 'WARNING' ? Icons.warning_amber_rounded : Icons.error_outline_rounded),
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Central Percentage Display with Progress Bar
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: statusColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (percentage / 100.0).clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: colors.glassSurfaceSubtle,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${present + od} / $total attended',
                          style: TextStyle(fontSize: 11, color: colors.textMuted),
                        ),
                        Text(
                          '${(100.0 - percentage).toStringAsFixed(1)}% missed',
                          style: TextStyle(fontSize: 11, color: colors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stat boxes row 1: Total, Present, Absent, OD
          Row(
            children: [
              _buildStatBox('Total', '$total', colors.textPrimary, colors),
              const SizedBox(width: 8),
              _buildStatBox('Present', '$present', colors.present, colors),
              const SizedBox(width: 8),
              _buildStatBox('Absent', '$absent', colors.absent, colors),
              const SizedBox(width: 8),
              _buildStatBox('OD', '$od', colors.od, colors),
            ],
          ),

          // Stat boxes row 2: Half-Day Present, Half-Day Absent (if any exist)
          if (halfDayPresent > 0 || halfDayAbsent > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatBox('Half-Day Present', '$halfDayPresent', colors.warning, colors),
                const SizedBox(width: 8),
                _buildStatBox('Half-Day Absent', '$halfDayAbsent', colors.error, colors),
              ],
            ),
          ],

          // Alert Message Banner (if any)
          if (alertMessage != null && alertMessage!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alertMessage!,
                      style: TextStyle(fontSize: 11, color: statusColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
