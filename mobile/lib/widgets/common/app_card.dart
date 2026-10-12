import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. HERO CARD
// ─────────────────────────────────────────────────────────────────────────────

class HeroCard extends StatelessWidget {
  final Widget? child;
  final String? greeting;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? bottomContent;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const HeroCard({
    Key? key,
    this.child,
    this.greeting,
    this.title,
    this.subtitle,
    this.trailing,
    this.bottomContent,
    this.padding,
    this.borderRadius,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final effectiveBorderRadius = borderRadius ?? AppRadius.cardBorder;

    Widget content = child ??
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (greeting != null && greeting!.isNotEmpty)
                        Text(
                          greeting!,
                          style: typography.bodyMedium.copyWith(
                            color: colors.onHeroSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (title != null && title!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            title!,
                            style: typography.headlineMedium.copyWith(
                              color: colors.onHero,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            subtitle!,
                            style: typography.bodySmall.copyWith(
                              color: colors.onHeroSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            if (bottomContent != null) ...[
              const SizedBox(height: AppSpacing.md),
              bottomContent!,
            ],
          ],
        );

    Widget card = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.heroCardInnerPadding),
      decoration: BoxDecoration(
        color: colors.hero.withValues(alpha: 0.94),
        borderRadius: effectiveBorderRadius,
        border: Border.all(
          color: colors.accent.withValues(alpha: 0.32),
          width: 1.0,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.hero.withValues(alpha: 0.96),
            colors.heroGradientEnd.withValues(alpha: 0.90),
          ],
        ),
      ),
      child: content,
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        borderRadius: effectiveBorderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveBorderRadius,
          splashColor: colors.onHero.withValues(alpha: 0.1),
          highlightColor: colors.onHero.withValues(alpha: 0.05),
          child: card,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: effectiveBorderRadius,
        boxShadow: AppGlass.shadowElevated,
      ),
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: AppGlass.blurStandard, sigmaY: AppGlass.blurStandard),
          child: card,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. GLASS CARD / SURFACE CARD
// ─────────────────────────────────────────────────────────────────────────────

enum GlassCardVariant { standard, elevated, muted, hero }

class GlassCard extends StatelessWidget {
  final Widget child;
  final GlassCardVariant variant;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final Color? customColor;
  final Border? customBorder;
  final double? blur;
  final double? opacity;
  final Color? tint;
  final bool enableBlur;
  final Gradient? customGradient;
  final double borderWidth;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;

  const GlassCard({
    Key? key,
    required this.child,
    this.variant = GlassCardVariant.standard,
    this.padding,
    this.margin,
    this.borderRadius,
    this.onTap,
    this.customColor,
    this.customBorder,
    this.blur,
    this.opacity,
    this.tint,
    this.enableBlur = true,
    this.customGradient,
    this.borderWidth = 1.0,
    this.borderColor,
    this.boxShadow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final effectiveBorderRadius = borderRadius ?? AppRadius.cardBorder;

    Color bg;
    List<BoxShadow> shadows;
    Border? border;
    Gradient? gradient;
    double defaultBlur;

    switch (variant) {
      case GlassCardVariant.elevated:
        bg = customColor ?? colors.glassSurfaceStrong;
        shadows = boxShadow ?? AppGlass.shadowElevated;
        border = customBorder ?? Border.all(color: borderColor ?? colors.glassBorderStrong, width: borderWidth);
        gradient = customGradient ?? AppGlass.specularGradient;
        defaultBlur = AppGlass.blurStrong;
        break;
      case GlassCardVariant.muted:
        bg = customColor ?? colors.glassSurfaceSubtle;
        shadows = boxShadow ?? AppElevation.e0;
        border = customBorder ?? Border.all(color: borderColor ?? colors.border.withValues(alpha: 0.6), width: borderWidth);
        gradient = customGradient ?? AppGlass.subtleSpecularGradient;
        defaultBlur = AppGlass.blurSubtle;
        break;
      case GlassCardVariant.hero:
        bg = customColor ?? colors.glassSurfaceHero;
        shadows = boxShadow ?? AppElevation.e2;
        border = customBorder ?? Border.all(color: borderColor ?? colors.accent.withValues(alpha: 0.32), width: borderWidth);
        gradient = customGradient ?? AppGlass.heroSpecularGradient;
        defaultBlur = AppGlass.blurStrong;
        break;
      case GlassCardVariant.standard:
        bg = customColor ?? colors.glassSurface;
        shadows = boxShadow ?? AppGlass.shadow;
        border = customBorder ?? Border.all(color: borderColor ?? colors.glassBorder, width: borderWidth);
        gradient = customGradient ?? AppGlass.specularGradient;
        defaultBlur = AppGlass.blurStandard;
        break;
    }

    if (opacity != null) {
      bg = bg.withValues(alpha: opacity!);
    }

    if (tint != null) {
      bg = Color.alphaBlend(tint!, bg);
    }

    Widget content = Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.cardInnerPadding),
      decoration: BoxDecoration(
        color: bg,
        gradient: gradient,
        borderRadius: effectiveBorderRadius,
        border: border,
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: effectiveBorderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveBorderRadius,
          splashColor: (variant == GlassCardVariant.hero ? colors.onHero : colors.primary)
              .withValues(alpha: 0.08),
          highlightColor: (variant == GlassCardVariant.hero ? colors.onHero : colors.primary)
              .withValues(alpha: 0.04),
          child: content,
        ),
      );
    }

    final effectiveBlur = blur ?? defaultBlur;

    if (enableBlur && effectiveBlur > 0) {
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: effectiveBorderRadius,
          boxShadow: shadows,
        ),
        child: ClipRRect(
          borderRadius: effectiveBorderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
            child: content,
          ),
        ),
      );
    } else {
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: effectiveBorderRadius,
          boxShadow: shadows,
        ),
        child: ClipRRect(
          borderRadius: effectiveBorderRadius,
          child: content,
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsetsGeometry? padding;

  const SectionHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.action,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Padding(
      padding: padding ??
          const EdgeInsets.only(
            top: AppSpacing.sectionSpacing,
            bottom: AppSpacing.md,
          ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: typography.headlineSmall.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      subtitle!,
                      style: typography.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. STAT CARD
// ─────────────────────────────────────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? statusColor;
  final VoidCallback? onTap;

  const StatCard({
    Key? key,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.statusColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final effectiveColor = statusColor ?? colors.textPrimary;

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      borderRadius: AppRadius.largeBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: typography.caption.copyWith(
                    color: colors.textMuted,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: effectiveColor.withValues(alpha: 0.12),
                    borderRadius: AppRadius.smallBorder,
                    border: Border.all(color: effectiveColor.withValues(alpha: 0.22)),
                  ),
                  child: Icon(
                    icon,
                    size: AppIconSize.statusChip,
                    color: effectiveColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: typography.numeric.copyWith(
              color: effectiveColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: typography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
