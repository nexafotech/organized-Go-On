/// Authoritative Timezone and Relative Time Utilities for go-On Mobile.
/// Strictly implements the Asia/Kolkata (IST, UTC+05:30) timezone policy.
library;

class TimezoneUtils {
  /// Standard offset for Indian Standard Time (Asia/Kolkata, UTC+05:30).
  /// India does not observe Daylight Saving Time.
  static const Duration kolkataOffset = Duration(hours: 5, minutes: 30);

  /// Month names for local date formatting.
  static const List<String> _months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Safely parses a dynamic datetime input into a normalized UTC [DateTime].
  ///
  /// Prevents the critical bug where naive ISO-8601 strings without timezone indicators
  /// (e.g. '2026-10-15T07:55:28.304365') are wrongly parsed as device-local time by Dart.
  /// Any string lacking timezone designators ('Z' or '+/-HH:MM') is explicitly
  /// treated as UTC because all go-On backend timestamps are stored in UTC.
  static DateTime parseUtc(dynamic raw) {
    if (raw == null) return DateTime.now().toUtc();
    if (raw is DateTime) return raw.toUtc();

    final str = raw.toString().trim();
    if (str.isEmpty) return DateTime.now().toUtc();

    // Check if the string already has a timezone indicator
    String normalized = str;
    if (!normalized.endsWith('Z') && !normalized.contains('+')) {
      final tIndex = normalized.indexOf('T');
      if (tIndex != -1) {
        final timePart = normalized.substring(tIndex);
        // Check if there is an explicit negative timezone offset after the time part (e.g., -05:00)
        final hasTzOffset = timePart.contains('+') || (timePart.lastIndexOf('-') > 0);
        if (!hasTzOffset) {
          normalized = '${normalized}Z';
        }
      } else {
        // Space separated e.g. '2026-10-15 07:55:28'
        normalized = normalized.replaceAll(' ', 'T');
        if (!normalized.endsWith('Z')) {
          normalized = '${normalized}Z';
        }
      }
    }

    final parsed = DateTime.tryParse(normalized);
    if (parsed != null) {
      return parsed.toUtc();
    }

    // Fallback: try raw string directly
    final fallback = DateTime.tryParse(str);
    return fallback != null ? fallback.toUtc() : DateTime.now().toUtc();
  }

  /// Converts any [DateTime] instant into Indian Standard Time (Asia/Kolkata).
  static DateTime toIst(DateTime dt) {
    return dt.toUtc().add(kolkataOffset);
  }

  /// Formats elapsed time relative to the creation instant.
  ///
  /// Relative time is calculated from the UTC instant of creation and the current UTC instant.
  /// Because relative elapsed time is invariant across timezones, this ensures
  /// absolute accuracy without double conversion or local time skew.
  ///
  /// - Within 15s future (clock skew tolerance) -> 'Just now'
  /// - Future beyond 15s -> 'Upcoming'
  /// - < 60s -> 'Just now'
  /// - < 60m -> 'Xm ago'
  /// - < 24h -> 'Xh ago'
  /// - < 7d -> 'Xd ago'
  /// - >= 7d -> 'DD/MM/YYYY'
  static String formatRelativeTime(DateTime dt, {DateTime? clockNow}) {
    final nowUtc = clockNow?.toUtc() ?? DateTime.now().toUtc();
    final notifUtc = dt.toUtc();
    final diff = nowUtc.difference(notifUtc);

    // Future-dated check
    if (diff.isNegative) {
      // Allow up to 15 seconds clock skew tolerance between server and device
      if (diff.inSeconds >= -15) {
        return 'Just now';
      }
      return 'Upcoming';
    }

    if (diff.inSeconds < 60) {
      return 'Just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }

    // Beyond 7 days: format in IST calendar date
    final ist = toIst(notifUtc);
    final dayStr = ist.day.toString().padLeft(2, '0');
    final monthStr = ist.month.toString().padLeft(2, '0');
    return '$dayStr/$monthStr/${ist.year}';
  }

  /// Formats a timestamp into human-readable IST date and time.
  /// Example: '15 Oct 2026, 1:25 PM IST'
  static String formatIstDateTime(dynamic dt) {
    if (dt == null) return '';
    final utc = parseUtc(dt);
    final ist = toIst(utc);
    final dayStr = ist.day.toString().padLeft(2, '0');
    final monthStr = _months[ist.month];
    final timeStr = formatIstTime(utc);
    return '$dayStr $monthStr ${ist.year}, $timeStr';
  }

  /// Formats the time component in 12-hour IST format with explicit 'IST' label.
  /// Example: '1:25 PM IST' or '9:10 AM IST'
  static String formatIstTime(dynamic dt) {
    if (dt == null) return '';
    final utc = parseUtc(dt);
    final ist = toIst(utc);
    final hour = ist.hour % 12 == 0 ? 12 : ist.hour % 12;
    final minute = ist.minute.toString().padLeft(2, '0');
    final ampm = ist.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm IST';
  }

  /// Formats the date component in IST.
  /// Example: '15 Oct 2026'
  static String formatIstDate(dynamic dt) {
    if (dt == null) return '';
    final utc = parseUtc(dt);
    final ist = toIst(utc);
    final dayStr = ist.day.toString().padLeft(2, '0');
    final monthStr = _months[ist.month];
    return '$dayStr $monthStr ${ist.year}';
  }

  /// Converts a 24-hour time string "HH:MM" (as returned by the API for period
  /// start/end times stored in the database) to a 12-hour AM/PM string.
  ///
  /// Examples:
  ///   '09:10' → '9:10 AM'
  ///   '12:50' → '12:50 PM'
  ///   '13:40' → '1:40 PM'
  ///   '16:10' → '4:10 PM'
  ///
  /// Returns the original string unchanged if it cannot be parsed.
  static String format24hTo12h(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    final parts = timeStr.split(':');
    if (parts.length != 2) return timeStr;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return timeStr;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$displayHour:$minuteStr $ampm';
  }

  /// Returns the current weekday name in IST (e.g. 'Monday', 'Tuesday').
  /// Uses the UTC+05:30 fixed offset — safe when device timezone differs from IST.
  static String istWeekdayName() {
    final now = DateTime.now().toUtc().add(kolkataOffset);
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
    ];
    return days[now.weekday - 1];
  }

  /// Returns the current DateTime in Indian Standard Time (Asia/Kolkata).
  static DateTime nowIst() {
    return toIst(DateTime.now());
  }

  /// Returns today's date at midnight in Indian Standard Time (Asia/Kolkata).
  static DateTime todayIst() {
    final now = nowIst();
    return DateTime(now.year, now.month, now.day);
  }

  /// Returns the uppercase weekday name for any DateTime (e.g. 'MONDAY', 'SUNDAY').
  static String weekdayNameFor(DateTime dt) {
    const days = [
      'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY',
    ];
    return days[dt.weekday - 1];
  }

  /// Formats a DateTime as 'YYYY-MM-DD'.
  static String dateToIsoString(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Determines whether a scheduled period has ended based strictly on its
  /// scheduled end time and the target date in IST.
  ///
  /// - Historical dates (strictly before today): returns `true` (period has already ended).
  /// - Future dates (strictly after today): returns `false` (period is in the future).
  /// - Today: returns `true` ONLY if [now] is strictly after the period's scheduled end time.
  /// - Invalid/missing end time: returns `false` (cannot verify completion).
  static bool isPeriodCompleted({
    required DateTime targetDate,
    required String? endTimeStr,
    required DateTime now,
  }) {
    if (endTimeStr == null || endTimeStr.trim().isEmpty) {
      return false;
    }

    final parts = endTimeStr.trim().split(':');
    if (parts.length < 2) {
      return false;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return false;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return false;
    }

    final second = parts.length >= 3 ? (int.tryParse(parts[2]) ?? 0) : 0;

    // Construct the authoritative period end instant on targetDate
    final periodEnd = DateTime.utc(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      hour,
      minute,
      second,
    );

    // Current instant normalized with UTC components for timezone-agnostic comparison
    final currentInstant = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );

    // The period has completed if and only if the current time is strictly after the scheduled end time
    return currentInstant.isAfter(periodEnd);
  }
}
