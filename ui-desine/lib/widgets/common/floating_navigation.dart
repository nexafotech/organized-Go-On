import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FLOATING NAVIGATION ITEM MODEL
// ─────────────────────────────────────────────────────────────────────────────

class FloatingNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final String? tooltip;

  const FloatingNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.tooltip,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// FLOATING NAVIGATION BAR
// ─────────────────────────────────────────────────────────────────────────────

class FloatingNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FloatingNavItem> items;
  final bool hasRaisedCenterItem;
  final EdgeInsetsGeometry? margin;

  const FloatingNavigation({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.hasRaisedCenterItem = false,
    this.margin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
      child: Container(
        height: 68.0,
        decoration: BoxDecoration(
          borderRadius: AppRadius.pillBorder,
          boxShadow: AppGlass.shadowFloating,
        ),
        child: ClipRRect(
          borderRadius: AppRadius.pillBorder,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: AppGlass.blurStrong, sigmaY: AppGlass.blurStrong),
            child: Container(
              height: 68.0,
              decoration: BoxDecoration(
                color: colors.glassSurfaceStrong,
                gradient: AppGlass.specularGradient,
                borderRadius: AppRadius.pillBorder,
                border: Border.all(color: colors.glassBorderStrong, width: 1.2),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = index == currentIndex;
                  final isCenterRaised = hasRaisedCenterItem && items.length == 5 && index == 2;

                  if (isCenterRaised) {
                    return _buildRaisedCenterItem(context, item, isSelected, () => onTap(index));
                  }

                  final iconData = isSelected ? (item.activeIcon ?? item.icon) : item.icon;

                  return Expanded(
                    child: Semantics(
                      button: true,
                      selected: isSelected,
                      label: '${item.label} tab',
                      child: InkWell(
                        onTap: () => onTap(index),
                        borderRadius: AppRadius.pillBorder,
                        child: Container(
                          height: 52.0,
                          alignment: Alignment.center,
                          child: AnimatedContainer(
                            duration: disableAnimations ? Duration.zero : AppMotion.normal,
                            curve: AppMotion.standard,
                            padding: EdgeInsets.symmetric(
                              horizontal: isSelected ? AppSpacing.md : AppSpacing.xs,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? colors.primary.withValues(alpha: 0.10) : Colors.transparent,
                              borderRadius: AppRadius.pillBorder,
                              border: isSelected
                                  ? Border.all(color: colors.primary.withValues(alpha: 0.18), width: 1)
                                  : null,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  iconData,
                                  size: AppIconSize.navHeader,
                            color: isSelected ? colors.primary : colors.textMuted,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            style: typography.caption.copyWith(
                              fontSize: 10.0,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? colors.primary : colors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  ),
),
);
  }

  Widget _buildRaisedCenterItem(
    BuildContext context,
    FloatingNavItem item,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final colors = context.colors;
    final typography = context.typography;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${item.label} tab (Featured)',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 54.0,
          height: 54.0,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            color: isSelected ? colors.accentStrong : colors.hero,
            shape: BoxShape.circle,
            boxShadow: AppElevation.e2,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? (item.activeIcon ?? item.icon) : item.icon,
                size: AppIconSize.navHeader,
                color: colors.onHero,
              ),
              const SizedBox(height: 1),
              Text(
                item.label,
                style: typography.caption.copyWith(
                  fontSize: 9.0,
                  fontWeight: FontWeight.w700,
                  color: colors.onHero,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
