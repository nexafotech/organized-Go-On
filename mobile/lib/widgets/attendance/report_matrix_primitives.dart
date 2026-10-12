import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'attendance_status_chip.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. MATRIX HEADER CELL
// ─────────────────────────────────────────────────────────────────────────────

class MatrixHeaderCell extends StatelessWidget {
  final String text;
  final double width;
  final double height;
  final bool isFixed;

  const MatrixHeaderCell({
    Key? key,
    required this.text,
    this.width = 44.0,
    this.height = AppSize.matrixRow, // 48.0
    this.isFixed = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        border: Border(
          right: BorderSide(color: colors.border, width: 1),
          bottom: BorderSide(color: colors.borderStrong, width: 1.5),
        ),
      ),
      child: Text(
        text,
        style: typography.caption.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. MATRIX DATA CELL
// ─────────────────────────────────────────────────────────────────────────────

class MatrixDataCell extends StatelessWidget {
  final String status;
  final String? odReason;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const MatrixDataCell({
    Key? key,
    required this.status,
    this.odReason,
    this.width = 44.0,
    this.height = AppSize.matrixRow, // 48.0
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: colors.divider, width: 1),
          bottom: BorderSide(color: colors.divider, width: 1),
        ),
      ),
      child: AttendanceStatusChip(
        status: status,
        odReason: odReason,
        size: AttendanceChipSize.compact, // 28x28
        onTap: onTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. MATRIX LUNCH BAND (NON-ATTENDANCE SEPARATOR)
// ─────────────────────────────────────────────────────────────────────────────

class MatrixLunchBand extends StatelessWidget {
  final double width;
  final double height;

  const MatrixLunchBand({
    Key? key,
    this.width = 36.0,
    this.height = AppSize.matrixRow, // 48.0
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.lunchBg.withValues(alpha: 0.6),
        border: Border(
          right: BorderSide(color: colors.border, width: 1),
          left: BorderSide(color: colors.border, width: 1),
          bottom: BorderSide(color: colors.divider, width: 1),
        ),
      ),
      child: Icon(
        Icons.restaurant_rounded,
        size: AppIconSize.statusChip,
        color: colors.lunch.withValues(alpha: 0.7),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. MATRIX ROW CONTAINER
// ─────────────────────────────────────────────────────────────────────────────

class MatrixRowContainer extends StatelessWidget {
  final Widget fixedIdentityCell;
  final List<Widget> periodCells;
  final Widget? summaryCell;
  final double height;
  final bool isEven;

  const MatrixRowContainer({
    Key? key,
    required this.fixedIdentityCell,
    required this.periodCells,
    this.summaryCell,
    this.height = AppSize.matrixRow, // 48.0
    this.isEven = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rowBg = isEven ? colors.surface : colors.surfaceMuted.withValues(alpha: 0.35);

    return Container(
      height: height,
      color: rowBg,
      child: Row(
        children: [
          fixedIdentityCell,
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Row(
                children: [
                  ...periodCells,
                  if (summaryCell != null) summaryCell!,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
