import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/models/notification_model.dart';
import 'package:attendance_marker_mobile/services/notification_service.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_notification_history_screen.dart';

class MockNotificationService extends ChangeNotifier implements NotificationService {
  int _unreadCount = 0;
  List<NotificationItem> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;

  MockNotificationService({
    int unreadCount = 0,
    List<NotificationItem>? notifications,
    bool isLoading = false,
  }) {
    _unreadCount = unreadCount;
    _notifications = notifications ?? [];
    _isLoading = isLoading;
  }

  @override int get unreadCount => _unreadCount;
  @override List<NotificationItem> get notifications => _notifications;
  @override bool get isLoading => _isLoading;
  @override String? get errorMessage => _errorMessage;
  @override bool get isBulkDeleting => false;
  @override bool isNotificationPinned(int id) => _notifications.any((n) => n.id == id && n.isPinned);

  @override
  Future<List<NotificationItem>> fetchNotifications(dynamic apiClient, {bool unreadOnly = false, int limit = 50}) async {
    return _notifications;
  }

  @override
  Future<int> refreshUnreadCount(dynamic apiClient) async {
    return _unreadCount;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  NotificationItem makeNotification({
    required int id,
    required String title,
    required String body,
    bool isRead = false,
    bool isPinned = false,
    bool isDeleted = false,
    String channelId = 'GO_ON_ADMIN',
  }) {
    return NotificationItem(
      id: id,
      userId: 5,
      notificationType: 'ANNOUNCEMENT',
      channelId: channelId,
      title: title,
      body: body,
      status: 'SENT',
      isRead: isRead,
      isPinned: isPinned,
      isDeleted: isDeleted,
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    );
  }

  Widget createTestWidget(NotificationService service) {
    return MaterialApp(
      home: ChangeNotifierProvider<NotificationService>.value(
        value: service,
        child: const FacultyNotificationHistoryScreen(),
      ),
    );
  }

  group('Notification Count and Inbox State Synchronization', () {
    test('NotificationService clearUserData resets counts, notifications, and state', () {
      final service = NotificationService();
      service.clearUserData();

      expect(service.notifications, isEmpty);
      expect(service.unreadCount, equals(0));
      expect(service.isLoading, isFalse);
    });

    testWidgets('Empty inbox renders zero counts, hidden header badge, and empty state message',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = MockNotificationService(unreadCount: 0, notifications: []);

      await tester.pumpWidget(createTestWidget(service));
      await tester.pumpAndSettle();

      // Verify Empty State Messages
      expect(find.text('No notifications yet'), findsOneWidget);
      expect(find.text('Class updates and announcements will appear here.'), findsOneWidget);

      // Verify Header Badge is NOT present when unreadCount is 0
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('0'), findsNothing);

      // Verify Filter Chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);
    });

    testWidgets('Populated inbox with 3 unread displays matching header badge and filter counts',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final items = [
        makeNotification(id: 101, title: 'Exam Notice', body: 'Midterm dates announced', isRead: false),
        makeNotification(id: 102, title: 'Timetable Update', body: 'Period 3 room changed', isRead: false),
        makeNotification(id: 103, title: 'Attendance Alert', body: 'Attendance recorded', isRead: false),
      ];

      final service = MockNotificationService(unreadCount: 3, notifications: items);

      await tester.pumpWidget(createTestWidget(service));
      await tester.pumpAndSettle();

      // Verify items are displayed
      expect(find.text('Exam Notice'), findsOneWidget);
      expect(find.text('Timetable Update'), findsOneWidget);
      expect(find.text('Attendance Alert'), findsOneWidget);

      // Verify counts agree:
      // AppBar badge = 3, All chip = 3, Unread chip = 3
      expect(find.text('3'), findsNWidgets(3));
    });

    testWidgets('Tapping Unread filter tab filters list in-place without destroying All count',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final items = [
        makeNotification(id: 201, title: 'Read Announcement 1', body: 'Message 1', isRead: true),
        makeNotification(id: 202, title: 'Unread Urgent Note', body: 'Urgent notice', isRead: false),
        makeNotification(id: 203, title: 'Read Announcement 2', body: 'Message 2', isRead: true),
      ];

      final service = MockNotificationService(unreadCount: 1, notifications: items);

      await tester.pumpWidget(createTestWidget(service));
      await tester.pumpAndSettle();

      // On 'All' tab (initial): All 3 should be displayed
      expect(find.text('Read Announcement 1'), findsOneWidget);
      expect(find.text('Unread Urgent Note'), findsOneWidget);
      expect(find.text('Read Announcement 2'), findsOneWidget);

      // Tap 'Unread' filter chip
      await tester.tap(find.text('Unread'));
      await tester.pumpAndSettle();

      // Only unread item should remain visible
      expect(find.text('Unread Urgent Note'), findsOneWidget);
      expect(find.text('Read Announcement 1'), findsNothing);
      expect(find.text('Read Announcement 2'), findsNothing);

      // Crucial: All count must remain 3 on the All tab chip, Unread count must remain 1
      expect(find.text('3'), findsOneWidget); // All chip count
      expect(find.text('1'), findsNWidgets(2)); // Header badge + Unread chip count

      // Switch back to 'All' tab
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      // All 3 items should reappear without any network loss
      expect(find.text('Read Announcement 1'), findsOneWidget);
      expect(find.text('Unread Urgent Note'), findsOneWidget);
      expect(find.text('Read Announcement 2'), findsOneWidget);
    });

    testWidgets('Unread tab with 0 unread displays correct empty state message without corrupting All tab',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final items = [
        makeNotification(id: 301, title: 'Completed Class', body: 'Class 1', isRead: true),
        makeNotification(id: 302, title: 'Completed Class 2', body: 'Class 2', isRead: true),
      ];

      final service = MockNotificationService(unreadCount: 0, notifications: items);

      await tester.pumpWidget(createTestWidget(service));
      await tester.pumpAndSettle();

      // Tap 'Unread' filter chip
      await tester.tap(find.text('Unread'));
      await tester.pumpAndSettle();

      // Should display 'No unread notifications' and 'All your notifications have been marked as read.'
      expect(find.text('No unread notifications'), findsOneWidget);
      expect(find.text('All your notifications have been marked as read.'), findsOneWidget);

      // Header badge is hidden (unread is 0)
      expect(find.text('Notifications'), findsOneWidget);

      // All chip still displays count of 2
      expect(find.text('2'), findsOneWidget);
    });
  });
}
