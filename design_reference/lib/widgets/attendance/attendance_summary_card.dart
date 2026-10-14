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
        return colors.absent;
      case 'WARNING':
        return colors.warning;
      case 'OK':
      default:
        return colors.primary;
    }
  }

  Widget _buildStatBox(String label, String value, Color color, AppColors colors) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: colors.glassSurfaceStrong,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.glassBorderStrong,
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: colors.textMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
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
    final statusColor = _getStatusColor(colors);
    final isBelow = percentage < minimumRequired && total > 0;
    final isSafe = percentage >= minimumRequired;

    return GlassCard(
      variant: GlassCardVariant.elevated,
      borderRadius: BorderRadius.circular(26),
      padding: const EdgeInsets.all(20),
      borderColor: isBelow
          ? colors.absent.withValues(alpha: 0.5)
          : colors.glassBorderStrong,
      borderWidth: isBelow ? 1.5 : 1.2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row with Title and Policy / Status Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.insights_rounded,
                        size: 13,
                        color: colors.accentStrong,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'OVERALL ATTENDANCE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Min Requirement: ${minimumRequired.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.25),
                    width: 1.1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSafe
                          ? Icons.check_circle_rounded
                          : (status == 'WARNING'
                              ? Icons.warning_amber_rounded
                              : Icons.error_outline_rounded),
                      size: 13,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4.5),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Central Percentage Display with Liquid Progress Bar
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: colors.textPrimary,
                  letterSpacing: -1.8,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Liquid Progress Bar
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final fillFraction = (percentage / 100.0).clamp(0.0, 1.0);
                          final fillWidth = constraints.maxWidth * fillFraction;
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: fillWidth,
                              height: 10,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: isSafe
                                      ? const [
                                          Color(0xFFE8DDD2),
                                          Color(0xFFB59A84),
                                          Color(0xFF5E4233),
                                          Color(0xFF2B1A13),
                                        ]
                                      : const [
                                          Color(0xFFF7DDD2),
                                          Color(0xFFE29A7D),
                                          Color(0xFFBA5A31),
                                          Color(0xFF8A3416),
                                        ],
                                  stops: const [0.0, 0.35, 0.75, 1.0],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isSafe
                                            ? const Color(0xFF2B1A13)
                                            : const Color(0xFFBA5A31))
                                        .withValues(alpha: 0.25),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${present + od} / $total attended',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          '${(100.0 - percentage).clamp(0.0, 100.0).toStringAsFixed(1)}% missed',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: colors.absent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

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
                _buildStatBox('Half-Day Present', '$halfDayPresent', colors.accentStrong, colors),
                const SizedBox(width: 8),
                _buildStatBox('Half-Day Absent', '$halfDayAbsent', colors.absent, colors),
              ],
            ),
          ],

          // Alert Message Banner
          if (alertMessage != null && alertMessage!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.14),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSafe ? Icons.verified_rounded : Icons.info_outline_rounded,
                    size: 16,
                    color: isSafe ? colors.accentStrong : colors.absent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alertMessage!,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
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
