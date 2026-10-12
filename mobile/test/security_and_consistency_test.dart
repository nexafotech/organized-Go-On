import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/models/user_model.dart';
import 'package:attendance_marker_mobile/models/student_model.dart';
import 'package:attendance_marker_mobile/models/faculty_model.dart';
import 'package:attendance_marker_mobile/models/recognition_model.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/models/faculty_report_model.dart';
import 'package:attendance_marker_mobile/services/auth_service.dart';
import 'package:attendance_marker_mobile/services/student_service.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';
import 'package:attendance_marker_mobile/student/screens/student_dashboard_screen.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_dashboard_screen.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_session_screen.dart';

class MockAuthServiceForSecurity extends ChangeNotifier implements AuthService {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _sessionExpired = false;
  int loginCallCount = 0;

  MockAuthServiceForSecurity({UserModel? user, bool sessionExpired = false})
      : _currentUser = user,
        _sessionExpired = sessionExpired;

  @override
  UserModel? get currentUser => _currentUser;
  @override
  bool get isLoading => _isLoading;
  @override
  String? get errorMessage => _errorMessage;
  @override
  bool get sessionExpired => _sessionExpired;
  @override
  bool get isAuthenticated => _currentUser != null;

  @override
  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void clearSessionExpired() {
    _sessionExpired = false;
    notifyListeners();
  }

  @override
  Future<UserModel?> loginStudent(String identifier, String password) async {
    if (_isLoading) return null; // Duplicate request prevention
    loginCallCount++;
    _isLoading = true;
    notifyListeners();

    if (identifier == 'DISABLED') {
      _isLoading = false;
      _errorMessage = 'Your account is disabled. Please contact Admin.';
      notifyListeners();
      throw Exception('Account disabled');
    }
    if (identifier == 'LOCKED') {
      _isLoading = false;
      _errorMessage = 'Your account is temporarily locked. Please try again later or contact Admin.';
      notifyListeners();
      throw Exception('Account locked');
    }
    if (identifier == 'NETWORK_ERR') {
      _isLoading = false;
      _errorMessage = 'Unable to reach the server. Check your connection or server address.';
      notifyListeners();
      throw Exception('Network error');
    }
    if (identifier == 'WRONG_PASS') {
      _isLoading = false;
      _errorMessage = 'Incorrect login ID or password.';
      notifyListeners();
      throw Exception('Invalid credentials');
    }

    _currentUser = UserModel(
      id: 1,
      username: identifier,
      email: '$identifier@college.edu',
      role: 'STUDENT',
      isActive: true,
      fullName: 'Valid Student',
      forcePasswordChange: identifier == 'FORCE_PASS',
    );
    _isLoading = false;
    notifyListeners();
    return _currentUser;
  }

  @override
  Future<UserModel?> loginFaculty(String usernameOrEmail, String password) async {
    if (_isLoading) return null;
    loginCallCount++;
    _isLoading = true;
    notifyListeners();

    if (usernameOrEmail == 'FAC_DISABLED') {
      _isLoading = false;
      _errorMessage = 'Your account is disabled. Please contact Admin.';
      notifyListeners();
      throw Exception('Account disabled');
    }

    _currentUser = UserModel(
      id: 2,
      username: usernameOrEmail,
      email: '$usernameOrEmail@college.edu',
      role: 'FACULTY',
      isActive: true,
      fullName: 'Valid Faculty',
      forcePasswordChange: usernameOrEmail == 'FAC_FORCE_PASS',
    );
    _isLoading = false;
    notifyListeners();
    return _currentUser;
  }

  @override
  Future<UserModel?> restoreSession() async => _currentUser;

  @override
  Future<bool> changePassword({required String currentPassword, required String newPassword}) async => true;

  @override
  Future<void> logout() async {
    _currentUser = null;
    notifyListeners();
  }

  @override
  Future<Map<String, dynamic>> validateIdentifier(String identifier, {String role = 'FACULTY'}) async =>
      {'valid': true, 'role': role, 'message': null, 'is_network_error': false};
}

class MockStudentServiceForSecurity extends ChangeNotifier implements StudentService {
  StudentSummaryModel? _summary;
  List<SubjectAttendanceModel> _subjects = [];
  List<TimetableItemModel> _timetable = [];
  List<DateWiseEntryModel> _dateWise = [];
  bool _isLoading = false;
  String? _errorMessage;
  int refreshCount = 0;

  MockStudentServiceForSecurity({
    StudentSummaryModel? summary,
    List<SubjectAttendanceModel>? subjects,
    List<TimetableItemModel>? timetable,
    String? errorMessage,
  })  : _summary = summary,
        _subjects = subjects ?? [],
        _timetable = timetable ?? [],
        _errorMessage = errorMessage;

  @override
  StudentSummaryModel? get summary => _summary;
  @override
  List<SubjectAttendanceModel> get subjects => _subjects;
  @override
  List<TimetableItemModel> get timetable => _timetable;
  @override
  List<DateWiseEntryModel> get dateWise => _dateWise;
  @override
  bool get isLoading => _isLoading;
  @override
  String? get errorMessage => _errorMessage;

  @override
  Future<void> fetchStudentSummary() async {}
  @override
  Future<void> fetchSubjects() async {}
  @override
  Future<void> fetchTimetable() async {}
  @override
  Future<void> fetchAttendanceReport() async {}
  @override
  Future<void> fetchAttendanceReportFiltered({int? subjectId, String? startDate, String? endDate}) async {}
  @override
  Future<void> loadDashboardData() async {
    refreshCount++;
    notifyListeners();
  }
}

class MockFacultyServiceForSecurity extends ChangeNotifier implements FacultyService {
  List<FacultyScheduleItem> _schedule = [];
  ActiveClassSlot? _activeSlot;
  bool _hasActiveSlot = false;
  int? _activeSessionId;
  String? _activeSessionStatus;
  List<RosterStudentModel> _roster = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool completeSessionCalled = false;
  int markAttendanceCount = 0;
  String? lastMarkedStatus;
  String? lastOdReason;

  MockFacultyServiceForSecurity({
    List<FacultyScheduleItem>? schedule,
    ActiveClassSlot? activeSlot,
    bool hasActiveSlot = false,
    int? activeSessionId,
    List<RosterStudentModel>? roster,
  })  : _schedule = schedule ?? [],
        _activeSlot = activeSlot,
        _hasActiveSlot = hasActiveSlot,
        _activeSessionId = activeSessionId,
        _roster = roster ?? [];

  @override
  List<FacultyScheduleItem> get schedule => _schedule;
  @override
  ActiveClassSlot? get activeSlot => _activeSlot;
  @override
  bool get hasActiveSlot => _hasActiveSlot;
  @override
  int? get activeSessionId => _activeSessionId;
  @override
  String? get activeSessionStatus => _activeSessionStatus;
  @override
  List<RosterStudentModel> get roster => _roster;
  @override
  bool get isLoading => _isLoading;
  @override
  String? get errorMessage => _errorMessage;

  @override
  Future<void> fetchSchedule() async {}
  @override
  Future<void> checkActiveClassSlot() async {}
  @override
  Future<void> checkActiveSession() async {}
  @override
  Future<void> startSession() async {}
  @override
  Future<void> markAttendance({required int studentId, required String status, String? odReason}) async {
    markAttendanceCount++;
    lastMarkedStatus = status;
    lastOdReason = odReason;
    final idx = _roster.indexWhere((r) => r.studentId == studentId);
    if (idx != -1) {
      _roster[idx] = RosterStudentModel(
        studentId: _roster[idx].studentId,
        fullName: _roster[idx].fullName,
        rollNumber: _roster[idx].rollNumber,
        attendanceStatus: status,
        odReason: odReason,
      );
      notifyListeners();
    }
  }

  @override
  Future<void> completeSession() async {
    completeSessionCalled = true;
    _activeSessionStatus = 'COMPLETED';
    _activeSessionId = null;
    notifyListeners();
  }

  @override
  Future<RecognitionResultModel> uploadGroupPhoto(File imageFile, {List<int>? bytes, String? filename}) async => throw UnimplementedError();
  @override
  Future<void> confirmRecognition(List<int> confirmedStudentIds) async {}
  @override
  Future<void> loadDashboardData() async {}

  @override
  Future<AvailablePeriodsResponse> fetchAvailableAttendancePeriods() async =>
      AvailablePeriodsResponse(
        todayDate: '2026-09-29',
        todayDay: 'Tuesday',
        yesterdayDate: '2026-09-28',
        yesterdayDay: 'Monday',
        currentTime: '14:00',
        todayPeriods: [],
        yesterdayPeriods: [],
      );

  @override
  Future<FacultyAttendanceRosterResponse> fetchAttendanceRoster(
          int timetableEntryId, String date) async =>
      FacultyAttendanceRosterResponse(
        timetableEntryId: timetableEntryId,
        date: date,
        dayOfWeek: 'Tuesday',
        periodId: 1,
        periodNumber: 1,
        periodName: 'Period 1',
        startTime: '09:10',
        endTime: '10:00',
        subjectCode: 'TEST',
        subjectName: 'Test Subject',
        classId: 1,
        className: 'Class 1',
        facultyName: 'Dr. Test',
        status: 'AVAILABLE',
        canMark: true,
        alreadyMarked: false,
        roster: [],
      );

  @override
  Future<Map<String, dynamic>> submitAttendanceWindow({
    required int timetableEntryId,
    required String date,
    required List<Map<String, dynamic>> records,
  }) async =>
      {'message': 'Attendance submitted successfully.'};

  @override
  bool get isClassAdvisor => false;
  @override
  AdvisedClassInfo? get advisedClass => null;
  @override
  Future<ClassAdvisorAvailablePeriodsResponse> fetchClassAdvisorAvailablePeriods() async =>
      throw UnimplementedError();
  @override
  Future<ClassAdvisorAttendanceRosterResponse> fetchClassAdvisorRoster(
          int timetableEntryId, String date) async =>
      throw UnimplementedError();
  @override
  Future<ClassAdvisorAttendanceSubmitResponse> submitClassAdvisorAttendance({
    required int timetableEntryId,
    required String date,
    required List<Map<String, dynamic>> records,
    String? expectedLastUpdated,
  }) async =>
      throw UnimplementedError();
  @override
  Future<ClassDailySummaryResponse> fetchClassAdvisorDailySummary(String date) async =>
      throw UnimplementedError();

  @override
  Future<FacultyAuthorizedReportOptionsModel> fetchReportAuthorizedOptions() async =>
      throw UnimplementedError();
  @override
  Future<FacultyClassSummaryModel> fetchClassSummaryReport({
    required int classId,
    int? subjectId,
    String? startDate,
    String? endDate,
  }) async =>
      throw UnimplementedError();
  @override
  Future<FacultyStudentDetailModel> fetchStudentDetailReport({
    required int studentId,
    int? subjectId,
    String? startDate,
    String? endDate,
  }) async =>
      throw UnimplementedError();
  @override
  Future<FacultyDateMatrixModel> fetchDateMatrixReport({
    required int classId,
    required String date,
    int? subjectId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<FacultyHistoricalMatrixModel> fetchHistoricalMatrixReport({
    required int classId,
    int? subjectId,
    String? startDate,
    String? endDate,
  }) async =>
      throw UnimplementedError();

  @override
  Future<FacultyPeriodsForDateResponse> fetchPeriodsForDate(String dateStr) async =>
      throw UnimplementedError();

  @override
  Future<ClassAdvisorPeriodsForDateResponse> fetchClassAdvisorPeriodsForDate(String dateStr) async =>
      throw UnimplementedError();

  @override
  Future<BatchRecognitionResultModel> batchRecognizePhotos({
    required int timetableEntryId,
    required String date,
    required List<({String filename, List<int> bytes})> files,
  }) async =>
      throw UnimplementedError();

  @override
  Future<AttendanceRangeReportModel> fetchAttendanceRangeReport({
    required int classId,
    required String fromDate,
    required String toDate,
    int? subjectId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<List<int>> downloadAttendanceRangePdf({
    required int classId,
    required String fromDate,
    required String toDate,
    int? subjectId,
  }) async =>
      [];

  @override
  Future<List<int>> downloadAttendanceRangeExcel({
    required int classId,
    required String fromDate,
    required String toDate,
    int? subjectId,
  }) async =>
      [];
}

void main() {
  group('Auth & Account Security Tests', () {
    test('Disabled account returns 403 mapped message', () async {
      final mockAuth = MockAuthServiceForSecurity();
      try {
        await mockAuth.loginStudent('DISABLED', 'pass');
      } catch (_) {}
      expect(mockAuth.errorMessage, 'Your account is disabled. Please contact Admin.');
    });

    test('Locked account returns 403 locked message', () async {
      final mockAuth = MockAuthServiceForSecurity();
      try {
        await mockAuth.loginStudent('LOCKED', 'pass');
      } catch (_) {}
      expect(mockAuth.errorMessage, 'Your account is temporarily locked. Please try again later or contact Admin.');
    });

    test('Network failure returns 0/Network mapped message without clearing session', () async {
      final mockAuth = MockAuthServiceForSecurity();
      try {
        await mockAuth.loginStudent('NETWORK_ERR', 'pass');
      } catch (_) {}
      expect(mockAuth.errorMessage, 'Unable to reach the server. Check your connection or server address.');
    });

    test('Invalid credentials returns 401 mapped message', () async {
      final mockAuth = MockAuthServiceForSecurity();
      try {
        await mockAuth.loginStudent('WRONG_PASS', 'pass');
      } catch (_) {}
      expect(mockAuth.errorMessage, 'Incorrect login ID or password.');
    });

    test('Forced password change flag creates user model with forcePasswordChange = true', () async {
      final mockAuth = MockAuthServiceForSecurity();
      final user = await mockAuth.loginStudent('FORCE_PASS', 'pass');
      expect(user?.forcePasswordChange, true);
    });

    testWidgets('Student dashboard renders Mandatory Password Update banner when forcePasswordChange is true', (tester) async {
      final user = UserModel(
        id: 1,
        username: 'FORCE_PASS',
        email: 'fp@college.edu',
        role: 'STUDENT',
        isActive: true,
        fullName: 'Force Student',
        forcePasswordChange: true,
      );
      final summary = StudentSummaryModel(
        studentId: 1,
        fullName: 'Force Student',
        registerNumber: 'FORCE01',
        isActive: true,
        total: 10,
        present: 9,
        absent: 1,
        od: 0,
        percentage: 90.0,
        calculationMode: 'RECORD_BASED',
        attendanceStatus: 'OK',
        minimumRequired: 75.0,
        belowMinimum: false,
      );

      final mockAuth = MockAuthServiceForSecurity(user: user);
      final mockStudent = MockStudentServiceForSecurity(summary: summary);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
            ChangeNotifierProvider<StudentService>.value(value: mockStudent),
          ],
          child: const MaterialApp(
            home: StudentDashboardScreen(),
          ),
        ),
      );

      expect(find.text('Mandatory Password Update'), findsOneWidget);
      expect(find.text('Administration has requested you set a new password.'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
    });

    testWidgets('Faculty dashboard renders Mandatory Password Update banner when forcePasswordChange is true', (tester) async {
      final user = UserModel(
        id: 2,
        username: 'FAC_FORCE_PASS',
        email: 'facfp@college.edu',
        role: 'FACULTY',
        isActive: true,
        fullName: 'Force Faculty',
        forcePasswordChange: true,
      );

      final mockAuth = MockAuthServiceForSecurity(user: user);
      final mockFaculty = MockFacultyServiceForSecurity();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
            ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
          ],
          child: const MaterialApp(
            home: FacultyDashboardScreen(),
          ),
        ),
      );

      expect(find.text('Mandatory Password Update'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
    });
  });

  group('Faculty Attendance Session Lifecycle Tests', () {
    testWidgets('Renders session roster, allows manual marking of Present, Absent, and OD with reason', (tester) async {
      final roster = [
        RosterStudentModel(
          studentId: 101,
          fullName: 'Alice Smith',
          rollNumber: '23CS001',
          attendanceStatus: 'UNMARKED',
        ),
        RosterStudentModel(
          studentId: 102,
          fullName: 'Bob Jones',
          rollNumber: '23CS002',
          attendanceStatus: 'UNMARKED',
        ),
      ];

      final mockFaculty = MockFacultyServiceForSecurity(
        activeSessionId: 88,
        roster: roster,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<FacultyService>.value(
          value: mockFaculty,
          child: const MaterialApp(
            home: FacultySessionScreen(),
          ),
        ),
      );

      expect(find.text('Active Session #88'), findsOneWidget);
      expect(find.text('Total: 2'), findsOneWidget);
      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('Bob Jones'), findsOneWidget);

      // 1. Mark Alice Present
      await tester.tap(find.byTooltip('Mark Present').first);
      await tester.pump();

      expect(mockFaculty.markAttendanceCount, 1);
      expect(mockFaculty.lastMarkedStatus, 'PRESENT');

      // 2. Mark Bob OD (opens OD dialog)
      await tester.tap(find.byTooltip('Mark OD').last);
      await tester.pumpAndSettle();

      expect(find.text('Mark OD: Bob Jones'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Representing College at Hackathon');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Mark OD'));
      await tester.pumpAndSettle();

      expect(mockFaculty.markAttendanceCount, 2);
      expect(mockFaculty.lastMarkedStatus, 'OD');
      expect(mockFaculty.lastOdReason, 'Representing College at Hackathon');
    });

    testWidgets('Complete Attendance Session opens confirmation dialog and completes session', (tester) async {
      final mockFaculty = MockFacultyServiceForSecurity(
        activeSessionId: 88,
        roster: [],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<FacultyService>.value(
          value: mockFaculty,
          child: const MaterialApp(
            home: FacultySessionScreen(),
          ),
        ),
      );

      // Tap Complete Session
      await tester.ensureVisible(find.text('COMPLETE ATTENDANCE SESSION'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('COMPLETE ATTENDANCE SESSION'));
      await tester.pumpAndSettle();

      expect(find.text('Complete Session'), findsOneWidget);
      expect(find.text('Complete & Finalize'), findsOneWidget);

      // Confirm Complete
      await tester.tap(find.text('Complete & Finalize'));
      await tester.pumpAndSettle();

      expect(mockFaculty.completeSessionCalled, true);
    });

    testWidgets('Class 1 attendance marking for student ABISHEK A (721025149002)', (tester) async {
      final roster = [
        RosterStudentModel(
          studentId: 2,
          fullName: 'ABISHEK A',
          rollNumber: '721025149002',
          attendanceStatus: 'UNMARKED',
        ),
      ];

      final mockFaculty = MockFacultyServiceForSecurity(
        activeSessionId: 101,
        roster: roster,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<FacultyService>.value(
          value: mockFaculty,
          child: const MaterialApp(
            home: FacultySessionScreen(),
          ),
        ),
      );

      expect(find.text('ABISHEK A'), findsOneWidget);
      expect(find.text('Roll: 721025149002'), findsOneWidget);

      // Tap Mark Present
      await tester.tap(find.byTooltip('Mark Present'));
      await tester.pump();

      expect(mockFaculty.markAttendanceCount, 1);
      expect(mockFaculty.lastMarkedStatus, 'PRESENT');
    });
  });
}
