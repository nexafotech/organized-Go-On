import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/faculty_attendance_model.dart';

/// Data model representing a single summary metric item.
class _DailySummaryMetricItem {
  final String label;
  final String value;
  final Color color;

  const _DailySummaryMetricItem({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// Clean, responsive 6-item daily attendance summary metrics grid.
///
/// On mobile phones: renders a 2-column x 3-row grid where each item has equal width,
/// prominent numeric count, centered multi-line wrapped label, and zero horizontal overlap.
///
/// On tablets/wider screens (width >= 460px): renders a 3-column x 2-row grid.
class DailyAttendanceSummaryMetrics extends StatelessWidget {
  final ClassDailySummaryResponse summary;

  const DailyAttendanceSummaryMetrics({
    Key? key,
    required this.summary,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    // The authoritative six daily summary metrics
    final items = [
      _DailySummaryMetricItem(
        label: 'Full Day Present',
        value: '${summary.fullDayPresentCount}',
        color: colors.present,
      ),
      _DailySummaryMetricItem(
        label: 'Half-Day Present',
        value: '${summary.halfDayPresentCount}',
        color: colors.present,
      ),
      _DailySummaryMetricItem(
        label: 'Full Day Absent',
        value: '${summary.fullDayAbsentCount}',
        color: colors.error,
      ),
      _DailySummaryMetricItem(
        label: 'On Duty (OD)',
        value: '${summary.odCount}',
        color: colors.warning,
      ),
      _DailySummaryMetricItem(
        label: 'Partial / Mixed',
        value: '${summary.partialCount}',
        color: colors.warning,
      ),
      _DailySummaryMetricItem(
        label: 'Not Entered',
        value: '${summary.notEnteredCount}',
        color: colors.textMuted,
      ),
    ];

    // Mobile viewports inside dialogs typically range from 260px to 380px.
    // Use 2 columns by 3 rows on mobile, and 3 columns by 2 rows on wider screens.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bool isWide = screenWidth >= 460;
    final int crossAxisCount = isWide ? 3 : 2;

    final List<Widget> rows = [];
    for (int i = 0; i < items.length; i += crossAxisCount) {
      final chunk = items.sublist(
        i,
        (i + crossAxisCount > items.length) ? items.length : i + crossAxisCount,
      );

      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int j = 0; j < chunk.length; j++) ...[
              if (j > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildMetricTile(chunk[j], colors, typography),
              ),
            ],
          ],
        ),
      );

      if (i + crossAxisCount < items.length) {
        rows.add(const SizedBox(height: AppSpacing.sm));
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _buildMetricTile(
    _DailySummaryMetricItem item,
    AppColors colors,
    AppTypography typography,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.65),
        borderRadius: AppRadius.smallBorder,
        border: Border.all(color: colors.glassBorder, width: 0.8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            item.value,
            textAlign: TextAlign.center,
            style: typography.numericLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: item.color,
              fontSize: 22,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            item.label,
            textAlign: TextAlign.center,
            softWrap: true,
            maxLines: 2,
            style: typography.caption.copyWith(
              color: colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

/// Clean information card for lunch-break interval without duplicated "(Not Counted)" suffix.
class DailyAttendanceLunchBreakCard extends StatelessWidget {
  final String lunchInterval;

  const DailyAttendanceLunchBreakCard({
    Key? key,
    required this.lunchInterval,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
