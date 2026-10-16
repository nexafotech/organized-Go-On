import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_marker_mobile/utils/timezone_utils.dart';
import 'package:attendance_marker_mobile/models/notification_model.dart';

void main() {
  group('TimezoneUtils - Comprehensive IST and Relative Time Tests', () {
    test('1. parseUtc normalizes strings without Z as UTC', () {
      // Backend naive string from SQLite
      const naiveStr = '2026-10-15T07:55:28.304365';
      final dt = TimezoneUtils.parseUtc(naiveStr);

      expect(dt.isUtc, isTrue);
      expect(dt.year, equals(2026));
      expect(dt.month, equals(10));
      expect(dt.day, equals(15));
      expect(dt.hour, equals(7));
      expect(dt.minute, equals(55));
      expect(dt.second, equals(28));
    });

    test('2. parseUtc preserves explicit UTC Z suffix', () {
      const utcStr = '2026-10-15T07:55:28.304365Z';
      final dt = TimezoneUtils.parseUtc(utcStr);

      expect(dt.isUtc, isTrue);
      expect(dt.hour, equals(7));
      expect(dt.minute, equals(55));
    });

    test('3. parseUtc parses explicit timezone offset without double conversion', () {
      // 13:25:28 IST (+05:30) is 07:55:28 UTC
      const istStr = '2026-10-15T13:25:28.304365+05:30';
      final dt = TimezoneUtils.parseUtc(istStr);

      expect(dt.isUtc, isTrue);
      expect(dt.hour, equals(7));
      expect(dt.minute, equals(55));
      expect(dt.second, equals(28));
    });

    test('4. parseUtc safely handles null, empty, and invalid formats', () {
      final nowUtc = DateTime.now().toUtc();

      final nullResult = TimezoneUtils.parseUtc(null);
      expect(nullResult.isUtc, isTrue);
      expect(nowUtc.difference(nullResult).inSeconds.abs(), lessThanOrEqualTo(2));

      final emptyResult = TimezoneUtils.parseUtc('');
      expect(emptyResult.isUtc, isTrue);

      final invalidResult = TimezoneUtils.parseUtc('not-a-valid-date');
      expect(invalidResult.isUtc, isTrue);
    });

    test('5. toIst converts UTC instant to exact Asia/Kolkata (+05:30)', () {
      // 06:30:00 UTC -> 12:00:00 IST
      final utcInstant = DateTime.utc(2026, 10, 15, 6, 30, 0);
      final istInstant = TimezoneUtils.toIst(utcInstant);

      expect(istInstant.year, equals(2026));
      expect(istInstant.month, equals(10));
      expect(istInstant.day, equals(15));
      expect(istInstant.hour, equals(12));
      expect(istInstant.minute, equals(0));
      expect(istInstant.second, equals(0));
    });

    test('6. formatRelativeTime - 30 seconds ago returns "Just now"', () {
      final fixedClock = DateTime.utc(2026, 10, 15, 12, 0, 30);
      final notifTime = DateTime.utc(2026, 10, 15, 12, 0, 0);

      final result = TimezoneUtils.formatRelativeTime(notifTime, clockNow: fixedClock);
      expect(result, equals('Just now'));
    });

    test('7. formatRelativeTime - 5 minutes ago returns "5m ago"', () {
      final fixedClock = DateTime.utc(2026, 10, 15, 12, 5, 0);
      final notifTime = DateTime.utc(2026, 10, 15, 12, 0, 0);

      final result = TimezoneUtils.formatRelativeTime(notifTime, clockNow: fixedClock);
      expect(result, equals('5m ago'));
    });

    test('8. formatRelativeTime - 2 hours ago returns "2h ago"', () {
      final fixedClock = DateTime.utc(2026, 10, 15, 14, 0, 0);
      final notifTime = DateTime.utc(2026, 10, 15, 12, 0, 0);

      final result = TimezoneUtils.formatRelativeTime(notifTime, clockNow: fixedClock);
      expect(result, equals('2h ago'));
    });

    test('9. formatRelativeTime - 1 day ago returns "1d ago"', () {
      final fixedClock = DateTime.utc(2026, 10, 16, 14, 0, 0);
      final notifTime = DateTime.utc(2026, 10, 15, 12, 0, 0);

      final result = TimezoneUtils.formatRelativeTime(notifTime, clockNow: fixedClock);
      expect(result, equals('1d ago'));
    });

    test('10. formatRelativeTime - clock skew tolerance within 15 seconds returns "Just now"', () {
      // Device clock is 10 seconds behind server clock
      final fixedClock = DateTime.utc(2026, 10, 15, 12, 0, 0);
      final notifTime = DateTime.utc(2026, 10, 15, 12, 0, 10);

      final result = TimezoneUtils.formatRelativeTime(notifTime, clockNow: fixedClock);
      expect(result, equals('Just now'));
    });

    test('11. formatRelativeTime - future scheduled notification returns "Upcoming"', () {
      final fixedClock = DateTime.utc(2026, 10, 15, 12, 0, 0);
      final notifTime = DateTime.utc(2026, 10, 15, 13, 0, 0); // 1 hour in future

      final result = TimezoneUtils.formatRelativeTime(notifTime, clockNow: fixedClock);
      expect(result, equals('Upcoming'));
    });

    test('12. Notifications crossing midnight in IST', () {
      // 11:45 PM IST on 15 Oct is 18:15 UTC on 15 Oct
      final notifTime = DateTime.utc(2026, 10, 15, 18, 15, 0);
      // Current time is 12:15 AM IST on 16 Oct (18:45 UTC on 15 Oct)
      final fixedClock = DateTime.utc(2026, 10, 15, 18, 45, 0);

      final result = TimezoneUtils.formatRelativeTime(notifTime, clockNow: fixedClock);
      expect(result, equals('30m ago'));

      // Check IST formatting across midnight boundary
      final istStr = TimezoneUtils.formatIstDateTime(notifTime);
      expect(istStr, contains('15 Oct 2026'));
      expect(istStr, contains('11:45 PM IST'));
    });

    test('13. Notifications created near UTC midnight', () {
      // 00:05 UTC on 16 Oct is 05:35 AM IST on 16 Oct
      final notifTime = DateTime.utc(2026, 10, 16, 0, 5, 0);
      final fixedClock = DateTime.utc(2026, 10, 16, 0, 15, 0);

      final result = TimezoneUtils.formatRelativeTime(notifTime, clockNow: fixedClock);
      expect(result, equals('10m ago'));

      final istStr = TimezoneUtils.formatIstDateTime(notifTime);
      expect(istStr, equals('16 Oct 2026, 5:35 AM IST'));
    });

    test('14. formatIstTime and formatIstDate helpers', () {
      // 06:30 UTC -> 12:00 PM IST
      final notifTime = DateTime.utc(2026, 10, 15, 6, 30, 0);
      expect(TimezoneUtils.formatIstTime(notifTime), equals('12:00 PM IST'));
      expect(TimezoneUtils.formatIstDate(notifTime), equals('15 Oct 2026'));

      // 03:40 UTC -> 9:10 AM IST
      final morningTime = DateTime.utc(2026, 10, 15, 3, 40, 0);
      expect(TimezoneUtils.formatIstTime(morningTime), equals('9:10 AM IST'));
    });

    test('15. NotificationItem.fromJson correctly integrates TimezoneUtils', () {
      final json = {
        'id': 101,
        'user_id': 5,
        'notification_type': 'TIMETABLE',
        'channel_id': 'GO_ON_NEXT_CLASS',
        'title': 'Go-On • Next Class',
        'body': 'Your next class is Data Structures Laboratory — Period 4 at 12:00 PM.',
        'status': 'SENT',
        'is_read': false,
        'is_pinned': true,
        'created_at': '2026-10-15T06:30:00Z',
        'pinned_at': '2026-10-15T06:31:00Z',
      };

      final item = NotificationItem.fromJson(json);
      expect(item.createdAt.isUtc, isTrue);
      expect(item.pinnedAt?.isUtc, isTrue);
      expect(item.istFormatted, equals('15 Oct 2026, 12:00 PM IST'));
      expect(item.istTimeOnly, equals('12:00 PM IST'));
      expect(item.isPinned, isTrue);
    });

    test('16. NotificationItem handles naive backend created_at without offset corruption', () {
      final json = {
        'id': 102,
        'user_id': 5,
        'notification_type': 'ANNOUNCEMENT',
        'channel_id': 'GO_ON_ADMIN',
        'title': 'Holiday Announcement',
        'body': 'Today is a declared institutional holiday.',
        'status': 'STORED',
        'is_read': true,
        'created_at': '2026-10-15T07:55:28.304365', // naive from SQLite
      };

      final item = NotificationItem.fromJson(json);
      expect(item.createdAt.isUtc, isTrue);
      // 07:55:28 UTC + 05:30 = 13:25:28 IST (1:25 PM IST)
      expect(item.istTimeOnly, equals('1:25 PM IST'));
    });
  });
}
