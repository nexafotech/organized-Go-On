import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/models/notification_model.dart';
import 'package:attendance_marker_mobile/services/notification_service.dart';
import 'package:attendance_marker_mobile/widgets/widgets.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_notification_history_screen.dart';

class MockNotificationService extends ChangeNotifier implements NotificationService {
  int _unreadCount = 0;
  List<NotificationItem> _notifications = [];
  bool _refreshCalled = false;

  MockNotificationService({int unreadCount = 0, List<NotificationItem>? notifications}) {
    _unreadCount = unreadCount;
    _notifications = notifications ?? [];
  }

  @override int get unreadCount => _unreadCount;
  @override List<NotificationItem> get notifications => _notifications;
  @override bool get isLoading => false;
  @override String? get errorMessage => null;
  @override bool get isBulkDeleting => false;
  bool get refreshCalled => _refreshCalled;

  void setUnreadCount(int count) {
    _unreadCount = count;
    notifyListeners();
  }

  @override
  Future<List<NotificationItem>> fetchNotifications(dynamic apiClient, {bool unreadOnly = false, int limit = 50}) async {
    return _notifications;
  }

  @override
  Future<int> refreshUnreadCount(dynamic apiClient) async {
    _refreshCalled = true;
    notifyListeners();
    return _unreadCount;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Faculty Notification Bell and Delivery Tests', () {
    testWidgets('1. Zero unread notifications: displays inactive bell and hides badge', (tester) async {
      final mockNotif = MockNotificationService(unreadCount: 0);

      await tester.pumpWidget(
        ChangeNotifierProvider<NotificationService>.value(
          value: mockNotif,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: NotificationBellWidget(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Inactive bell icon
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active_rounded), findsNothing);

      // Badge should NOT be rendered when unread is 0
      expect(find.text('0'), findsNothing);
      expect(find.byWidgetPredicate((w) => w is IgnorePointer && w.ignoring == true), findsNothing);
    });

    testWidgets('2. Single-digit unread: displays active bell and circular badge with exact count', (tester) async {
      final mockNotif = MockNotificationService(unreadCount: 7);

      await tester.pumpWidget(
        ChangeNotifierProvider<NotificationService>.value(
          value: mockNotif,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: NotificationBellWidget(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Active bell icon
      expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsNothing);

      // Exact count
      expect(find.text('7'), findsOneWidget);
      // Badge is wrapped with IgnorePointer(ignoring: true) to ensure reliable clicks
      expect(find.byWidgetPredicate((w) => w is IgnorePointer && w.ignoring == true), findsOneWidget);
    });

    testWidgets('3. Multi-digit unread count: displays exact count like 153 and does NOT hardcode 9+', (tester) async {
      final mockNotif = MockNotificationService(unreadCount: 153);

      await tester.pumpWidget(
        ChangeNotifierProvider<NotificationService>.value(
          value: mockNotif,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: NotificationBellWidget(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Active bell icon
      expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);

      // Displays exact 153, never hardcoded '9+'
      expect(find.text('153'), findsOneWidget);
      expect(find.text('9+'), findsNothing);
    });

    testWidgets('4. Tapping bell navigates to FacultyNotificationHistoryScreen and refreshes unread count on return', (tester) async {
      final mockNotif = MockNotificationService(unreadCount: 3);

      await tester.pumpWidget(
        ChangeNotifierProvider<NotificationService>.value(
          value: mockNotif,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: NotificationBellWidget(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the bell
      await tester.tap(find.byType(NotificationBellWidget));
      await tester.pumpAndSettle();

      // Should have navigated to history screen
      expect(find.byType(FacultyNotificationHistoryScreen), findsOneWidget);
      expect(find.text('Notifications'), findsWidgets);

      // Pop back to dashboard
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      // Should be back to initial screen
      expect(find.byType(FacultyNotificationHistoryScreen), findsNothing);
      expect(find.byType(NotificationBellWidget), findsOneWidget);

      // refreshUnreadCount should have been called upon return
      expect(mockNotif.refreshCalled, isTrue);
    });

    testWidgets('5. Dynamic update: count change automatically updates bell state and badge', (tester) async {
      final mockNotif = MockNotificationService(unreadCount: 0);

      await tester.pumpWidget(
        ChangeNotifierProvider<NotificationService>.value(
          value: mockNotif,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: NotificationBellWidget(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.text('4'), findsNothing);

      // Simulate notification arrival
      mockNotif.setUnreadCount(4);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);
      expect(find.text('4'), findsOneWidget);

      // Simulate all marked as read
      mockNotif.setUnreadCount(0);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.text('4'), findsNothing);
    });
  });
}
