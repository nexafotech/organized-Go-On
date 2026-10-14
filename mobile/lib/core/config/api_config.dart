import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get defaultUrl {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && !origin.startsWith('file://')) {
        if (Uri.base.port == 3000) {
          return '${Uri.base.scheme}://${Uri.base.host}:8000';
        }
        return origin;
      }
      return 'http://127.0.0.1:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static const String hotspotUrl = 'http://10.254.103.195:8000';
  static String? _customBaseUrl;

  static String get baseUrl => _customBaseUrl ?? defaultUrl;

  static void setBaseUrl(String url) {
    String clean = url.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (clean.isNotEmpty) {
      if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
        clean = 'http://$clean';
      }
      _customBaseUrl = clean;
    }
  }

  static String get apiVersion => '/api/v1';

  static String get fullApiUrl => '$baseUrl$apiVersion';

  // Endpoint paths
  static const String healthCheck = '/health';
  static const String apiHealthCheck = '/api/v1/health';
  static const String authStudentLogin = '/api/v1/auth/student/login';
  static const String authFacultyLogin = '/api/v1/auth/login';
  static const String authValidateIdentifier = '/api/v1/auth/validate-identifier';
  static const String authMe = '/api/v1/auth/me';
  static const String authStudentLogout = '/api/v1/auth/student/logout';
  static const String authFacultyLogout = '/api/v1/auth/logout';
  static const String authChangePassword = '/api/v1/auth/change-password';

  static const String studentMe = '/api/v1/student/me';
  static const String studentAttendance = '/api/v1/student/attendance';
  static const String studentSubjects = '/api/v1/student/attendance/subjects';
  static const String studentTimetable = '/api/v1/student/timetable';
  static const String studentProfile = '/api/v1/student/profile';
  static const String studentEnrollmentStatus = '/api/v1/student/enrollment-status';
  static const String studentEnrollValidatePose = '/api/v1/student/enroll-face/validate-pose';
  static const String studentEnrollCapture = '/api/v1/student/enroll-face/capture';
  static const String studentEnrollReset = '/api/v1/student/enroll-face/reset';

  static const String facultyTimetable = '/api/v1/faculty/timetable';
  static const String facultyActiveClass = '/api/v1/faculty/active-class';
  static const String facultySessionsStart = '/api/v1/faculty/sessions/start';
  static const String facultySessionsActive = '/api/v1/faculty/sessions/active';
  static String facultySessionDetails(int id) => '/api/v1/faculty/sessions/$id';
  static String facultyMarkAttendance(int id) => '/api/v1/faculty/sessions/$id/attendance';
  static String facultyMarkOd(int id) => '/api/v1/faculty/sessions/$id/od';
  static String facultyCompleteSession(int id) => '/api/v1/faculty/sessions/$id/complete';
  static String facultyRecognizeImage(int id) => '/api/v1/faculty/sessions/$id/recognize-image';
  static String facultyConfirmRecognition(int id) => '/api/v1/faculty/sessions/$id/confirm-recognition';
  static const String facultyAvailablePeriods = '/api/v1/faculty/attendance/available-periods';
  static String facultyAttendanceRoster(int timetableEntryId, String date) =>
      '/api/v1/faculty/attendance/roster/$timetableEntryId?date=$date';
  static const String facultyAttendanceSubmit = '/api/v1/faculty/attendance/submit';
  static String facultyAttendancePeriodsForDate(String date) =>
      '/api/v1/faculty/attendance/periods-for-date?date=$date';
  static const String facultyAttendanceBatchRecognize =
      '/api/v1/faculty/attendance/batch-recognize';

  // Class Advisor Endpoints
  static const String facultyClassAdvisorClass = '/api/v1/faculty/class-advisor/class';
  static const String facultyClassAdvisorAvailablePeriods = '/api/v1/faculty/class-advisor/available-periods';
  static String facultyClassAdvisorPeriodsForDate(String date) =>
      '/api/v1/faculty/class-advisor/periods-for-date?date=$date';
  static String facultyClassAdvisorRoster(int timetableEntryId, String date) =>
      '/api/v1/faculty/class-advisor/roster/$timetableEntryId?date=$date';
  static const String facultyClassAdvisorSubmit = '/api/v1/faculty/class-advisor/submit';
  static String facultyClassAdvisorDailySummary(String date) =>
      '/api/v1/faculty/class-advisor/daily-summary?date=$date';

  // Attendance Reports Endpoints
  static const String facultyReportAuthorizedOptions = '/api/v1/faculty/reports/authorized-options';
  static String facultyReportClassSummary({
    required int classId,
    int? subjectId,
    String? startDate,
    String? endDate,
  }) {
    final params = <String>['class_id=$classId'];
    if (subjectId != null) params.add('subject_id=$subjectId');
    if (startDate != null && startDate.isNotEmpty) params.add('start_date=$startDate');
    if (endDate != null && endDate.isNotEmpty) params.add('end_date=$endDate');
    return '/api/v1/faculty/reports/class-summary?${params.join('&')}';
  }

  static String facultyReportStudentDetail({
    required int studentId,
    int? subjectId,
    String? startDate,
    String? endDate,
  }) {
    final params = <String>['student_id=$studentId'];
    if (subjectId != null) params.add('subject_id=$subjectId');
    if (startDate != null && startDate.isNotEmpty) params.add('start_date=$startDate');
    if (endDate != null && endDate.isNotEmpty) params.add('end_date=$endDate');
    return '/api/v1/faculty/reports/student-detail?${params.join('&')}';
  }

  static String facultyReportDateMatrix({
    required int classId,
    required String date,
    int? subjectId,
  }) {
    final params = <String>['class_id=$classId', 'date=$date'];
    if (subjectId != null) params.add('subject_id=$subjectId');
    return '/api/v1/faculty/reports/date-matrix?${params.join('&')}';
  }

  static String facultyReportHistoricalMatrix({
    required int classId,
    int? subjectId,
    String? startDate,
    String? endDate,
  }) {
    final params = <String>['class_id=$classId'];
    if (subjectId != null) params.add('subject_id=$subjectId');
    if (startDate != null && startDate.isNotEmpty) params.add('start_date=$startDate');
    if (endDate != null && endDate.isNotEmpty) params.add('end_date=$endDate');
    return '/api/v1/faculty/reports/historical-matrix?${params.join('&')}';
  }

  // Phase 9: Faculty Date-Range Attendance Report PDF & Excel Export
  static String facultyReportRange({
    required int classId,
    required String fromDate,
    required String toDate,
    int? subjectId,
  }) {
    final params = <String>[
      'class_id=$classId',
      'from_date=$fromDate',
      'to_date=$toDate',
    ];
    if (subjectId != null) params.add('subject_id=$subjectId');
    return '/api/v1/faculty/reports/range?${params.join('&')}';
  }

  static String facultyReportRangePdf({
    required int classId,
    required String fromDate,
    required String toDate,
    int? subjectId,
  }) {
    final params = <String>[
      'class_id=$classId',
      'from_date=$fromDate',
      'to_date=$toDate',
    ];
    if (subjectId != null) params.add('subject_id=$subjectId');
    return '/api/v1/faculty/reports/range/pdf?${params.join('&')}';
  }

  static String facultyReportRangeExcel({
    required int classId,
    required String fromDate,
    required String toDate,
    int? subjectId,
  }) {
    final params = <String>[
      'class_id=$classId',
      'from_date=$fromDate',
      'to_date=$toDate',
    ];
    if (subjectId != null) params.add('subject_id=$subjectId');
    return '/api/v1/faculty/reports/range/excel?${params.join('&')}';
  }


  static String studentAttendanceReport({
    int? subjectId,
    String? startDate,
    String? endDate,
  }) {
    final params = <String>[];
    if (subjectId != null) params.add('subject_id=$subjectId');
    if (startDate != null && startDate.isNotEmpty) params.add('start_date=$startDate');
    if (endDate != null && endDate.isNotEmpty) params.add('end_date=$endDate');
    if (params.isEmpty) return studentAttendance;
    return '$studentAttendance?${params.join('&')}';
  }

  // Admin Biometric Management Endpoints
  static const String adminBiometricsSummary = '/api/v1/admin/biometrics/summary';
  static const String adminBiometricsStudents = '/api/v1/admin/biometrics/students';
  static String adminStudentBiometrics(int id) => '/api/v1/admin/students/$id/biometrics';
  static String adminStudentEnrollFace(int id, {bool replace = false}) =>
      '/api/v1/admin/students/$id/enroll-face?replace=$replace';
  static String adminStudentResetBiometrics(int id) => '/api/v1/admin/biometrics/$id/reset';
  static const String adminPreviewFolderPath = '/api/v1/admin/preview-folder-path';
  static const String adminEnrollFolderPath = '/api/v1/admin/enroll-folder-path';

  // Phase 7.8: Canonical Student Face Dataset & Multi-Photo Endpoints
  static String adminStudentEnrollPhotos(int id, {bool replace = false}) =>
      '/api/v1/admin/students/$id/enroll-photos?replace=$replace';
  static String adminStudentPhotos(int id) => '/api/v1/admin/students/$id/photos';
  static String adminStudentPhotoImage(int studentId, int embeddingId) =>
      '/api/v1/admin/students/$studentId/photos/$embeddingId/image';
  static String adminStudentDeletePhoto(int studentId, int embeddingId) =>
      '/api/v1/admin/students/$studentId/photos/$embeddingId';
  static String adminStudentReplaceDataset(int id) =>
      '/api/v1/admin/students/$id/replace-dataset';

  // Phase 11: Push Notification Endpoints
  static const String notificationDeviceToken = '/api/v1/notifications/device-token';
  static const String notificationMyDevices = '/api/v1/notifications/my-devices';
  static const String notificationHistory = '/api/v1/notifications/history';
  static const String notificationUnreadCount = '/api/v1/notifications/unread-count';
  static String notificationMarkRead(int id) => '/api/v1/notifications/$id/read';
  static const String notificationReadAll = '/api/v1/notifications/read-all';
  static String notificationDelete(int id) => '/api/v1/notifications/$id';
  static String notificationPin(int id) => '/api/v1/notifications/$id/pin';
  static String notificationUnpin(int id) => '/api/v1/notifications/$id/unpin';
  static const String notificationDeleteUnpinned = '/api/v1/notifications/unpinned';
  static const String adminNotificationSettings = '/api/v1/admin/notifications/settings';
  static const String adminNotificationSend = '/api/v1/admin/notifications/send';
  static const String adminNotificationTrigger = '/api/v1/admin/notifications/trigger-reminders';
  static const String adminNotificationLogs = '/api/v1/admin/notifications/logs';
}

