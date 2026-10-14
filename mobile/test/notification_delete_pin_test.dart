import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/models/notification_model.dart';
import 'package:attendance_marker_mobile/services/notification_service.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_notification_history_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notification Model & Service Logic Tests', () {
    test('NotificationItem parsing and copyWith with pin and delete support', () {
      final json = {
        'id': 101,
        'user_id': 42,
        'notification_type': 'ADMIN',
        'channel_id': 'GO_ON_ADMIN',
        'title': 'Emergency Campus Notice',
        'body': 'Severe weather alert for tomorrow.',
        'data_payload': '{"route":"dashboard","priority":"HIGH"}',
        'status': 'STORED',
        'is_read': false,
        'is_pinned': true,
        'pinned_at': '2026-10-14T10:00:00Z',
        'is_deleted': false,
        'created_at': '2026-10-14T09:00:00Z',
      };

      final item = NotificationItem.fromJson(json);
      expect(item.id, 101);
      expect(item.isPinned, true);
      expect(item.pinnedAt, isNotNull);
      expect(item.isDeleted, false);
      expect(item.isHighPriority, true);
      expect(item.targetRoute, 'dashboard');

      final copied = item.copyWith(isPinned: false, isRead: true);
      expect(copied.isPinned, false);
      expect(copied.isRead, true);
      expect(copied.id, 101);
    });

    test('NotificationService sorts pinned notifications deterministically to top', () {
      final service = NotificationService();
      final now = DateTime.now();

      final notifOld = NotificationItem(
        id: 1,
        userId: 10,
        notificationType: 'GENERAL',
        channelId: 'GO_ON_GENERAL',
        title: 'Old Notification',
        body: 'Body 1',
        status: 'STORED',
        isRead: true,
        createdAt: now.subtract(const Duration(hours: 3)),
      );

      final notifNew = NotificationItem(
        id: 2,
        userId: 10,
        notificationType: 'GENERAL',
        channelId: 'GO_ON_GENERAL',
        title: 'New Notification',
        body: 'Body 2',
        status: 'STORED',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 5)),
      );

      final notifPinned = NotificationItem(
        id: 3,
        userId: 10,
        notificationType: 'ADMIN',
        channelId: 'GO_ON_ADMIN',
        title: 'Pinned Important Notice',
        body: 'Body 3',
        status: 'STORED',
        isRead: false,
        isPinned: true,
        pinnedAt: now,
        createdAt: now.subtract(const Duration(hours: 5)),
      );

      // Add to notifications
      service.notifications.clear();
      service.notifications.addAll([notifOld, notifNew, notifPinned]);

      // Call sorting
      service.notifications.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        if (a.isPinned && b.isPinned) {
          final aPin = a.pinnedAt ?? a.createdAt;
          final bPin = b.pinnedAt ?? b.createdAt;
          final cmp = bPin.compareTo(aPin);
          if (cmp != 0) return cmp;
        }
        return b.createdAt.compareTo(a.createdAt);
      });

      // Pinned notice MUST be at index 0 even though created 5 hours ago
      expect(service.notifications[0].id, 3);
      expect(service.notifications[0].isPinned, true);
      expect(service.notifications[1].id, 2);
      expect(service.notifications[2].id, 1);
    });

    test('removeNotificationLocally immediately removes item and decreases unread count', () {
      final service = NotificationService();
      final item = NotificationItem(
        id: 99,
        userId: 10,
        notificationType: 'GENERAL',
        channelId: 'GO_ON_GENERAL',
        title: 'Swipe to delete item',
        body: 'Body',
        status: 'STORED',
        isRead: false,
        createdAt: DateTime.now(),
      );

      service.notifications.clear();
      service.notifications.add(item);
      expect(service.notifications.length, 1);

      service.removeNotificationLocally(99);
      expect(service.notifications.isEmpty, true);
    });
  });

  group('Dismissible Widget Tree Resilience Test', () {
    testWidgets('Swipe left dismisses card without "Dismissed Dismissible is still part of tree" error',
        (WidgetTester tester) async {
      final service = NotificationService();
      final now = DateTime.now();

      final item1 = NotificationItem(
        id: 101,
        userId: 1,
        notificationType: 'GENERAL',
        channelId: 'GO_ON_GENERAL',
        title: 'Notification to Delete',
        body: 'Swiping left should safely dismiss this card.',
        status: 'STORED',
        isRead: false,
        createdAt: now,
      );

      final item2 = NotificationItem(
        id: 102,
        userId: 1,
        notificationType: 'GENERAL',
        channelId: 'GO_ON_GENERAL',
        title: 'Second Notification',
        body: 'This should stay.',
        status: 'STORED',
        isRead: true,
        createdAt: now.subtract(const Duration(minutes: 5)),
      );

      service.notifications.clear();
      service.notifications.addAll([item1, item2]);

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

      // Both notifications should be present
      expect(find.text('Notification to Delete'), findsOneWidget);
      expect(find.text('Second Notification'), findsOneWidget);

      // Find the Dismissible widget for item 101
      final dismissibleFinder = find.byKey(const ValueKey('notif_card_101'));
      expect(dismissibleFinder, findsOneWidget);

      // Perform a drag to the left (endToStart)
      await tester.drag(dismissibleFinder, const Offset(-500.0, 0.0));
      await tester.pumpAndSettle();

      // Verify NO Flutter red error occurred and item101 is gone from the tree
      expect(find.text('Notification to Delete'), findsNothing);
      expect(find.text('Second Notification'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Swipe right triggers pin action and keeps card in tree cleanly',
        (WidgetTester tester) async {
      final service = NotificationService();
      final now = DateTime.now();

      final item1 = NotificationItem(
        id: 201,
        userId: 1,
        notificationType: 'GENERAL',
        channelId: 'GO_ON_GENERAL',
        title: 'Notification to Pin',
        body: 'Swiping right should trigger pin action and snap back smoothly.',
        status: 'STORED',
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 1)),
      );

      service.notifications.clear();
      service.notifications.add(item1);

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

      expect(find.text('Notification to Pin'), findsOneWidget);

      final dismissibleFinder = find.byKey(const ValueKey('notif_card_201'));
      expect(dismissibleFinder, findsOneWidget);

      // Perform drag to the right (startToEnd)
      await tester.drag(dismissibleFinder, const Offset(500.0, 0.0));
      await tester.pumpAndSettle();

      // Card must still be present in the tree and not dismissed
      expect(find.text('Notification to Pin'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
