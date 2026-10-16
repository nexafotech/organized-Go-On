import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Official Go-On brand constants. Exact capitalisation: `Go-On`.
class GoOnBrand {
  GoOnBrand._();

  static const String name = 'Go-On';
  static const String logoAsset = 'assets/branding/go_on_logo.png';
  static const String logoSemanticLabel = 'Go-On logo';
}

/// The official Go-On logo (transparent PNG, never recoloured or re-drawn).
///
/// The artwork is light beige/gold, so use it on dark (Espresso) surfaces, or
/// use [GoOnLogoBadge] on light surfaces.
class GoOnLogo extends StatelessWidget {
  const GoOnLogo({Key? key, required this.size, this.color}) : super(key: key);

  /// Rendered width/height (the asset is square; aspect ratio is preserved).
  final double size;

  /// Optional color blend for the logo. If null, the natural PNG artwork is rendered.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
    return Image.asset(
      GoOnBrand.logoAsset,
      width: size,
      height: size,
      color: color,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      cacheWidth: (size * dpr).ceil().clamp(32, 1024),
      semanticLabel: GoOnBrand.logoSemanticLabel,
    );
  }
}

/// Logo on a small Espresso tile - for light (Cream) surfaces such as the
/// dashboard app bar, where the beige logo would otherwise lack contrast.
class GoOnLogoBadge extends StatelessWidget {
  const GoOnLogoBadge({Key? key, this.size = 30}) : super(key: key);

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: context.colors.hero,
        borderRadius: BorderRadius.circular(size * 0.24),
      ),
      child: GoOnLogo(size: size * 0.76),
    );
  }
}

/// Logo + "Go-On" wordmark on a dark (hero) surface.
///
/// [GoOnLockupAxis.vertical]: logo above the name (splash / login).
/// [GoOnLockupAxis.horizontal]: logo beside the name (compact headers).
enum GoOnLockupAxis { vertical, horizontal }

class GoOnLockup extends StatelessWidget {
  const GoOnLockup({
    Key? key,
    this.axis = GoOnLockupAxis.vertical,
    this.logoSize = 88,
    this.fontSize = 28,
    this.color,
  }) : super(key: key);

  final GoOnLockupAxis axis;
  final double logoSize;
  final double fontSize;

  /// Wordmark colour; defaults to `onHero` (the lockup lives on hero surfaces).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final label = Text(
      GoOnBrand.name,
      textAlign: TextAlign.center,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: typography.headlineLarge.copyWith(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: color ?? colors.onHero,
        letterSpacing: 0.6,
      ),
    );

    if (axis == GoOnLockupAxis.horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GoOnLogo(size: logoSize),
          SizedBox(width: logoSize * 0.28),
          Flexible(child: label),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GoOnLogo(size: logoSize),
        SizedBox(height: logoSize * 0.12),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: label,
        ),
      ],
    );
  }
}

/// The authoritative "from NEXAFOTECH" footer branding with flanking accent lines (matching Image 1).
class NexafoBranding extends StatelessWidget {
  const NexafoBranding({
    Key? key,
    this.isDark,
  }) : super(key: key);

  /// Force dark or light mode palette. If null, inferred from context brightness.
  final bool? isDark;

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? (Theme.of(context).brightness == Brightness.dark);
    // Dark mode: Warm champagne gold (#D5CBB8) from Image 1 on Obsidian (#0D0C13)
    // Light mode: Sophisticated espresso bronze (#6B5B50) with high contrast (>6:1) on White (#FFFFFF)
    final textColor = dark ? const Color(0xFFD5CBB8) : const Color(0xFF6B5B50);
    final ruleColor = dark ? const Color(0x99D5CBB8) : const Color(0x806B5B50);

    return Semantics(
      label: 'from NEXAFOTECH',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'from',
            style: TextStyle(
              fontFamily: 'CaviarDreams',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: textColor.withValues(alpha: 0.85),
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 1.2,
                color: ruleColor,
              ),
              const SizedBox(width: 10),
              Text(
                'NEXAFOTECH',
                style: TextStyle(
                  fontFamily: 'CaviarDreams',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: 4.5,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 24,
                height: 1.2,
                color: ruleColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
