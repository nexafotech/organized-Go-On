import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/models/user_model.dart';
import 'package:attendance_marker_mobile/models/faculty_model.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/services/auth_service.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_dashboard_screen.dart';

class MockAuth extends ChangeNotifier implements AuthService {
  UserModel? _user = UserModel(
    id: 7,
    username: 'fac04',
    fullName: 'Shankar',
    email: 'shankar@test.com',
    role: 'FACULTY',
    isActive: true,
  );
  @override UserModel? get currentUser => _user;
  @override bool get isAuthenticated => true;
  @override bool get isLoading => false;
  @override String? get errorMessage => null;
  @override Future<void> logout() async {}
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFaculty extends ChangeNotifier implements FacultyService {
  List<FacultyScheduleItem> _schedule = [];
  ActiveClassSlot? _activeSlot;
  bool _hasActiveSlot = false;
  int? _activeSessionId;
  String? _activeSessionStatus;
  List<RosterStudentModel> _roster = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool loadDashboardDataCalled = false;
  bool fetchScheduleCalled = false;

  @override List<FacultyScheduleItem> get schedule => _schedule;
  @override ActiveClassSlot? get activeSlot => _activeSlot;
  @override bool get hasActiveSlot => _hasActiveSlot;
  @override int? get activeSessionId => _activeSessionId;
  @override String? get activeSessionStatus => _activeSessionStatus;
  @override List<RosterStudentModel> get roster => _roster;
  @override bool get isLoading => _isLoading;
  @override String? get errorMessage => _errorMessage;
  @override bool get isClassAdvisor => false;
  @override AdvisedClassInfo? get advisedClass => null;

  @override
  Future<void> loadDashboardData() async {
    loadDashboardDataCalled = true;
    notifyListeners();
  }

  @override
  Future<void> fetchSchedule() async {
    fetchScheduleCalled = true;
    notifyListeners();
  }

  @override Future<void> checkActiveClassSlot() async {}
  @override Future<void> checkActiveSession() async {}

  @override
  Future<AvailablePeriodsResponse> fetchAvailableAttendancePeriods() async {
    return AvailablePeriodsResponse(
      todayDate: '2026-09-30',
      todayDay: 'Wednesday',
      yesterdayDate: '2026-09-29',
      yesterdayDay: 'Tuesday',
      currentTime: '10:00',
      todayPeriods: [
        AvailablePeriodItem(
          timetableEntryId: 1,
          periodId: 1,
          periodNumber: 1,
          periodName: 'Period 1',
          startTime: '09:10',
          endTime: '10:00',
          subjectCode: 'SDBMS',
          subjectName: 'Secure Database',
          classId: 1,
          className: 'III Year CSE',
          date: '2026-09-30',
          dayOfWeek: 'Wednesday',
          facultyName: 'Shankar',
          status: 'AVAILABLE',
          canMark: true,
        ),
      ],
      yesterdayPeriods: [],
    );
  }

  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('Safe Map casting unit test in AvailablePeriodsResponse and FacultyAttendanceRosterResponse', () {
    // Simulating dynamic Map from jsonDecode where nested maps are typed as Map<dynamic, dynamic>
    final dynamic rawPeriodsData = <dynamic, dynamic>{
      'today_date': '2026-09-30',
      'today_day': 'Wednesday',
      'yesterday_date': '2026-09-29',
      'yesterday_day': 'Tuesday',
      'current_time': '10:00',
      'today_periods': <dynamic>[
        <dynamic, dynamic>{
          'timetable_entry_id': 101,
          'period_id': 1,
          'period_number': 1,
          'period_name': 'Period 1',
          'start_time': '09:10',
          'end_time': '10:00',
          'subject_code': 'SEC01',
          'subject_name': 'Network Security',
          'class_id': 2,
          'class_name': 'III Year CSE',
          'date': '2026-09-30',
          'day_of_week': 'Wednesday',
          'faculty_name': 'Dr. Shankar',
          'status': 'AVAILABLE',
          'can_mark': true,
        }
      ],
      'yesterday_periods': <dynamic>[
        <dynamic, dynamic>{
          'timetable_entry_id': 102,
          'period_id': 2,
          'period_number': 2,
          'period_name': 'Period 2',
          'start_time': '10:00',
          'end_time': '10:50',
          'subject_code': 'SEC02',
          'subject_name': 'Cryptography',
          'class_id': 2,
          'class_name': 'III Year CSE',
          'date': '2026-09-29',
          'day_of_week': 'Tuesday',
          'faculty_name': 'Dr. Shankar',
          'status': 'AVAILABLE',
          'can_mark': true,
        }
      ],
    };

    final periodsParsed = AvailablePeriodsResponse.fromJson(Map<String, dynamic>.from(rawPeriodsData));
    expect(periodsParsed.todayPeriods.length, 1);
    expect(periodsParsed.todayPeriods.first.subjectCode, 'SEC01');
    expect(periodsParsed.yesterdayPeriods.length, 1);
    expect(periodsParsed.yesterdayPeriods.first.subjectCode, 'SEC02');

    final dynamic rawRosterData = <dynamic, dynamic>{
      'timetable_entry_id': 101,
      'date': '2026-09-30',
      'day_of_week': 'Wednesday',
      'period_id': 1,
      'period_number': 1,
      'period_name': 'Period 1',
      'start_time': '09:10',
      'end_time': '10:00',
      'subject_code': 'SEC01',
      'subject_name': 'Network Security',
      'class_id': 2,
      'class_name': 'III Year CSE',
      'faculty_name': 'Dr. Shankar',
      'status': 'AVAILABLE',
      'can_mark': true,
      'already_marked': false,
      'roster': <dynamic>[
        <dynamic, dynamic>{
          'student_id': 501,
          'roll_number': '21CS001',
          'full_name': 'Alice Johnson',
          'email': 'alice@example.com',
          'attendance_status': 'PRESENT',
        }
      ],
    };

    final rosterParsed = FacultyAttendanceRosterResponse.fromJson(Map<String, dynamic>.from(rawRosterData));
    expect(rosterParsed.roster.length, 1);
    expect(rosterParsed.roster.first.fullName, 'Alice Johnson');
  });

  testWidgets('Faculty Dashboard with attendance data loaded and smooth tab switching', (tester) async {
    final mockAuth = MockAuth();
    final mockFaculty = MockFaculty();

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

    // Initial frame
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Faculty Dashboard'), findsOneWidget);
    expect(find.text('Shankar'), findsOneWidget);
    expect(find.text('Faculty ID: fac04'), findsOneWidget);

    // Switch to Attendance tab
    await tester.tap(find.text('Attendance'));
    await tester.pumpAndSettle();

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('YESTERDAY'), findsOneWidget);
    expect(find.text('Secure Database (SDBMS)'), findsOneWidget);
    expect(find.text('AVAILABLE'), findsOneWidget);

    // Switch to Timetable tab
    await tester.tap(find.text('Timetable'));
    await tester.pumpAndSettle();
    expect(find.text('Faculty Timetable'), findsOneWidget);

    // Switch to Profile tab
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Faculty Profile'), findsOneWidget);
    expect(find.text('Identifier: fac04'), findsOneWidget);

    // Switch back to Dashboard
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Faculty Dashboard'), findsOneWidget);
  });

  testWidgets('Faculty Dashboard loading state renders spinner and does not blank screen', (tester) async {
    final mockAuth = MockAuth();
    final mockFaculty = MockFaculty();
    mockFaculty._isLoading = true;

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

    await tester.pump();
    expect(find.text('Faculty Dashboard'), findsOneWidget);
    expect(find.text('Shankar'), findsOneWidget);
    expect(find.text('Loading faculty dashboard data...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('Faculty Dashboard when APIs fail does not blank and shows error/retry', (tester) async {
    final mockAuth = MockAuth();
    final mockFaculty = MockFaculty();
    mockFaculty._errorMessage = 'Unable to reach server';

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

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Faculty Dashboard'), findsOneWidget);
    // Should still show header with faculty identity
    expect(find.text('Shankar'), findsOneWidget);
    expect(find.text('Schedule Data Unavailable'), findsOneWidget);
    expect(find.text('Unable to reach server'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);

    // Tap retry
    await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
    await tester.pump();
    expect(mockFaculty.loadDashboardDataCalled, isTrue);
  });

  testWidgets('Faculty Timetable tab shows error and retry button when timetable fails to load', (tester) async {
    final mockAuth = MockAuth();
    final mockFaculty = MockFaculty();
    mockFaculty._errorMessage = 'Connection timeout';

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

    await tester.pumpAndSettle();

    // Switch to Timetable tab
    await tester.tap(find.text('Timetable'));
    await tester.pumpAndSettle();

    expect(find.text('Faculty Timetable'), findsOneWidget);
    expect(find.text('Timetable Unavailable'), findsOneWidget);
    expect(find.text('Connection timeout'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);

    // Tap retry in timetable tab
    await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
    await tester.pump();
    expect(mockFaculty.fetchScheduleCalled, isTrue);
  });
}
