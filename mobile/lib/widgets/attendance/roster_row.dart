import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../avatar/user_avatar_widget.dart';
import 'attendance_status_chip.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. STUDENT ROW
// ─────────────────────────────────────────────────────────────────────────────

class StudentRow extends StatelessWidget {
  final String rollNumber;
  final String fullName;
  final Widget? trailing;
  final String? status;
  final VoidCallback? onTap;

  const StudentRow({
    Key? key,
    required this.rollNumber,
    required this.fullName,
    this.trailing,
    this.status,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    Widget row = Container(
      height: AppSize.rosterRow, // 72px
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.divider, width: 1)),
      ),
      child: Row(
        children: [
          UserAvatarWidget(
            fallbackSeed: rollNumber.isNotEmpty ? rollNumber : fullName,
            radius: 20,
            borderWidth: 1.5,
            borderColor: colors.border,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: typography.titleMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  rollNumber,
                  style: typography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (status != null)
            AttendanceStatusChip(
              status: status!,
              size: AttendanceChipSize.compact,
            )
          else if (trailing != null)
            trailing!,
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: row,
        ),
      );
    }

    return row;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. ATTENDANCE ROW (INTERACTIVE MARKING ROW)
// ─────────────────────────────────────────────────────────────────────────────

class AttendanceRow extends StatelessWidget {
  final String rollNumber;
  final String fullName;
  final String currentStatus; // 'PRESENT', 'ABSENT', 'OD', 'NOT_ENTERED'
  final ValueChanged<String>? onStatusChanged;
  final bool isLocked;
  final String? odReason;

  const AttendanceRow({
    Key? key,
    required this.rollNumber,
    required this.fullName,
    required this.currentStatus,
    this.onStatusChanged,
    this.isLocked = false,
    this.odReason,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final isPresent = currentStatus.toUpperCase() == 'PRESENT' || currentStatus.toUpperCase() == 'P';
    final isAbsent = currentStatus.toUpperCase() == 'ABSENT' || currentStatus.toUpperCase() == 'A';
    final isOd = currentStatus.toUpperCase() == 'OD';

    return Container(
      height: AppSize.rosterRow, // 72px
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.divider, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: typography.titleMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      rollNumber,
                      style: typography.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    if (isOd && odReason != null && odReason!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '($odReason)',
                        style: typography.caption.copyWith(
                          color: colors.od,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isLocked)
            AttendanceStatusChip(
              status: currentStatus,
              odReason: odReason,
              size: AttendanceChipSize.normal,
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggleButton(
                  label: 'P',
                  isSelected: isPresent,
                  activeColor: colors.present,
                  activeBg: colors.presentBg,
                  onTap: () => onStatusChanged?.call('PRESENT'),
                  colors: colors,
                ),
                const SizedBox(width: AppSpacing.xs),
                _buildToggleButton(
                  label: 'A',
                  isSelected: isAbsent,
                  activeColor: colors.absent,
                  activeBg: colors.absentBg,
                  onTap: () => onStatusChanged?.call('ABSENT'),
                  colors: colors,
                ),
                const SizedBox(width: AppSpacing.xs),
                _buildToggleButton(
                  label: 'OD',
                  isSelected: isOd,
                  activeColor: colors.od,
                  activeBg: colors.odBg,
                  onTap: () => onStatusChanged?.call('OD'),
                  colors: colors,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required Color activeBg,
    required VoidCallback onTap,
    required AppColors colors,
  }) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Mark $label for $fullName',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: AppSize.minTouchTarget, // 48x48 accessible touch target
          height: AppSize.minTouchTarget,
          alignment: Alignment.center,
          child: Container(
            width: 36.0,
            height: 36.0,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? activeBg : Colors.transparent,
              borderRadius: AppRadius.smallBorder,
              border: Border.all(
                color: isSelected ? activeColor : colors.border,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : colors.textSecondary,
                fontSize: 12.0,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
