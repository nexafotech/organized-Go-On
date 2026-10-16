import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. APP HEADER
// ─────────────────────────────────────────────────────────────────────────────

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final Widget? titleWidget;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final String? roleChip;
  final Color? backgroundColor;
  final double height;
  final bool showBottomBorder;

  const AppHeader({
    Key? key,
    this.titleWidget,
    this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.roleChip,
    this.backgroundColor,
    this.height = 64.0,
    this.showBottomBorder = false,
  }) : super(key: key);

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final canPop = Navigator.canPop(context);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktopOrLaptop = screenWidth >= 900.0;

    Widget headerRow = Row(
      children: [
        if (leading != null)
          leading!
        else if (canPop)
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, size: AppIconSize.navHeader, color: colors.textPrimary),
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
          ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: titleWidget ??
                        Text(
                          title ?? '',
                          style: typography.titleLarge.copyWith(color: colors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  ),
                  if (roleChip != null && roleChip!.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        borderRadius: AppRadius.pillBorder,
                        border: Border.all(color: colors.borderStrong.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        roleChip!.toUpperCase(),
                        style: typography.caption.copyWith(
                          color: colors.accentStrong,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  style: typography.bodySmall.copyWith(color: colors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (actions != null) ...actions!,
      ],
    );

    if (isDesktopOrLaptop) {
      headerRow = Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040.0),
          child: headerRow,
        ),
      );
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: height + MediaQuery.of(context).padding.top,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            left: AppSpacing.md,
            right: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: backgroundColor ?? colors.surface.withValues(alpha: 0.85),
            border: Border(
              bottom: BorderSide(
                color: showBottomBorder
                    ? colors.glassBorderStrong
                    : colors.border.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: headerRow,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. APP SCAFFOLD
// ─────────────────────────────────────────────────────────────────────────────

class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? header;
  final Widget? floatingBottomBar;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final bool safeArea;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;
  final bool resizeToAvoidBottomInset;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  final bool enableLiquidGlow;

  const AppScaffold({
    Key? key,
    required this.body,
    this.header,
    this.floatingBottomBar,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.safeArea = true,
    this.scrollable = false,
    this.padding,
    this.resizeToAvoidBottomInset = true,
    this.floatingActionButtonLocation,
    this.enableLiquidGlow = true,
  }) : super(key: key);

  static Widget buildLiquidAmbientCanvas([BuildContext? context]) {
    final bool isDark = context != null ? context.colors.isDark : false;
    if (!isDark) {
      return Positioned.fill(
        child: IgnorePointer(
          child: Stack(
            children: [
              // Subtle warm cream/amber highlight (Upper Right)
              Positioned(
                top: -30,
                right: -40,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFB87B4B).withValues(alpha: 0.04),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Subtle soft warm diffusion (Lower Left)
              Positioned(
                bottom: 80,
                left: -50,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFD4C5B3).withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // Ambient Electric Indigo Orb (Upper Right)
            Positioned(
              top: 30,
              right: -60,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6366F1).withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Ambient Liquid Emerald Orb (Mid Left)
            Positioned(
              top: 320,
              left: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF10B981).withValues(alpha: 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Ambient Liquid Radiant Amber Orb (Mid Right)
            Positioned(
              top: 650,
              right: -70,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFF8A00).withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Ambient Liquid Coral Rose Orb (Lower Left)
            Positioned(
              bottom: 140,
              left: -50,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFF43F5E).withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Ambient Liquid Violet Orb (Bottom Center)
            Positioned(
              bottom: -40,
              right: 40,
              child: Container(
                width: 290,
                height: 290,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF8B5CF6).withValues(alpha: 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final defaultHorizontalPadding = AppSpacing.pagePadding(context);
    final effectivePadding = padding ?? EdgeInsets.symmetric(horizontal: defaultHorizontalPadding);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktopOrLaptop = screenWidth >= 900.0;
    final maxContentWidth = isDesktopOrLaptop ? 1040.0 : double.infinity;

    Widget responsiveWrap(Widget child) {
      if (!isDesktopOrLaptop) return child;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: child,
        ),
      );
    }

    Widget content = body;

    if (scrollable) {
      content = SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: effectivePadding,
        child: responsiveWrap(content),
      );
    } else if (padding != null) {
      content = Padding(
        padding: effectivePadding,
        child: responsiveWrap(content),
      );
    } else {
      content = responsiveWrap(content);
    }

    if (safeArea) {
      content = SafeArea(
        top: header == null,
        bottom: floatingBottomBar == null,
        child: content,
      );
    }

    if (floatingBottomBar != null) {
      content = Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 96.0), // Reserve bottom space for floating nav
              child: content,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: isDesktopOrLaptop
                  ? Align(
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 580.0),
                        child: floatingBottomBar!,
                      ),
                    )
                  : floatingBottomBar!,
            ),
          ),
        ],
      );
    }

    final Widget finalBody = enableLiquidGlow
        ? Stack(
            children: [
              buildLiquidAmbientCanvas(context),
              content,
            ],
          )
        : content;

    return Scaffold(
      backgroundColor: backgroundColor ?? colors.background,
      appBar: header,
      bottomNavigationBar: bottomNavigationBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: finalBody,
    );
  }
}
