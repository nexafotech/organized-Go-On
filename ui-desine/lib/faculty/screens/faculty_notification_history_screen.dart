import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../widgets/widgets.dart';

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
        ? notifService.notifications.where((n) => !n.isRead).toList()
        : notifService.notifications;

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
                _buildFilterChip(0, 'All', notifService.notifications.length, colors),
                const SizedBox(width: 8),
                _buildFilterChip(1, 'Unread', notifService.unreadCount, colors),
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
        return _buildNotificationCard(item, colors);
      },
    );
  }

  Widget _buildNotificationCard(NotificationItem item, AppColors colors) {
    final channelColor = _getChannelColor(item.channelId, colors);
    final channelName = _getChannelName(item.channelId);
    final icon = _getChannelIcon(item.channelId);
    final hasRoute = item.targetRoute != null && item.targetRoute!.isNotEmpty;

    return Dismissible(
      key: Key('notif_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white),
      ),
      onDismissed: (_) {
        _handleMarkRead(item);
      },
      child: GlassCard(
        variant: item.isRead ? GlassCardVariant.standard : GlassCardVariant.elevated,
        enableBlur: false,
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        borderColor: !item.isRead ? channelColor.withValues(alpha: 0.4) : null,
        child: InkWell(
          onTap: () => _handleItemTap(item),
          borderRadius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Channel Badge, Priority, Timestamp, Unread Dot
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: channelColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: channelColor.withValues(alpha: 0.3), width: 0.8),
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
                  if (item.isHighPriority) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'HIGH',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: colors.warning,
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
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),

              // Body
              Text(
                item.body,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: item.isRead ? colors.textSecondary : colors.textPrimary.withValues(alpha: 0.9),
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
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: channelColor),
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
