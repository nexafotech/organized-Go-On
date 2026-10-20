import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/models/notification_model.dart';
import 'package:attendance_marker_mobile/services/notification_service.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_notification_history_screen.dart';
import 'package:attendance_marker_mobile/widgets/common/notification_toast.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pinned Notification Warning Toast Contrast & Behavior Tests', () {
    testWidgets('Attempting to delete pinned notification displays high-contrast toast in LIGHT theme',
        (WidgetTester tester) async {
      // Configure Samsung Galaxy S24 dimensions (360x800 logical viewport)
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final service = NotificationService();
      final now = DateTime.now();

      final pinnedItem = NotificationItem(
        id: 101,
        userId: 1,
        notificationType: 'ADMIN',
        channelId: 'GO_ON_ADMIN',
        title: 'Important Pinned Exam Alert',
        body: 'Hall tickets are available for download.',
        status: 'STORED',
        isRead: false,
        isPinned: true,
        pinnedAt: now,
        createdAt: now.subtract(const Duration(minutes: 10)),
      );

      service.notifications.clear();
      service.notifications.add(pinnedItem);

      await tester.pumpWidget(
        ChangeNotifierProvider<NotificationService>.value(
          value: service,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const FacultyNotificationHistoryScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Important Pinned Exam Alert'), findsOneWidget);

      // Swipe left on pinned card to trigger delete
      final dismissibleFinder = find.byKey(const ValueKey('notif_card_101'));
      expect(dismissibleFinder, findsOneWidget);
      await tester.drag(dismissibleFinder, const Offset(-500.0, 0.0));
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Verify warning text is displayed
      final messageFinder = find.text('Pinned notifications cannot be deleted. Unpin first.');
      expect(messageFinder, findsOneWidget);

      // 2. Verify SnackBar has explicit high-contrast background: #171417
      final snackBarFinder = find.byType(SnackBar);
      expect(snackBarFinder, findsOneWidget);
      final SnackBar snackBar = tester.widget(snackBarFinder);
      expect(snackBar.backgroundColor, const Color(0xFF171417));
      expect(snackBar.behavior, SnackBarBehavior.floating);

      // 3. Verify text has explicit crisp white color: #FFFFFF
      final Text messageWidget = tester.widget(messageFinder);
      expect(messageWidget.style?.color, const Color(0xFFFFFFFF));

      // 4. Verify gold/amber warning icon is present
      final iconFinder = find.byIcon(Icons.warning_amber_rounded);
      expect(iconFinder, findsOneWidget);
      final Icon iconWidget = tester.widget(iconFinder);
      expect(iconWidget.color, const Color(0xFFF59E0B));

      // 5. Verify pinned notification was NOT deleted from list
      expect(service.notifications.length, 1);
      expect(service.notifications.first.id, 101);
      expect(service.notifications.first.isPinned, true);
    });

    testWidgets('Attempting to delete pinned notification displays high-contrast toast in DARK theme',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final service = NotificationService();
      final now = DateTime.now();

      final pinnedItem = NotificationItem(
        id: 102,
        userId: 1,
        notificationType: 'ADMIN',
        channelId: 'GO_ON_ADMIN',
        title: 'Dark Mode Pinned Alert',
        body: 'Testing dark theme contrast.',
        status: 'STORED',
        isRead: false,
        isPinned: true,
        pinnedAt: now,
        createdAt: now.subtract(const Duration(minutes: 5)),
      );

      service.notifications.clear();
      service.notifications.add(pinnedItem);

      await tester.pumpWidget(
        ChangeNotifierProvider<NotificationService>.value(
          value: service,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const FacultyNotificationHistoryScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final dismissibleFinder = find.byKey(const ValueKey('notif_card_102'));
      await tester.drag(dismissibleFinder, const Offset(-500.0, 0.0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // In Dark theme, contrast is equally crisp and distinct
      final snackBarFinder = find.byType(SnackBar);
      expect(snackBarFinder, findsOneWidget);
      final SnackBar snackBar = tester.widget(snackBarFinder);
      expect(snackBar.backgroundColor, const Color(0xFF171417));

      final messageFinder = find.text('Pinned notifications cannot be deleted. Unpin first.');
      expect(messageFinder, findsOneWidget);
      final Text messageWidget = tester.widget(messageFinder);
      expect(messageWidget.style?.color, const Color(0xFFFFFFFF));

      final iconFinder = find.byIcon(Icons.warning_amber_rounded);
      expect(iconFinder, findsOneWidget);
      final Icon iconWidget = tester.widget(iconFinder);
      expect(iconWidget.color, const Color(0xFFF59E0B));
    });

    testWidgets('Popup menu delete option on pinned notification triggers warning toast',
        (WidgetTester tester) async {
      final service = NotificationService();
      final now = DateTime.now();

      final pinnedItem = NotificationItem(
        id: 103,
        userId: 1,
        notificationType: 'GENERAL',
        channelId: 'GO_ON_GENERAL',
        title: 'Popup Pinned Item',
        body: 'Menu delete should trigger toast.',
        status: 'STORED',
        isRead: false,
        isPinned: true,
        pinnedAt: now,
        createdAt: now,
      );

      service.notifications.clear();
      service.notifications.add(pinnedItem);

      await tester.pumpWidget(
        ChangeNotifierProvider<NotificationService>.value(
          value: service,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const FacultyNotificationHistoryScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open popup menu on the card
      final menuFinder = find.byKey(const ValueKey('notif_menu_103'));
      expect(menuFinder, findsOneWidget);
      await tester.tap(menuFinder);
      await tester.pumpAndSettle();

      // Tap Protected (Pinned) menu item
      expect(find.text('Protected (Pinned)'), findsOneWidget);
      await tester.tap(find.text('Protected (Pinned)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // NotificationToast must be displayed
      expect(find.text('Pinned notifications cannot be deleted. Unpin first.'), findsOneWidget);
      final SnackBar snackBar = tester.widget(find.byType(SnackBar));
      expect(snackBar.backgroundColor, const Color(0xFF171417));
    });

    testWidgets('Bulk-delete icon when all notifications are pinned shows high-contrast warning toast',
        (WidgetTester tester) async {
      final service = NotificationService();
      final now = DateTime.now();

      final pinned1 = NotificationItem(
        id: 201,
        userId: 1,
        notificationType: 'ADMIN',
        channelId: 'GO_ON_ADMIN',
        title: 'Sole Pinned 1',
        body: 'Body 1',
        status: 'STORED',
        isRead: false,
        isPinned: true,
        pinnedAt: now,
        createdAt: now,
      );

      service.notifications.clear();
      service.notifications.add(pinned1);

      await tester.pumpWidget(
        ChangeNotifierProvider<NotificationService>.value(
          value: service,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const FacultyNotificationHistoryScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap dustbin
      await tester.tap(find.byTooltip('Delete all unpinned notifications'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify the warning toast appears with correct high-contrast colors
      final messageFinder = find.text('All active notifications are pinned. Unpin notifications first to delete them.');
      expect(messageFinder, findsOneWidget);

      final SnackBar snackBar = tester.widget(find.byType(SnackBar));
      expect(snackBar.backgroundColor, const Color(0xFF171417));

      final Text messageText = tester.widget(messageFinder);
      expect(messageText.style?.color, const Color(0xFFFFFFFF));

      final Icon icon = tester.widget(find.byIcon(Icons.warning_amber_rounded));
      expect(icon.color, const Color(0xFFF59E0B));
    });

    testWidgets('Unpinning a notification allows standard deletion behavior',
        (WidgetTester tester) async {
      final service = NotificationService();
      final now = DateTime.now();

      final item = NotificationItem(
        id: 301,
        userId: 1,
        notificationType: 'GENERAL',
        channelId: 'GO_ON_GENERAL',
        title: 'Unpinned Notification Item',
        body: 'Can be deleted normally.',
        status: 'STORED',
        isRead: false,
        isPinned: false, // NOT pinned
        createdAt: now,
      );

      service.notifications.clear();
      service.notifications.add(item);

      await tester.pumpWidget(
        ChangeNotifierProvider<NotificationService>.value(
          value: service,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const FacultyNotificationHistoryScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Swipe left on unpinned card to delete
      final dismissibleFinder = find.byKey(const ValueKey('notif_card_301'));
      await tester.drag(dismissibleFinder, const Offset(-500.0, 0.0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Card is dismissed because it is unpinned
      expect(find.text('Unpinned Notification Item'), findsNothing);
      // Warning toast is NOT shown
      expect(find.text('Pinned notifications cannot be deleted. Unpin first.'), findsNothing);
    });

    test('NotificationToast unit test for type configurations and color contracts', () {
      expect(NotificationToast.toastBg, const Color(0xFF171417));
      expect(NotificationToast.toastText, const Color(0xFFFFFFFF));
      expect(NotificationToast.warningGold, const Color(0xFFF59E0B));
      expect(NotificationToast.successGreen, const Color(0xFF10B981));
      expect(NotificationToast.infoBlue, const Color(0xFF818CF8));
      expect(NotificationToast.errorRed, const Color(0xFFF43F5E));
    });
  });
}
