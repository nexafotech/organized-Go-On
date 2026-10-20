import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. PRIMARY BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final double? width;
  final double height;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String? semanticLabel;

  const PrimaryButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.width,
    this.height = AppSize.primaryButton,
    this.backgroundColor,
    this.foregroundColor,
    this.semanticLabel,
  }) : super(key: key);

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.fast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.press),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      if (MediaQuery.maybeOf(context)?.disableAnimations != true) {
        _controller.forward();
      }
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (_controller.status == AnimationStatus.forward || _controller.status == AnimationStatus.completed) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (_controller.status == AnimationStatus.forward || _controller.status == AnimationStatus.completed) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    final bg = widget.backgroundColor ?? colors.primary;
    final fg = widget.foregroundColor ?? colors.onPrimary;

    Widget buttonChild = Row(
      mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        else ...[
          if (widget.icon != null) ...[
            Icon(widget.icon, size: AppIconSize.chip, color: fg),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            widget.text,
            style: typography.labelLarge.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: widget.semanticLabel ?? widget.text,
      child: GestureDetector(
        onTapDown: isEnabled ? _onTapDown : null,
        onTapUp: isEnabled ? _onTapUp : null,
        onTapCancel: isEnabled ? _onTapCancel : null,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: widget.isFullWidth ? double.infinity : widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: colors.isDark ? Colors.black.withValues(alpha: 0.35) : const Color(0x1F2B1A13),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: colors.isDark
                            ? const Color(0xFF818CF8).withValues(alpha: 0.18)
                            : colors.primary.withValues(alpha: 0.12),
                        blurRadius: 20,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton(
              onPressed: isEnabled ? widget.onPressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: bg,
                foregroundColor: fg,
                disabledBackgroundColor: bg.withValues(alpha: 0.35),
                disabledForegroundColor: fg.withValues(alpha: 0.5),
                elevation: 0,
                minimumSize: Size(widget.width ?? (widget.isFullWidth ? double.infinity : AppSize.minTouchTarget), widget.height),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isEnabled
                        ? (colors.isDark ? Colors.white.withValues(alpha: 0.35) : Colors.transparent)
                        : Colors.transparent,
                    width: 1.1,
                  ),
                ),
              ),
              child: buttonChild,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. SECONDARY BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final double? width;
  final double height;
  final Color? borderColor;
  final Color? textColor;
  final String? semanticLabel;

  const SecondaryButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.width,
    this.height = AppSize.secondaryButton,
    this.borderColor,
    this.textColor,
    this.semanticLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isEnabled = onPressed != null && !isLoading;

    final border = borderColor ?? colors.borderStrong;
    final textCol = textColor ?? colors.primary;

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: semanticLabel ?? text,
      child: SizedBox(
        width: isFullWidth ? double.infinity : width,
        height: height,
        child: OutlinedButton(
          onPressed: isEnabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            backgroundColor: colors.glassSurfaceSubtle,
            foregroundColor: textCol,
            disabledForegroundColor: textCol.withValues(alpha: 0.4),
            minimumSize: Size(width ?? (isFullWidth ? double.infinity : AppSize.minTouchTarget), height),
            side: BorderSide(color: isEnabled ? border : border.withValues(alpha: 0.3), width: 1.1),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation<Color>(textCol),
                  ),
                )
              else ...[
                if (icon != null) ...[
                  Icon(icon, size: AppIconSize.chip, color: textCol),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    text,
                    overflow: TextOverflow.ellipsis,
                    style: typography.labelLarge.copyWith(
                      color: textCol,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. ICON BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final double iconSize;
  final Border? border;

  const AppIconButton({
    Key? key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.backgroundColor,
    this.size = AppSize.minTouchTarget,
    this.iconSize = AppIconSize.navHeader,
    this.border,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isEnabled = onPressed != null;

    Widget btn = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: AppRadius.mediumBorder,
        border: border,
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: isEnabled ? (color ?? colors.textPrimary) : colors.textMuted.withValues(alpha: 0.5),
      ),
    );

    if (isEnabled) {
      btn = Material(
        color: Colors.transparent,
        borderRadius: AppRadius.mediumBorder,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.mediumBorder,
          child: btn,
        ),
      );
    }

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(
        message: tooltip!,
        child: btn,
      );
    }

    return btn;
  }
}
