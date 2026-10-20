import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_tokens.dart';
import '../../faculty/screens/faculty_notification_history_screen.dart';
import '../../services/notification_service.dart';

/// Reusable Notification Bell Icon Widget with live unread badge.
///
/// Features:
/// - Guaranteed accessible touch target (min 42x42).
/// - Unread badge positioned at the top-right corner with `Clip.none`
///   so it never obscures or overlaps the bell icon body.
/// - Auto-expanding pill shape that accommodates single, double, or triple
///   digit unread counts without clipping or distorting.
/// - Wrapped with `IgnorePointer` on the badge so taps anywhere on the
///   icon or badge register cleanly and reliably.
/// - Awaits the notification history route and automatically refreshes
///   the authoritative unread count upon return to the dashboard.
/// - Graceful fallback if Provider<NotificationService> is unavailable
///   (e.g., in isolated widget tests).
class NotificationBellWidget extends StatelessWidget {
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? badgeColor;
  final Color? badgeBorderColor;
  final double iconSize;
  final VoidCallback? onCustomTap;

  const NotificationBellWidget({
    Key? key,
    this.activeColor,
    this.inactiveColor,
    this.badgeColor,
    this.badgeBorderColor,
    this.iconSize = 22.0,
    this.onCustomTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    NotificationService? notifService;
    try {
      notifService = Provider.of<NotificationService>(context);
    } catch (_) {
      notifService = null;
    }

    final unread = notifService?.unreadCount ?? 0;
    final bellColor = unread > 0
        ? (activeColor ?? colors.accent)
        : (inactiveColor ?? colors.textSecondary);

    return Semantics(
      button: true,
      label: unread > 0
          ? 'Notifications, $unread unread'
          : 'Notifications, no unread',
      child: Tooltip(
        message: unread > 0
            ? 'Notifications ($unread unread)'
            : 'Notifications',
        child: SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                icon: Icon(
                  unread > 0
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_outlined,
                  color: bellColor,
                  size: iconSize,
                ),
                onPressed: () async {
                  if (onCustomTap != null) {
                    onCustomTap!();
                    return;
                  }
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FacultyNotificationHistoryScreen(),
                    ),
                  );
                  if (context.mounted && notifService != null) {
                    try {
                      await notifService.refreshUnreadCount(ApiClient());
                    } catch (_) {}
                  }
                },
              ),
              if (unread > 0)
                Positioned(
                  top: 2,
                  right: 2,
                  child: IgnorePointer(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: unread > 9 ? 4.5 : 0.0,
                        vertical: 1.0,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 17,
                        minHeight: 17,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor ?? colors.error,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: badgeBorderColor ?? colors.surface,
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          unread > 999 ? '999+' : '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            height: 1.1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
