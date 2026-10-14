import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum AttendanceChipSize { compact, normal, expanded }

class AttendanceStatusChip extends StatelessWidget {
  final String status;
  final String? odReason;
  final AttendanceChipSize size;
  final bool showIcon;
  final bool showLabel;
  final VoidCallback? onTap;

  const AttendanceStatusChip({
    Key? key,
    required this.status,
    this.odReason,
    this.size = AttendanceChipSize.normal,
    this.showIcon = true,
    this.showLabel = false,
    this.onTap,
  }) : super(key: key);

  AppStatusStyle _resolveStyle(AppColors colors, String s) {
    switch (s.trim().toUpperCase()) {
      case 'PRESENT':
      case 'P':
        return colors.presentStyle;
      case 'ABSENT':
      case 'A':
        return colors.absentStyle;
      case 'OD':
      case 'ON_DUTY':
        return colors.odStyle;
      case 'EXCLUDED':
        return colors.excludedStyle;
      case 'SHORT_BREAK':
      case 'BREAK':
        return colors.breakStyle;
      case 'LUNCH':
      case 'LUNCH_BREAK':
        return colors.lunchStyle;
      case 'NOT_ENTERED':
      case 'UNMARKED':
      case '-':
      default:
        return colors.notEnteredStyle;
    }
  }

  String _getShortCode(String s) {
    switch (s.trim().toUpperCase()) {
      case 'PRESENT':
      case 'P':
        return 'P';
      case 'ABSENT':
      case 'A':
        return 'A';
      case 'OD':
      case 'ON_DUTY':
        return 'OD';
      case 'EXCLUDED':
        return 'EX';
      case 'SHORT_BREAK':
      case 'BREAK':
        return 'BR';
      case 'LUNCH':
      case 'LUNCH_BREAK':
        return 'L';
      default:
        return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final style = _resolveStyle(colors, status);
    final shortCode = _getShortCode(status);
    final isLunch = status.trim().toUpperCase().contains('LUNCH');

    double height;
    double? width;
    double fontSize;
    double radius;
    double iconSize;

    switch (size) {
      case AttendanceChipSize.compact:
        height = AppSize.matrixChip.height; // 28
        width = showLabel ? null : AppSize.matrixChip.width; // 28x28
        fontSize = 11.0;
        radius = AppRadius.small;
        iconSize = 12.0;
        break;
      case AttendanceChipSize.expanded:
        height = AppSize.chip; // 32
        width = null;
        fontSize = 12.0;
        radius = AppRadius.medium;
        iconSize = AppIconSize.statusChip;
        break;
      case AttendanceChipSize.normal:
        height = AppSize.chip; // 32
        width = (showLabel || (showIcon && size != AttendanceChipSize.compact)) ? null : 36.0;
        fontSize = 12.0;
        radius = AppRadius.small;
        iconSize = AppIconSize.statusChip;
        break;
    }

    String labelText;
    if (showLabel || size == AttendanceChipSize.expanded) {
      if (status.trim().toUpperCase() == 'OD' && odReason != null && odReason!.isNotEmpty) {
        labelText = 'OD ($odReason)';
      } else {
        labelText = style.label;
      }
    } else {
      labelText = shortCode;
    }

    Widget content = Container(
      width: width,
      height: height,
      padding: EdgeInsets.symmetric(
        horizontal: (width == null) ? AppSpacing.sm : 0,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isLunch ? colors.border : style.fg.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showIcon && (size != AttendanceChipSize.compact || showLabel)) ...[
            Icon(style.icon, size: iconSize, color: style.fg),
            const SizedBox(width: 4),
          ],
          Text(
            labelText,
            style: typography.numericCell.copyWith(
              color: style.fg,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: content,
        ),
      );
    }

    if (odReason != null && odReason!.isNotEmpty) {
      return Tooltip(
        message: 'On Duty: $odReason',
        child: content,
      );
    }

    return content;
  }
}
