import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
    });
  }

  Future<void> _loadNotifications() async {
    final notifService = Provider.of<NotificationService>(context, listen: false);
    await notifService.fetchNotifications(
      _apiClient,
      unreadOnly: _selectedFilterIndex == 1,
    );
    await notifService.refreshUnreadCount(_apiClient);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked $count notification(s) as read'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleTogglePin(NotificationItem item) async {
    final notifService = Provider.of<NotificationService>(context, listen: false);
    if (item.isPinned) {
      final success = await notifService.unpinNotification(_apiClient, item.id);
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification unpinned'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      final success = await notifService.pinNotification(_apiClient, item.id);
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification pinned to top'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleDelete(NotificationItem item) async {
    final notifService = Provider.of<NotificationService>(context, listen: false);
    final success = await notifService.deleteNotification(_apiClient, item.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Notification deleted' : 'Failed to delete notification',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pinnedCount > 0
                  ? 'All active notifications are pinned. Unpin notifications first to delete them.'
                  : 'No notifications to delete.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Deleted $deleted unpinned notification${deleted != 1 ? 's' : ''} ($pinnedKept pinned preserved)',
              ),
              duration: const Duration(seconds: 3),
              backgroundColor: colors.surface,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] ?? 'Failed to delete unpinned notifications',
              ),
              backgroundColor: colors.error,
              duration: const Duration(seconds: 4),
            ),
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

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
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

    final displayedNotifications = _selectedFilterIndex == 1
        ? notifService.notifications.where((n) => !n.isRead && !n.isDeleted).toList()
        : notifService.notifications.where((n) => !n.isDeleted).toList();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_active_rounded, size: 22),
            const SizedBox(width: 8),
            const Text('Notifications'),
            if (notifService.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${notifService.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        elevation: 0,
        actions: [
          if (notifService.unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              tooltip: 'Mark all as read',
              onPressed: _handleMarkAllRead,
            ),
          IconButton(
            icon: notifService.isBulkDeleting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.textSecondary,
                    ),
                  )
                : const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete all unpinned notifications',
            onPressed: notifService.isBulkDeleting ? null : _handleDeleteAllUnpinned,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadNotifications,
          ),
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
                  notifService.notifications.where((n) => !n.isDeleted).length,
                  colors,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(1, 'Unread', notifService.unreadCount, colors),
                const Spacer(),
                Text(
                  'Swipe left to delete, right to pin',
                  style: TextStyle(
                    color: colors.textSecondary.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
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
        _loadNotifications();
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
                color: isSelected ? Colors.white : colors.textSecondary,
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
                      ? Colors.white.withValues(alpha: 0.25)
                      : colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : colors.primary,
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
    if (notifService.isLoading && items.isEmpty) {
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
    final hasRoute = item.targetRoute != null && item.targetRoute!.isNotEmpty;

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
          onTap: () => _handleItemTap(item),
          borderRadius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Channel Badge, Pinned Badge, Priority, Timestamp, Actions Menu
              Row(
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
                  if (item.isPinned) ...[
                    const SizedBox(width: 6),
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
                  ],
                  if (item.isHighPriority) ...[
                    const SizedBox(width: 6),
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
                  const Spacer(),
                  Text(
                    _formatTimeAgo(item.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textSecondary,
                    ),
                  ),
                  if (!item.isRead) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
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
                  // Accessibility action pop-up menu
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Options',
                    onSelected: (action) {
                      switch (action) {
                        case 'pin':
                          _handleTogglePin(item);
                          break;
                        case 'read':
                          _handleMarkRead(item);
                          break;
                        case 'delete':
                          _handleDelete(item);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
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
                            Icon(Icons.delete_outline_rounded, size: 16, color: colors.error),
                            const SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: colors.error)),
                          ],
                        ),
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

              // Action Bar (if deep link route available)
              if (hasRoute) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _handleItemTap(item),
                    icon: Icon(Icons.arrow_forward_rounded, size: 14, color: channelColor),
                    label: Text(
                      'Open View',
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
            ],
          ),
        ),
      ),
    );
  }
}
