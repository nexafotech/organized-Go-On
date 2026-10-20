import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../utils/timezone_utils.dart';
import '../../widgets/widgets.dart';

/// Notification History Screen for Students and Faculty
class FacultyNotificationHistoryScreen extends StatefulWidget {
  const FacultyNotificationHistoryScreen({Key? key}) : super(key: key);

  @override
  State<FacultyNotificationHistoryScreen> createState() =>
      _FacultyNotificationHistoryScreenState();
}

class _FacultyNotificationHistoryScreenState
    extends State<FacultyNotificationHistoryScreen> {
  final ApiClient _apiClient = ApiClient();
  int _selectedFilterIndex = 0; // 0: All, 1: Unread Only
  Timer? _relativeTimeRefreshTimer;
  bool _hasInitialLoaded = false;

  @override
  void initState() {
    super.initState();
    final notifService = Provider.of<NotificationService>(context, listen: false);
    _hasInitialLoaded = notifService.notifications.isNotEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
    });
    // Periodically refresh relative time labels (e.g. 'Just now' -> '1m ago')
    _relativeTimeRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _relativeTimeRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    final notifService = Provider.of<NotificationService>(context, listen: false);
    try {
      await notifService.fetchNotifications(_apiClient);
      await notifService.refreshUnreadCount(_apiClient);
    } finally {
      if (mounted) {
        setState(() {
          _hasInitialLoaded = true;
        });
      }
    }
  }

  Future<void> _handleMarkRead(NotificationItem item) async {
    if (item.isRead) return;
    final notifService = Provider.of<NotificationService>(context, listen: false);
    await notifService.markAsRead(_apiClient, item.id);
  }

  Future<void> _handleMarkAllRead() async {
    final notifService = Provider.of<NotificationService>(context, listen: false);
    final count = await notifService.markAllAsRead(_apiClient);
    if (mounted && count > 0) {
      NotificationToast.showSuccess(
        context,
        'Marked $count notification(s) as read',
      );
    }
  }

  Future<void> _handleTogglePin(NotificationItem item) async {
    final notifService = Provider.of<NotificationService>(context, listen: false);
    if (item.isPinned) {
      final success = await notifService.unpinNotification(_apiClient, item.id);
      if (mounted && success) {
        NotificationToast.showSuccess(
          context,
          'Notification unpinned',
        );
      }
    } else {
      final success = await notifService.pinNotification(_apiClient, item.id);
      if (mounted && success) {
        NotificationToast.showSuccess(
          context,
          'Notification pinned to top',
        );
      }
    }
  }

  Future<void> _handleDelete(NotificationItem item) async {
    final notifService = Provider.of<NotificationService>(context, listen: false);
    if (notifService.isNotificationPinned(item.id)) {
      if (mounted) {
        NotificationToast.showPinnedWarning(context);
      }
      return;
    }

    final success = await notifService.deleteNotification(_apiClient, item.id);
    if (mounted) {
      if (success) {
        NotificationToast.showSuccess(context, 'Notification deleted');
      } else {
        NotificationToast.showError(context, 'Failed to delete notification');
      }
    }
  }

  Future<void> _handleDeleteAllUnpinned() async {
    final notifService = Provider.of<NotificationService>(context, listen: false);
    final colors = context.colors;

    if (notifService.isBulkDeleting) return;

    final unpinnedCount = notifService.notifications.where((n) => !n.isPinned && !n.isDeleted).length;
    final pinnedCount = notifService.notifications.where((n) => n.isPinned && !n.isDeleted).length;

    if (unpinnedCount == 0) {
      if (mounted) {
        if (pinnedCount > 0) {
          NotificationToast.showWarning(
            context,
            'All active notifications are pinned. Unpin notifications first to delete them.',
          );
        } else {
          NotificationToast.showInfo(
            context,
            'No notifications to delete.',
          );
        }
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.glassBorder),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delete_sweep_rounded, color: colors.error, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Delete Unpinned?',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete all $unpinnedCount unpinned notification${unpinnedCount > 1 ? 's' : ''}?',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colors.warning.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.push_pin_rounded, size: 16, color: colors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pinnedCount > 0
                            ? '$pinnedCount pinned notification${pinnedCount > 1 ? 's' : ''} will be kept safe at the top.'
                            : 'Pinned notifications are always kept safe.',
                        style: TextStyle(
                          color: colors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                'Delete ($unpinnedCount)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final result = await notifService.deleteAllUnpinnedNotifications(_apiClient);
      if (mounted) {
        if (result['success'] == true) {
          final deleted = result['deleted_count'] ?? unpinnedCount;
          final pinnedKept = result['pinned_preserved_count'] ?? pinnedCount;
          NotificationToast.showSuccess(
            context,
            'Deleted $deleted unpinned notification${deleted != 1 ? 's' : ''} ($pinnedKept pinned preserved)',
            duration: const Duration(seconds: 3),
          );
        } else {
          NotificationToast.showError(
            context,
            result['message'] ?? 'Failed to delete unpinned notifications',
          );
        }
      }
    }
  }

  void _handleItemTap(NotificationItem item) async {
    if (!item.isRead) {
      await _handleMarkRead(item);
    }
    final route = item.targetRoute;
    if (route != null && mounted) {
      final notifService = Provider.of<NotificationService>(context, listen: false);
      notifService.navigateForData(item.parsedData);
    }
  }

  void _showNotificationDetails(NotificationItem item) {
    if (!item.isRead) {
      _handleMarkRead(item);
    }
    final colors = context.colors;
    final channelColor = _getChannelColor(item.channelId, colors);
    final channelName = _getChannelName(item.channelId);
    final channelIcon = _getChannelIcon(item.channelId);
    final isHigh = item.isHighPriority;
    final route = item.targetRoute;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: colors.border.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag indicator
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title bar with close button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: channelColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(channelIcon, size: 20, color: channelColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            channelName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: channelColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Notification Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: colors.textSecondary,
                      onPressed: () => Navigator.of(ctx).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Content scroll view
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges row
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (isHigh)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: colors.error.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                'HIGH PRIORITY',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: colors.error,
                                ),
                              ),
                            ),
                          if (item.isPinned)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: colors.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.push_pin_rounded, size: 11, color: colors.warning),
                                  const SizedBox(width: 4),
                                  Text(
                                    'PINNED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: colors.warning,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: colors.border.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              item.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Title
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Timestamp Card (Exact IST Date & Time + Relative Time)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors.border.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.schedule_rounded, size: 16, color: colors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Standard Indian Time (IST)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        TimezoneUtils.formatIstDateTime(item.createdAt),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    item.relativeTime,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (item.readAt != null) ...[
                              const SizedBox(height: 8),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.done_all_rounded, size: 14, color: colors.present),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Read: ${TimezoneUtils.formatIstDateTime(item.readAt)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Message Body
                      Text(
                        'Message',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors.border.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Text(
                          item.body,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      if (route != null && route.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _handleItemTap(item);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: channelColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: channelColor.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.open_in_new_rounded, size: 15, color: channelColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Linked destination: ${item.targetRoute ?? ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: channelColor,
                                    ),
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: channelColor),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.border.withValues(alpha: 0.15))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _handleDelete(item);
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _handleTogglePin(item);
                      },
                      icon: Icon(
                        item.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                        size: 16,
                      ),
                      label: Text(item.isPinned ? 'Unpin' : 'Pin'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.warning,
                        side: BorderSide(color: colors.warning.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimeAgo(DateTime dt) {
    return TimezoneUtils.formatRelativeTime(dt);
  }

  IconData _getChannelIcon(String channelId) {
    switch (channelId) {
      case 'GO_ON_ADMIN':
        return Icons.campaign_rounded;
      case 'GO_ON_NEXT_CLASS':
        return Icons.schedule_rounded;
      case 'GO_ON_ATTENDANCE':
        return Icons.how_to_reg_rounded;
      case 'GO_ON_ACCOUNT':
        return Icons.security_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getChannelColor(String channelId, AppColors colors) {
    switch (channelId) {
      case 'GO_ON_ADMIN':
        return colors.primary;
      case 'GO_ON_NEXT_CLASS':
        return colors.warning;
      case 'GO_ON_ATTENDANCE':
        return colors.present;
      case 'GO_ON_ACCOUNT':
        return colors.od;
      default:
        return colors.textSecondary;
    }
  }

  String _getChannelName(String channelId) {
    switch (channelId) {
      case 'GO_ON_ADMIN':
        return 'Announcement';
      case 'GO_ON_NEXT_CLASS':
        return 'Timetable';
      case 'GO_ON_ATTENDANCE':
        return 'Attendance';
      case 'GO_ON_ACCOUNT':
        return 'Account';
      default:
        return 'General';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final notifService = Provider.of<NotificationService>(context);

    final activeNotifications = notifService.notifications.where((n) => !n.isDeleted).toList();
    final int allCount = activeNotifications.length;
    final int unreadCount = activeNotifications.where((n) => !n.isRead).length;

    final displayedNotifications = _selectedFilterIndex == 1
        ? activeNotifications.where((n) => !n.isRead).toList()
        : activeNotifications;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.notifications_active_rounded, size: 22),
              const SizedBox(width: 8),
              const Text('Notifications'),
              if (unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$unreadCount',
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        elevation: 0,
        actions: [
          if (unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all_rounded, size: 20),
              tooltip: 'Mark all as read',
              padding: const EdgeInsets.all(5),
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              onPressed: _handleMarkAllRead,
            ),
          IconButton(
            icon: notifService.isBulkDeleting
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.textSecondary,
                    ),
                  )
                : const Icon(Icons.delete_outline_rounded, size: 20),
            tooltip: 'Delete all unpinned notifications',
            padding: const EdgeInsets.all(5),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: notifService.isBulkDeleting ? null : _handleDeleteAllUnpinned,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh',
            padding: const EdgeInsets.all(5),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: _loadNotifications,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs (All vs Unread)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colors.glassSurfaceStrong,
              border: Border(bottom: BorderSide(color: colors.glassBorder)),
            ),
            child: Row(
              children: [
                _buildFilterChip(
                  0,
                  'All',
                  allCount,
                  colors,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(1, 'Unread', unreadCount, colors),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Swipe: ⇦ delete • pin ⇨',
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content Area
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadNotifications,
              color: colors.primary,
              child: _buildBody(displayedNotifications, notifService, colors),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label, int count, AppColors colors) {
    final isSelected = _selectedFilterIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilterIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : colors.glassSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? colors.primary : colors.glassBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? colors.onPrimary : colors.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.onPrimary.withValues(alpha: 0.25)
                      : colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? colors.onPrimary : colors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    List<NotificationItem> items,
    NotificationService notifService,
    AppColors colors,
  ) {
    if ((notifService.isLoading || !_hasInitialLoaded) && notifService.notifications.isEmpty && notifService.errorMessage == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colors.primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Loading notifications...',
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (notifService.errorMessage != null && items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 54, color: colors.warning),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Unable to load notifications',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                notifService.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: _loadNotifications,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _selectedFilterIndex == 1
                    ? Icons.mark_email_read_rounded
                    : Icons.notifications_none_rounded,
                size: 64,
                color: colors.textMuted.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _selectedFilterIndex == 1
                    ? 'No unread notifications'
                    : 'No notifications yet',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _selectedFilterIndex == 1
                    ? 'All your notifications have been marked as read.'
                    : 'Class updates and announcements will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildNotificationCard(item, notifService, colors);
      },
    );
  }

  Widget _buildNotificationCard(
    NotificationItem item,
    NotificationService notifService,
    AppColors colors,
  ) {
    final channelColor = _getChannelColor(item.channelId, colors);
    final channelName = _getChannelName(item.channelId);
    final icon = _getChannelIcon(item.channelId);

    return Dismissible(
      key: ValueKey('notif_card_${item.id}'),
      direction: DismissDirection.horizontal,
      // Swipe Right -> Pin / Unpin
      background: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: colors.warning.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              item.isPinned ? 'Unpin' : 'Pin to Top',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      // Swipe Left -> Delete
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: colors.error.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_forever_rounded, color: Colors.white, size: 24),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe Right: Pin or Unpin
          // Return false so widget snaps back cleanly to its slot,
          // then update pin state post-frame to eliminate in-flight tree mutation during gesture
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleTogglePin(item);
          });
          return false;
        } else if (direction == DismissDirection.endToStart) {
          // Swipe Left: Delete
          if (notifService.isNotificationPinned(item.id)) {
            // Strictly protect pinned notifications from deletion
            NotificationToast.showPinnedWarning(context);
            return false;
          }
          // Immediately and synchronously unregister from local list before tree rebuild
          notifService.removeNotificationLocally(item.id);
          return true;
        }
        return false;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          // Persist deletion to backend
          _handleDelete(item);
        }
      },
      child: GlassCard(
        variant: item.isRead ? GlassCardVariant.standard : GlassCardVariant.elevated,
        enableBlur: false,
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        borderColor: item.isPinned
            ? colors.warning.withValues(alpha: 0.6)
            : (!item.isRead ? channelColor.withValues(alpha: 0.4) : null),
        child: InkWell(
          onTap: () => _showNotificationDetails(item),
          borderRadius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Badges on left (Wrap) and Trailing Actions on right
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: channelColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: channelColor.withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 12, color: channelColor),
                              const SizedBox(width: 4),
                              Text(
                                channelName.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: channelColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (item.isPinned)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: colors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: colors.warning.withValues(alpha: 0.5),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.push_pin_rounded, size: 11, color: colors.warning),
                                const SizedBox(width: 3),
                                Text(
                                  'PINNED',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: colors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (item.isHighPriority)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'HIGH',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: colors.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: TimezoneUtils.formatIstDateTime(item.createdAt),
                        child: Text(
                          _formatTimeAgo(item.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      if (!item.isRead) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: channelColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: channelColor.withValues(alpha: 0.6),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                      PopupMenuButton<String>(
                        key: ValueKey('notif_menu_${item.id}'),
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        tooltip: 'Options',
                        onSelected: (action) {
                          switch (action) {
                            case 'details':
                              _showNotificationDetails(item);
                              break;
                            case 'pin':
                              _handleTogglePin(item);
                              break;
                            case 'read':
                              _handleMarkRead(item);
                              break;
                            case 'delete':
                              if (item.isPinned) {
                                NotificationToast.showPinnedWarning(context);
                                return;
                              }
                              _handleDelete(item);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'details',
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 16, color: colors.primary),
                                const SizedBox(width: 8),
                                const Text('View Details'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'pin',
                            child: Row(
                              children: [
                                Icon(
                                  item.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                                  size: 16,
                                  color: colors.warning,
                                ),
                                const SizedBox(width: 8),
                                Text(item.isPinned ? 'Unpin' : 'Pin to Top'),
                              ],
                            ),
                          ),
                          if (!item.isRead)
                            PopupMenuItem(
                              value: 'read',
                              child: Row(
                                children: [
                                  Icon(Icons.done_rounded, size: 16, color: colors.primary),
                                  const SizedBox(width: 8),
                                  const Text('Mark as Read'),
                                ],
                              ),
                            ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  item.isPinned ? Icons.lock_outline_rounded : Icons.delete_outline_rounded,
                                  size: 16,
                                  color: item.isPinned ? colors.textSecondary : colors.error,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item.isPinned ? 'Protected (Pinned)' : 'Delete',
                                  style: TextStyle(color: item.isPinned ? colors.textSecondary : colors.error),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title with Pinned Indicator
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.isPinned) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 6),
                      child: Icon(
                        Icons.push_pin_rounded,
                        size: 16,
                        color: colors.warning,
                      ),
                    ),
                  ],
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Body
              Text(
                item.body,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: item.isRead
                      ? colors.textSecondary
                      : colors.textPrimary.withValues(alpha: 0.9),
                ),
              ),

              // Tap to View Action
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showNotificationDetails(item),
                  icon: Icon(Icons.arrow_forward_rounded, size: 14, color: channelColor),
                  label: Text(
                    'Tap to view',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: channelColor,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
