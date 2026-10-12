import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum PeriodCardState { current, completed, upcoming, locked, breakTime, lunch }

// ─────────────────────────────────────────────────────────────────────────────
// 1. PERIOD CARD
// ─────────────────────────────────────────────────────────────────────────────

class PeriodCard extends StatelessWidget {
  final String periodNumber;
  final String time;
  final String subject;
  final String? subjectCode;
  final String? faculty;
  final String? room;
  final PeriodCardState state;
  final Widget? statusChip;
  final VoidCallback? onTap;

  const PeriodCard({
    Key? key,
    required this.periodNumber,
    required this.time,
    required this.subject,
    this.subjectCode,
    this.faculty,
    this.room,
    this.state = PeriodCardState.upcoming,
    this.statusChip,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    if (state == PeriodCardState.breakTime) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.breakBg.withValues(alpha: 0.75),
          borderRadius: AppRadius.largeBorder,
          border: Border.all(color: colors.breakColor.withValues(alpha: 0.25)),
          boxShadow: AppGlass.shadow,
        ),
        child: Row(
          children: [
            Icon(Icons.coffee_rounded, size: AppIconSize.row, color: colors.breakColor),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SHORT BREAK',
                    style: typography.labelMedium.copyWith(
                      color: colors.breakColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    time,
                    style: typography.bodySmall.copyWith(color: colors.breakColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (state == PeriodCardState.lunch) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.lunchBg.withValues(alpha: 0.75),
          borderRadius: AppRadius.largeBorder,
          border: Border.all(color: colors.lunch.withValues(alpha: 0.25)),
          boxShadow: AppGlass.shadow,
        ),
        child: Row(
          children: [
            Icon(Icons.restaurant_rounded, size: AppIconSize.row, color: colors.lunch),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LUNCH BREAK (Strictly Excluded)',
                    style: typography.labelMedium.copyWith(
                      color: colors.lunch,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    time,
                    style: typography.bodySmall.copyWith(color: colors.lunch),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isCurrent = state == PeriodCardState.current;
    final isLocked = state == PeriodCardState.locked;

    final bg = isCurrent
        ? colors.glassSurfaceHero
        : (isLocked ? colors.glassSurfaceSubtle : colors.glassSurface);
    final gradient = isCurrent
        ? AppGlass.heroSpecularGradient
        : (isLocked ? AppGlass.subtleSpecularGradient : AppGlass.specularGradient);
    final border = isCurrent
        ? Border.all(color: colors.accent.withValues(alpha: 0.38), width: 1.2)
        : Border.all(color: colors.glassBorder, width: 1.0);
    final shadows = isCurrent ? AppGlass.shadowElevated : AppGlass.shadow;
    final fg = isCurrent ? colors.onHero : colors.textPrimary;
    final fgSub = isCurrent ? colors.onHeroSecondary : colors.textSecondary;
    final badgeBg = isCurrent ? colors.heroRaised : colors.surfaceMuted;
    final badgeFg = isCurrent ? colors.accentOnHero : colors.accentStrong;

    Widget card = Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
      decoration: BoxDecoration(
        color: bg,
        gradient: gradient,
        borderRadius: AppRadius.cardBorder,
        border: border,
        boxShadow: shadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: AppRadius.smallBorder,
                    ),
                    child: Text(
                      periodNumber,
                      style: typography.caption.copyWith(
                        color: badgeFg,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    time,
                    style: typography.bodySmall.copyWith(
                      color: fgSub,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.heroChip,
                    borderRadius: AppRadius.pillBorder,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.accentOnHero,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'NOW',
                        style: typography.caption.copyWith(
                          color: colors.onHero,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                )
              else if (statusChip != null)
                statusChip!,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subject,
            style: typography.titleMedium.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subjectCode != null && subjectCode!.isNotEmpty)
            Text(
              subjectCode!,
              style: typography.bodySmall.copyWith(
                color: fgSub,
              ),
            ),
          if (faculty != null || room != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                if (faculty != null) ...[
                  Icon(Icons.person_outline_rounded, size: AppIconSize.statusChip, color: fgSub),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      faculty!,
                      style: typography.bodySmall.copyWith(color: fgSub),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (faculty != null && room != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('•', style: TextStyle(color: fgSub)),
                  ),
                if (room != null) ...[
                  Icon(Icons.room_outlined, size: AppIconSize.statusChip, color: fgSub),
                  const SizedBox(width: 4),
                  Text(
                    room!,
                    style: typography.bodySmall.copyWith(color: fgSub),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        borderRadius: AppRadius.cardBorder,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardBorder,
          child: card,
        ),
      );
    }

    return card;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. TIMETABLE CARD / ITEM
// ─────────────────────────────────────────────────────────────────────────────

class TimetableCard extends StatelessWidget {
  final String period;
  final String time;
  final String subject;
  final String? faculty;
  final String? room;
  final bool isBreak;
  final bool isLunch;
  final VoidCallback? onTap;

  const TimetableCard({
    Key? key,
    required this.period,
    required this.time,
    required this.subject,
    this.faculty,
    this.room,
    this.isBreak = false,
    this.isLunch = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    PeriodCardState state = PeriodCardState.upcoming;
    if (isBreak) state = PeriodCardState.breakTime;
    if (isLunch) state = PeriodCardState.lunch;

    return PeriodCard(
      periodNumber: period,
      time: time,
      subject: subject,
      faculty: faculty,
      room: room,
      state: state,
      onTap: onTap,
    );
  }
}
