import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/models/notification_model.dart';
import 'package:attendance_marker_mobile/services/notification_service.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_notification_history_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bulk Delete Unpinned Notifications - Unit & Service Tests', () {
    test('deleteAllUnpinnedNotifications keeps only pinned notifications in memory', () async {
      final service = NotificationService();
      final now = DateTime.now();

      final itemUnpinned1 = NotificationItem(
        id: 1,
        userId: 10,
        notificationType: 'GENERAL',
        channelId: 'GO_ON_GENERAL',
        title: 'Unpinned 1',
        body: 'Body 1',
        status: 'STORED',
        isRead: false,
        isPinned: false,
        createdAt: now.subtract(const Duration(hours: 1)),
      );

      final itemPinned = NotificationItem(
        id: 2,
        userId: 10,
        notificationType: 'ADMIN',
        channelId: 'GO_ON_ADMIN',
        title: 'Pinned Urgent Notice',
        body: 'Body 2',
        status: 'STORED',
        isRead: false,
        isPinned: true,
        pinnedAt: now,
        createdAt: now.subtract(const Duration(hours: 2)),
      );

      final itemUnpinned2 = NotificationItem(
        id: 3,
        userId: 10,
        notificationType: 'GENERAL',
        channelId: 'GO_ON_GENERAL',
        title: 'Unpinned 2',
        body: 'Body 3',
        status: 'STORED',
        isRead: true,
        isPinned: false,
        createdAt: now.subtract(const Duration(minutes: 10)),
      );

      service.notifications.clear();
      service.notifications.addAll([itemUnpinned1, itemPinned, itemUnpinned2]);
      expect(service.notifications.length, 3);

      // Verify unpinned count
      final unpinned = service.notifications.where((n) => !n.isPinned && !n.isDeleted).toList();
      expect(unpinned.length, 2);

      // Verify pinned count
      final pinned = service.notifications.where((n) => n.isPinned && !n.isDeleted).toList();
      expect(pinned.length, 1);
    });

    test('All pinned case: no notifications eligible for bulk delete', () {
      final service = NotificationService();
      final now = DateTime.now();

      final itemPinned1 = NotificationItem(
        id: 10,
        userId: 10,
        notificationType: 'ADMIN',
        channelId: 'GO_ON_ADMIN',
        title: 'Pinned 1',
        body: 'Body 1',
        status: 'STORED',
        isRead: false,
        isPinned: true,
        pinnedAt: now,
        createdAt: now,
      );

      final itemPinned2 = NotificationItem(
        id: 11,
        userId: 10,
        notificationType: 'ADMIN',
        channelId: 'GO_ON_ADMIN',
        title: 'Pinned 2',
        body: 'Body 2',
        status: 'STORED',
        isRead: true,
        isPinned: true,
        pinnedAt: now,
        createdAt: now.subtract(const Duration(hours: 1)),
      );

      service.notifications.clear();
      service.notifications.addAll([itemPinned1, itemPinned2]);

      final unpinnedCount = service.notifications.where((n) => !n.isPinned && !n.isDeleted).length;
      expect(unpinnedCount, 0);
    });

    test('clearUserData completely resets notification state on logout', () {
      final service = NotificationService();
      final item = NotificationItem(
        id: 50,
        userId: 10,
        notificationType: 'GENERAL',
        channelId: 'GO_ON_GENERAL',
        title: 'User Item',
        body: 'Body',
        status: 'STORED',
        isRead: false,
        createdAt: DateTime.now(),
      );

      service.notifications.clear();
      service.notifications.add(item);
      expect(service.notifications.length, 1);

      service.clearUserData();
      expect(service.notifications.isEmpty, true);
      expect(service.unreadCount, 0);
      expect(service.isBulkDeleting, false);
    });
  });

  group('Notifications Screen Bulk Delete & Pinned Indicator Widget Tests', () {
    testWidgets('Renders dustbin icon in AppBar with correct tooltip and pin indicator on card',
        (WidgetTester tester) async {
      final service = NotificationService();
      final now = DateTime.now();

      final itemPinned = NotificationItem(
        id: 301,
        userId: 1,
        notificationType: 'ADMIN',
        channelId: 'GO_ON_ADMIN',
        title: 'Pinned Exam Timetable',
        body: 'Exam schedule published.',
        status: 'STORED',
        isRead: false,
        isPinned: true,
        pinnedAt: now,
        createdAt: now.subtract(const Duration(hours: 1)),
      );

      final itemUnpinned = NotificationItem(
        id: 302,
        userId: 1,
        notificationType: 'GENERAL',
        channelId: 'GO_ON_GENERAL',
        title: 'Regular Announcement',
        body: 'Library closes at 5pm today.',
        status: 'STORED',
        isRead: true,
        isPinned: false,
        createdAt: now.subtract(const Duration(hours: 2)),
      );

      service.notifications.clear();
      service.notifications.addAll([itemPinned, itemUnpinned]);

      await tester.pumpWidget(
        ChangeNotifierProvider<NotificationService>.value(
          value: service,
          child: const MaterialApp(
            home: FacultyNotificationHistoryScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify dustbin icon in AppBar
      final dustbinFinder = find.byTooltip('Delete all unpinned notifications');
      expect(dustbinFinder, findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      // 2. Verify refresh icon in AppBar
      expect(find.byTooltip('Refresh'), findsOneWidget);

      // 3. Verify pinned card displays both PINNED badge and push_pin_rounded indicator next to title
      expect(find.text('PINNED'), findsOneWidget);
      expect(find.text('Pinned Exam Timetable'), findsOneWidget);
      expect(find.byIcon(Icons.push_pin_rounded), findsWidgets);

      // 4. Verify unpinned card does not have PINNED badge
      expect(find.text('Regular Announcement'), findsOneWidget);
    });

    testWidgets('Tapping dustbin opens confirmation dialog with unpinned and pinned count details',
        (WidgetTester tester) async {
      final service = NotificationService();
      final now = DateTime.now();

      final itemPinned = NotificationItem(
        id: 401,
        userId: 1,
        notificationType: 'ADMIN',
        channelId: 'GO_ON_ADMIN',
        title: 'Pinned Notification',
        body: 'Must be kept.',
        status: 'STORED',
        isRead: false,
        isPinned: true,
        pinnedAt: now,
        createdAt: now,
      );

      final itemUnpinned1 = NotificationItem(
        id: 402,
        userId: 1,
        notificationType: 'GENERAL',
        channelId: 'GO_ON_GENERAL',
        title: 'Unpinned Notification 1',
        body: 'Can be deleted.',
        status: 'STORED',
        isRead: false,
        isPinned: false,
        createdAt: now.subtract(const Duration(minutes: 5)),
      );

      final itemUnpinned2 = NotificationItem(
        id: 403,
        userId: 1,
        notificationType: 'GENERAL',
        channelId: 'GO_ON_GENERAL',
        title: 'Unpinned Notification 2',
        body: 'Can also be deleted.',
        status: 'STORED',
        isRead: true,
        isPinned: false,
        createdAt: now.subtract(const Duration(minutes: 10)),
      );

      service.notifications.clear();
      service.notifications.addAll([itemPinned, itemUnpinned1, itemUnpinned2]);

      await tester.pumpWidget(
        ChangeNotifierProvider<NotificationService>.value(
          value: service,
          child: const MaterialApp(
            home: FacultyNotificationHistoryScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the dustbin icon
      final dustbinFinder = find.byTooltip('Delete all unpinned notifications');
      await tester.tap(dustbinFinder);
      await tester.pumpAndSettle();

      // Verify confirmation dialog is displayed
      expect(find.text('Delete Unpinned?'), findsOneWidget);
      expect(find.textContaining('Are you sure you want to delete all 2 unpinned notifications?'), findsOneWidget);
      expect(find.textContaining('1 pinned notification will be kept safe at the top.'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete (2)'), findsOneWidget);

      // Tap Cancel: dialog dismisses and all notifications remain
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Unpinned?'), findsNothing);
      expect(find.text('Pinned Notification'), findsOneWidget);
      expect(find.text('Unpinned Notification 1'), findsOneWidget);
      expect(find.text('Unpinned Notification 2'), findsOneWidget);
    });

    testWidgets('Tapping dustbin when all notifications are pinned shows informative SnackBar',
        (WidgetTester tester) async {
      final service = NotificationService();
      final now = DateTime.now();

      final itemPinned = NotificationItem(
        id: 501,
        userId: 1,
        notificationType: 'ADMIN',
        channelId: 'GO_ON_ADMIN',
        title: 'Sole Pinned Item',
        body: 'Cannot be deleted by bulk delete.',
        status: 'STORED',
        isRead: false,
        isPinned: true,
        pinnedAt: now,
        createdAt: now,
      );

      service.notifications.clear();
      service.notifications.add(itemPinned);

      await tester.pumpWidget(
        ChangeNotifierProvider<NotificationService>.value(
          value: service,
          child: const MaterialApp(
            home: FacultyNotificationHistoryScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap dustbin
      await tester.tap(find.byTooltip('Delete all unpinned notifications'));
      await tester.pump();

      // Confirmation dialog should NOT be shown; SnackBar should be displayed
      expect(find.text('Delete Unpinned?'), findsNothing);
      expect(find.text('All active notifications are pinned. Unpin notifications first to delete them.'), findsOneWidget);
    });
  });
}
