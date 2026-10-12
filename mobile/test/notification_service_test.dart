import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:attendance_marker_mobile/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService Channel and Configuration Tests', () {
    test('Notification channels are defined with correct importance', () {
      expect(NotificationService.channelNextClass.id, 'GO_ON_NEXT_CLASS');
      expect(NotificationService.channelNextClass.importance, Importance.max);
      expect(NotificationService.channelNextClass.playSound, isTrue);

      expect(NotificationService.channelAttendance.id, 'GO_ON_ATTENDANCE');
      expect(NotificationService.channelAttendance.importance, Importance.max);

      expect(NotificationService.channelAdmin.id, 'GO_ON_ADMIN');
      expect(NotificationService.channelAdmin.importance, Importance.max);

      expect(NotificationService.channelAccount.id, 'GO_ON_ACCOUNT');
      expect(NotificationService.channelAccount.importance, Importance.defaultImportance);

      expect(NotificationService.channelGeneral.id, 'GO_ON_GENERAL');
      expect(NotificationService.channelGeneral.importance, Importance.defaultImportance);
    });

    test('Singleton instance is consistent and initial state is clean', () {
      final s1 = NotificationService();
      final s2 = NotificationService();
      expect(identical(s1, s2), isTrue);
      expect(s1.currentFcmToken, isNull);
    });

    test('All required channels cover Go-On notification architecture', () {
      final channelIds = [
        NotificationService.channelNextClass.id,
        NotificationService.channelAttendance.id,
        NotificationService.channelAdmin.id,
        NotificationService.channelAccount.id,
        NotificationService.channelGeneral.id,
      ];
      expect(channelIds, contains('GO_ON_NEXT_CLASS'));
      expect(channelIds, contains('GO_ON_ATTENDANCE'));
      expect(channelIds, contains('GO_ON_ADMIN'));
      expect(channelIds, contains('GO_ON_ACCOUNT'));
      expect(channelIds, contains('GO_ON_GENERAL'));
    });
  });
}
