import 'package:flutter/material.dart';

/// Semantic toast types for notification actions and feedback
enum NotificationToastType {
  warning,
  success,
  info,
  error,
}

/// Shared high-contrast notification feedback toast component.
/// Ensures legible, accessible contrast across both Light (Cream & Espresso) and Dark (Obsidian) themes.
class NotificationToast {
  static const Color toastBg = Color(0xFF171417); // Explicit near-black background
  static const Color toastText = Color(0xFFFFFFFF); // Explicit crisp white text
  static const Color warningGold = Color(0xFFF59E0B); // Amber/gold warning icon
  static const Color successGreen = Color(0xFF10B981); // Emerald success icon
  static const Color infoBlue = Color(0xFF818CF8); // Indigo info icon
  static const Color errorRed = Color(0xFFF43F5E); // Crimson error icon

  /// Displays the authoritative pinned notification deletion warning toast
  static void showPinnedWarning(BuildContext context) {
    showWarning(
      context,
      'Pinned notifications cannot be deleted. Unpin first.',
      duration: const Duration(seconds: 2),
    );
  }

  /// Displays a warning toast with amber icon and near-black background
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      type: NotificationToastType.warning,
      duration: duration,
    );
  }

  /// Displays a success toast with emerald check icon and near-black background
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      context,
      message: message,
      type: NotificationToastType.success,
      duration: duration,
    );
  }

  /// Displays an error toast with red error icon and near-black background
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      type: NotificationToastType.error,
      duration: duration,
    );
  }

  /// Displays an informational toast with indigo icon and near-black background
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      context,
      message: message,
      type: NotificationToastType.info,
      duration: duration,
    );
  }

  /// Master method for displaying floating notification snackbars with explicit high-contrast styling
  static void show(
    BuildContext context, {
    required String message,
    NotificationToastType type = NotificationToastType.info,
    Duration duration = const Duration(seconds: 2),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    IconData iconData;
    Color iconColor;

    switch (type) {
      case NotificationToastType.warning:
        iconData = Icons.warning_amber_rounded;
        iconColor = warningGold;
        break;
      case NotificationToastType.success:
        iconData = Icons.check_circle_rounded;
        iconColor = successGreen;
        break;
      case NotificationToastType.error:
        iconData = Icons.error_outline_rounded;
        iconColor = errorRed;
        break;
      case NotificationToastType.info:
        iconData = Icons.info_outline_rounded;
        iconColor = infoBlue;
        break;
    }

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              iconData,
              color: iconColor,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: toastText,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: toastBg,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(
            color: Color(0x28FFFFFF), // 16% subtle white contour border
            width: 0.8,
          ),
        ),
        duration: duration,
      ),
    );
  }
}
