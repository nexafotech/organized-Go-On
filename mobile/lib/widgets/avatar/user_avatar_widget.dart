import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/student_model.dart';

/// UserAvatarWidget — Illustrated Avatar Component for Go-On
/// Renders the user's unique illustrated avatar from the design reference,
/// with support for edit badge, fallback seeds, and custom sizing.
class UserAvatarWidget extends StatelessWidget {
  final String? avatarId;
  final String fallbackSeed;
  final double radius;
  final VoidCallback? onTap;
  final bool showEditBadge;
  final VoidCallback? onEditTap;
  final Color? borderColor;
  final double borderWidth;

  const UserAvatarWidget({
    Key? key,
    this.avatarId,
    this.fallbackSeed = '',
    this.radius = 36,
    this.onTap,
    this.showEditBadge = false,
    this.onEditTap,
    this.borderColor,
    this.borderWidth = 2.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final assetPath = AvatarItemModel.resolveAsset(avatarId, fallbackSeed: fallbackSeed);
    final effectiveBorderColor = borderColor ?? colors.primary.withValues(alpha: 0.35);

    Widget avatarCore = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.isDark ? const Color(0xFF1E222B) : const Color(0xFFF3F2EE),
        border: Border.all(
          color: effectiveBorderColor,
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.35 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          assetPath,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Graceful fallback to initial letter if image cannot load
            final initial = fallbackSeed.isNotEmpty ? fallbackSeed[0].toUpperCase() : 'U';
            return Container(
              color: colors.primary.withValues(alpha: 0.15),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: radius * 0.8,
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
            );
          },
        ),
      ),
    );

    if (onTap != null) {
      avatarCore = GestureDetector(
        onTap: onTap,
        child: avatarCore,
      );
    }

    if (!showEditBadge) {
      return avatarCore;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatarCore,
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: onEditTap ?? onTap,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.isDark ? const Color(0xFF15181E) : Colors.white,
                  width: 2.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.edit_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
