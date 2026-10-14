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
import 'package:attendance_marker_mobile/student/screens/student_timetable_screen.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_dashboard_screen.dart';

class MockStudentServiceForTimetable extends ChangeNotifier implements StudentService {
  List<TimetableItemModel> _timetable = [];
  bool _isLoading = false;
  String? _errorMessage;

  MockStudentServiceForTimetable({
    List<TimetableItemModel>? timetable,
    bool isLoading = false,
    String? errorMessage,
  })  : _timetable = timetable ?? [],
        _isLoading = isLoading,
        _errorMessage = errorMessage;

  @override
  StudentSummaryModel? get summary => null;
  @override
  List<SubjectAttendanceModel> get subjects => [];
  @override
  List<TimetableItemModel> get timetable => _timetable;
  @override
  List<DateWiseEntryModel> get dateWise => [];
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
  Future<void> loadDashboardData() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFacultyServiceForTimetable extends ChangeNotifier implements FacultyService {
  List<FacultyScheduleItem> _schedule = [];
  ActiveClassSlot? _activeSlot;
  bool _hasActiveSlot = false;
  int? _activeSessionId;
  String? _activeSessionStatus;
  List<RosterStudentModel> _roster = [];
  bool _isLoading = false;
  String? _errorMessage;

  MockFacultyServiceForTimetable({
    List<FacultyScheduleItem>? schedule,
    ActiveClassSlot? activeSlot,
    bool hasActiveSlot = false,
    int? activeSessionId,
  })  : _schedule = schedule ?? [],
        _activeSlot = activeSlot,
        _hasActiveSlot = hasActiveSlot,
        _activeSessionId = activeSessionId;

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
  Future<void> markAttendance({required int studentId, required String status, String? odReason}) async {}
  @override
  Future<void> completeSession() async {}
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
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAuthServiceForTimetable extends ChangeNotifier implements AuthService {
  final UserModel _user = UserModel(
    id: 1,
    username: 'FAC_DEMO',
    email: 'fac@college.edu',
    role: 'FACULTY',
    isActive: true,
    fullName: 'Professor X',
  );

  @override
  UserModel? get currentUser => _user;
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  bool get sessionExpired => false;
  @override
  bool get isAuthenticated => true;

  @override
  void clearErrorMessage() {}
  @override
  void clearSessionExpired() {}
  @override
  Future<UserModel?> loginStudent(String identifier, String password) async => null;
  @override
  Future<UserModel?> loginFaculty(String usernameOrEmail, String password) async => null;
  @override
  Future<UserModel?> restoreSession() async => _user;
  @override
  Future<bool> changePassword({required String currentPassword, required String newPassword}) async => true;
  @override
  Future<void> logout() async {}
  @override
  Future<Map<String, dynamic>> validateIdentifier(String identifier, {String role = 'FACULTY'}) async =>
      {'valid': true, 'role': role, 'message': null, 'is_network_error': false};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Student Timetable UX Tests', () {
    testWidgets('Renders all weekday buttons Mon through Sat', (tester) async {
      final mockStudent = MockStudentServiceForTimetable();

      await tester.pumpWidget(
        ChangeNotifierProvider<StudentService>.value(
          value: mockStudent,
          child: const MaterialApp(
            home: Scaffold(body: StudentTimetableScreen()),
          ),
        ),
      );

      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
    });

    testWidgets('Renders period cards with subject, code, time, and faculty', (tester) async {
      final timetable = [
        TimetableItemModel(
          dayOfWeek: 'MONDAY',
          periodNumber: 1,
          periodName: 'Period 1',
          startTime: '09:00',
          endTime: '09:50',
          subjectCode: '23CS101',
          subjectName: 'Data Structures',
          facultyName: 'Dr. John Doe',
        ),
        TimetableItemModel(
          dayOfWeek: 'MONDAY',
          periodNumber: 2,
          periodName: 'Period 2',
          startTime: '10:00',
          endTime: '10:50',
          subjectCode: '23CS102',
          subjectName: 'Algorithms',
          facultyName: 'Dr. Ada Lovelace',
        ),
        TimetableItemModel(
          dayOfWeek: 'TUESDAY',
          periodNumber: 1,
          periodName: 'Period 1',
          startTime: '09:00',
          endTime: '09:50',
          subjectCode: '23CS103',
          subjectName: 'Operating Systems',
          facultyName: 'Dr. Ken Thompson',
        ),
      ];

      final mockStudent = MockStudentServiceForTimetable(timetable: timetable);

      await tester.pumpWidget(
        ChangeNotifierProvider<StudentService>.value(
          value: mockStudent,
          child: const MaterialApp(
            home: Scaffold(body: StudentTimetableScreen()),
          ),
        ),
      );

      // Select Monday
      await tester.tap(find.text('Mon'));
      await tester.pump();

      expect(find.text('Data Structures'), findsOneWidget);
      expect(find.text('Code: 23CS101'), findsOneWidget);
      expect(find.text('09:00 - 09:50'), findsOneWidget);
      expect(find.text('Faculty: Dr. John Doe'), findsOneWidget);
      expect(find.text('P1'), findsOneWidget);

      expect(find.text('Algorithms'), findsOneWidget);
      expect(find.text('Code: 23CS102'), findsOneWidget);
      expect(find.text('P2'), findsOneWidget);

      // Select Tuesday
      await tester.tap(find.text('Tue'));
      await tester.pump();

      expect(find.text('Operating Systems'), findsOneWidget);
      expect(find.text('Code: 23CS103'), findsOneWidget);
      expect(find.text('Data Structures'), findsNothing);
    });

    testWidgets('Renders Faculty assignment pending when slot faculty is unassigned', (tester) async {
      final timetable = [
        TimetableItemModel(
          dayOfWeek: 'MONDAY',
          periodNumber: 1,
          periodName: 'Period 1',
          startTime: '09:00',
          endTime: '09:50',
          subjectCode: '23CS101',
          subjectName: 'Data Structures',
          facultyName: null,
        ),
      ];

      final mockStudent = MockStudentServiceForTimetable(timetable: timetable);

      await tester.pumpWidget(
        ChangeNotifierProvider<StudentService>.value(
          value: mockStudent,
          child: const MaterialApp(
            home: Scaffold(body: StudentTimetableScreen()),
          ),
        ),
      );

      await tester.tap(find.text('Mon'));
      await tester.pump();

      expect(find.text('Faculty: Faculty assignment pending'), findsOneWidget);
    });

    testWidgets('Renders empty state when day has no classes', (tester) async {
      final mockStudent = MockStudentServiceForTimetable(timetable: []);

      await tester.pumpWidget(
        ChangeNotifierProvider<StudentService>.value(
          value: mockStudent,
          child: const MaterialApp(
            home: Scaffold(body: StudentTimetableScreen()),
          ),
        ),
      );

      await tester.tap(find.text('Sat'));
      await tester.pump();

      expect(find.text('No Classes on SATURDAY'), findsOneWidget);
      expect(find.text('No timetable schedule entries configured for this day.'), findsOneWidget);
    });

    testWidgets('Renders error state when timetable fails with retry button', (tester) async {
      final mockStudent = MockStudentServiceForTimetable(
        errorMessage: 'Unable to connect to server',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<StudentService>.value(
          value: mockStudent,
          child: const MaterialApp(
            home: Scaffold(body: StudentTimetableScreen()),
          ),
        ),
      );

      expect(find.text('Timetable Unavailable'), findsOneWidget);
      expect(find.text('Unable to connect to server'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('Faculty Dashboard Timetable Tests', () {
    testWidgets('Renders active class card with Start Attendance button when slot active', (tester) async {
      final activeSlot = ActiveClassSlot(
        timetableEntryId: 10,
        assignmentId: 2,
        dayOfWeek: 'MONDAY',
        date: '2026-08-18',
        periodNumber: 3,
        periodName: 'Period 3',
        startTime: '11:00',
        endTime: '11:50',
        subjectCode: '23CY301',
        subjectName: 'Network Security',
        className: 'II Year CSE - Cyber Security',
        classId: 1,
        subjectId: 5,
      );

      final mockFaculty = MockFacultyServiceForTimetable(
        activeSlot: activeSlot,
        hasActiveSlot: true,
      );
      final mockAuth = MockAuthServiceForTimetable();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
          ],
          child: const MaterialApp(
            home: FacultyDashboardScreen(),
          ),
        ),
      );

      expect(find.text('ACTIVE NOW'), findsOneWidget);
      expect(find.text('Network Security (23CY301)'), findsOneWidget);
      expect(find.text('II Year CSE - Cyber Security'), findsOneWidget);
      expect(find.text('P3'), findsOneWidget);
      expect(find.text('START ATTENDANCE SESSION'), findsOneWidget);
    });

    testWidgets('Renders active session banner when session is in progress', (tester) async {
      final mockFaculty = MockFacultyServiceForTimetable(
        activeSessionId: 42,
      );
      final mockAuth = MockAuthServiceForTimetable();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
          ],
          child: const MaterialApp(
            home: FacultyDashboardScreen(),
          ),
        ),
      );

      expect(find.text('Attendance Session In Progress'), findsOneWidget);
      expect(find.text('RESUME ATTENDANCE SESSION'), findsOneWidget);
    });

    testWidgets('Switches to Timetable tab and renders weekly schedule', (tester) async {
      final schedule = [
        FacultyScheduleItem(
          id: 1,
          dayOfWeek: 'MONDAY',
          periodId: 1,
          periodNumber: 1,
          periodName: 'Period 1',
          startTime: '09:00',
          endTime: '09:50',
          assignmentId: 1,
          subjectCode: '23CS201',
          subjectName: 'Database Systems',
          className: 'II Year CSE - Section A',
        ),
      ];

      final mockFaculty = MockFacultyServiceForTimetable(schedule: schedule);
      final mockAuth = MockAuthServiceForTimetable();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
          ],
          child: const MaterialApp(
            home: FacultyDashboardScreen(),
          ),
        ),
      );

      // Tap Timetable tab in bottom navigation
      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      // Select Mon
      await tester.tap(find.text('Mon'));
      await tester.pump();

      expect(find.text('Database Systems'), findsOneWidget);
      expect(find.text('Code: 23CS201 | Class: II Year CSE - Section A'), findsOneWidget);
    });

    testWidgets('Responsive Layout Test: Long class name does not cause horizontal overflow', (tester) async {
      // Set realistic phone screen dimensions (Realme Narzo 70 Pro 5G / standard viewport 390x844)
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final longSlot = ActiveClassSlot(
        timetableEntryId: 99,
        assignmentId: 42,
        dayOfWeek: 'Tuesday',
        date: '2026-09-29',
        periodNumber: 3,
        periodName: 'Period 3',
        startTime: '11:10',
        endTime: '12:00',
        subjectCode: 'ESSS',
        subjectName: 'Engineering Secure Software Systems',
        className: 'III Year CSE Cyber Security - Class 2',
        classId: 5,
        subjectId: 28,
      );

      final schedule = [
        FacultyScheduleItem(
          id: 101,
          dayOfWeek: 'Tuesday',
          periodId: 3,
          periodNumber: 3,
          periodName: 'Period 3',
          startTime: '11:10',
          endTime: '12:00',
          assignmentId: 42,
          subjectCode: 'ESSS',
          subjectName: 'Engineering Secure Software Systems',
          className: 'III Year CSE Cyber Security - Class 2',
          facultyName: 'Lakshmi Narayanan',
        ),
      ];

      final mockFaculty = MockFacultyServiceForTimetable(
        activeSlot: longSlot,
        hasActiveSlot: true,
        schedule: schedule,
      );
      final mockAuth = MockAuthServiceForTimetable();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
          ],
          child: const MaterialApp(
            home: FacultyDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify no overflow errors were thrown during layout
      expect(tester.takeException(), isNull);

      // Verify elements are present and rendered
      expect(find.text('ACTIVE NOW'), findsOneWidget);
      expect(find.text('Engineering Secure Software Systems (ESSS)'), findsOneWidget);
      expect(find.text('III Year CSE Cyber Security - Class 2'), findsWidgets);
      expect(find.text('P3'), findsWidgets);
      expect(find.text('11:10 - 12:00'), findsWidgets);
      expect(find.text('START ATTENDANCE SESSION'), findsOneWidget);
      expect(find.text('Professor X'), findsOneWidget);
    });
  });
}
