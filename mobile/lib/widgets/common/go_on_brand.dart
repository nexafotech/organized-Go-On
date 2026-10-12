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
  const GoOnLogo({Key? key, required this.size}) : super(key: key);

  /// Rendered width/height (the asset is square; aspect ratio is preserved).
  final double size;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
    return Image.asset(
      GoOnBrand.logoAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      cacheWidth: (size * dpr).ceil().clamp(32, 512),
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
