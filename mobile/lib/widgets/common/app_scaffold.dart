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

    return Container(
      height: height + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: AppSpacing.md,
        right: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.background,
        border: showBottomBorder
            ? Border(bottom: BorderSide(color: colors.border, width: 1))
            : null,
      ),
      child: Row(
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
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final defaultHorizontalPadding = AppSpacing.pagePadding(context);
    final effectivePadding = padding ?? EdgeInsets.symmetric(horizontal: defaultHorizontalPadding);

    Widget content = body;

    if (scrollable) {
      content = SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: effectivePadding,
        child: content,
      );
    } else if (padding != null) {
      content = Padding(
        padding: effectivePadding,
        child: content,
      );
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
              child: floatingBottomBar!,
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor ?? colors.background,
      appBar: header,
      bottomNavigationBar: bottomNavigationBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: content,
    );
  }
}
