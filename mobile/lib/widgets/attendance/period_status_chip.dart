import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum PeriodChipSize { compact, normal, large }

class PeriodStatusChip extends StatelessWidget {
  final String status;
  final String? odReason;
  final PeriodChipSize size;
  final bool showLabel;
  final VoidCallback? onTap;

  const PeriodStatusChip({
    Key? key,
    required this.status,
    this.odReason,
    this.size = PeriodChipSize.normal,
    this.showLabel = false,
    this.onTap,
  }) : super(key: key);

  Color _getStatusColor(String s, AppColors colors) {
    switch (s.toUpperCase()) {
      case 'PRESENT':
      case 'P':
        return colors.present;
      case 'ABSENT':
      case 'A':
        return colors.absent;
      case 'OD':
        return colors.od;
      case 'UNCERTAIN':
        return colors.warning;
      case 'LUNCH':
        return colors.textMuted;
      default:
        return colors.textMuted.withValues(alpha: 0.6);
    }
  }

  String _getShortCode(String s) {
    switch (s.toUpperCase()) {
      case 'PRESENT':
      case 'P':
        return 'P';
      case 'ABSENT':
      case 'A':
        return 'A';
      case 'OD':
        return 'OD';
      case 'UNCERTAIN':
        return '?';
      case 'LUNCH':
        return 'L';
      default:
        return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = _getStatusColor(status, colors);
    final shortCode = _getShortCode(status);
    final isLunch = status.toUpperCase() == 'LUNCH';

    double dim;
    double fontSize;
    double radius;

    switch (size) {
      case PeriodChipSize.compact:
        dim = 28.0;
        fontSize = 10.0;
        radius = 6.0;
        break;
      case PeriodChipSize.large:
        dim = 40.0;
        fontSize = 14.0;
        radius = 10.0;
        break;
      case PeriodChipSize.normal:
        dim = 34.0;
        fontSize = 12.0;
        radius = 8.0;
        break;
    }

    Widget chipContent = Container(
      width: showLabel ? null : dim,
      height: dim,
      padding: showLabel ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4) : null,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isLunch
            ? colors.glassSurfaceSubtle
            : color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isLunch
              ? colors.glassBorder
              : color.withValues(alpha: 0.8),
          width: 1.2,
        ),
      ),
      child: Text(
        showLabel
            ? (status == 'OD' && odReason != null && odReason!.isNotEmpty
                ? 'OD ($odReason)'
                : status)
            : shortCode,
        style: TextStyle(
          color: isLunch ? colors.textMuted : color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );

    if (onTap != null) {
      chipContent = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: chipContent,
      );
    }

    if (odReason != null && odReason!.isNotEmpty) {
      return Tooltip(
        message: 'On Duty: $odReason',
        child: chipContent,
      );
    }

    return chipContent;
  }
}
