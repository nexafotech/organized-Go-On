import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/models/user_model.dart';
import 'package:attendance_marker_mobile/models/faculty_model.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/services/auth_service.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_dashboard_screen.dart';

class MockAuthForSessionCount extends ChangeNotifier implements AuthService {
  final UserModel _user = UserModel(
    id: 7,
    username: 'fac05',
    fullName: 'Santhiya',
    email: 'santhiya@go-on.edu',
    role: 'FACULTY',
    isActive: true,
  );

  @override
  UserModel? get currentUser => _user;
  @override
  bool get isAuthenticated => true;
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  Future<void> logout() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFacultyForSessionCount extends ChangeNotifier implements FacultyService {
  List<FacultyScheduleItem> _schedule;
  List<FacultyScheduleItem> _classAdvisorSchedule;
  String? _classAdvisorClassName;
  bool _isLoading;
  String? _errorMessage;
  bool _isScheduleLoading;
  String? _scheduleErrorMessage;
  bool _isClassAdvisorScheduleLoading;
  String? _classAdvisorScheduleErrorMessage;
  bool _isClassAdvisor;

  int fetchScheduleCallCount = 0;
  int fetchClassAdvisorTimetableCallCount = 0;

  MockFacultyForSessionCount({
    List<FacultyScheduleItem>? schedule,
    List<FacultyScheduleItem>? classAdvisorSchedule,
    String? classAdvisorClassName,
    bool isLoading = false,
    String? errorMessage,
    bool isScheduleLoading = false,
    String? scheduleErrorMessage,
    bool isClassAdvisorScheduleLoading = false,
    String? classAdvisorScheduleErrorMessage,
    bool isClassAdvisor = false,
  })  : _schedule = schedule ?? [],
        _classAdvisorSchedule = classAdvisorSchedule ?? [],
        _classAdvisorClassName = classAdvisorClassName,
        _isLoading = isLoading,
        _errorMessage = errorMessage,
        _isScheduleLoading = isScheduleLoading,
        _scheduleErrorMessage = scheduleErrorMessage,
        _isClassAdvisorScheduleLoading = isClassAdvisorScheduleLoading,
        _classAdvisorScheduleErrorMessage = classAdvisorScheduleErrorMessage,
        _isClassAdvisor = isClassAdvisor;

  @override
  List<FacultyScheduleItem> get schedule => _schedule;
  @override
  List<FacultyScheduleItem> get classAdvisorSchedule => _classAdvisorSchedule;
  @override
  String? get classAdvisorClassName => _classAdvisorClassName;
  @override
  bool get isLoading => _isLoading;
  @override
  String? get errorMessage => _errorMessage;
  @override
  bool get isScheduleLoading => _isScheduleLoading;
  @override
  String? get scheduleErrorMessage => _scheduleErrorMessage;
  @override
  bool get isClassAdvisorScheduleLoading => _isClassAdvisorScheduleLoading;
  @override
  String? get classAdvisorScheduleErrorMessage => _classAdvisorScheduleErrorMessage;
  @override
  bool get isClassAdvisor => _isClassAdvisor;
  @override
  AdvisedClassInfo? get advisedClass => null;
  @override
  ActiveClassSlot? get activeSlot => null;
  @override
  bool get hasActiveSlot => false;
  @override
  int? get activeSessionId => null;
  @override
  String? get activeSessionStatus => null;

  @override
  Future<void> loadDashboardData() async {}

  @override
  Future<void> fetchSchedule() async {
    fetchScheduleCallCount++;
  }

  @override
  Future<void> fetchClassAdvisorTimetable() async {
    fetchClassAdvisorTimetableCallCount++;
  }

  void updateSchedule({
    List<FacultyScheduleItem>? schedule,
    bool? isScheduleLoading,
    String? scheduleErrorMessage,
    String? errorMessage,
  }) {
    if (schedule != null) _schedule = schedule;
    if (isScheduleLoading != null) _isScheduleLoading = isScheduleLoading;
    if (scheduleErrorMessage != null) _scheduleErrorMessage = scheduleErrorMessage;
    if (errorMessage != null) _errorMessage = errorMessage;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Faculty Timetable Session Count & Badge State Machine Tests', () {
    // 1. Single session day (Foundations of Data Science)
    final singleSessionSchedule = [
      FacultyScheduleItem(
        id: 701,
        dayOfWeek: 'MONDAY',
        periodId: 1,
        periodNumber: 1,
        periodName: 'Period 1',
        startTime: '09:10',
        endTime: '10:00',
        assignmentId: 7,
        subjectCode: 'CS401',
        subjectName: 'Foundations of Data Science',
        className: 'II Year CSE Cyber Security - Class 1',
        facultyName: 'Santhiya',
      ),
    ];

    // Multi-session schedule
    final multiSessionSchedule = [
      FacultyScheduleItem(
        id: 701,
        dayOfWeek: 'MONDAY',
        periodId: 1,
        periodNumber: 1,
        periodName: 'Period 1',
        startTime: '09:10',
        endTime: '10:00',
        assignmentId: 7,
        subjectCode: 'CS401',
        subjectName: 'Foundations of Data Science',
        className: 'II Year CSE Cyber Security - Class 1',
        facultyName: 'Santhiya',
      ),
      FacultyScheduleItem(
        id: 702,
        dayOfWeek: 'TUESDAY',
        periodId: 1,
        periodNumber: 1,
        periodName: 'Period 1',
        startTime: '09:10',
        endTime: '10:00',
        assignmentId: 7,
        subjectCode: 'CS401',
        subjectName: 'Foundations of Data Science',
        className: 'Class 1',
        facultyName: 'Santhiya',
      ),
      FacultyScheduleItem(
        id: 703,
        dayOfWeek: 'TUESDAY',
        periodId: 2,
        periodNumber: 2,
        periodName: 'Period 2',
        startTime: '10:00',
        endTime: '10:50',
        assignmentId: 8,
        subjectCode: 'CS402',
        subjectName: 'Machine Learning',
        className: 'Class 1',
        facultyName: 'Santhiya',
      ),
      FacultyScheduleItem(
        id: 704,
        dayOfWeek: 'TUESDAY',
        periodId: 3,
        periodNumber: 3,
        periodName: 'Period 3',
        startTime: '11:10',
        endTime: '12:00',
        assignmentId: 9,
        subjectCode: 'CS403',
        subjectName: 'Deep Learning Lab',
        className: 'Class 1',
        facultyName: 'Santhiya',
      ),
    ];

    Widget buildTestApp(MockFacultyForSessionCount mockFaculty, [MockAuthForSessionCount? mockAuth]) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
          ChangeNotifierProvider<AuthService>.value(value: mockAuth ?? MockAuthForSessionCount()),
        ],
        child: const MaterialApp(
          home: FacultyDashboardScreen(),
        ),
      );
    }

    testWidgets('Monday with 1 session displays "1 Session" badge and card', (tester) async {
      final mockFaculty = MockFacultyForSessionCount(schedule: singleSessionSchedule);

      await tester.pumpWidget(buildTestApp(mockFaculty));
      await tester.pumpAndSettle();

      // Navigate to Timetable tab
      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      // Tap Monday
      await tester.tap(find.text('Mon'));
      await tester.pumpAndSettle();

      // Verify the badge displays "1 Session"
      expect(find.byKey(const Key('timetable_session_count_badge')), findsOneWidget);
      expect(find.text('1 Session'), findsOneWidget);

      // Verify card content
      expect(find.text('Foundations of Data Science'), findsOneWidget);
      expect(find.textContaining('Period 1'), findsOneWidget);
    });

    testWidgets('Tuesday with 3 sessions displays "3 Sessions" badge', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockFaculty = MockFacultyForSessionCount(schedule: multiSessionSchedule);

      await tester.pumpWidget(buildTestApp(mockFaculty));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tue'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('timetable_session_count_badge')), findsOneWidget);
      expect(find.text('3 Sessions'), findsOneWidget);
      expect(find.text('Foundations of Data Science'), findsOneWidget);
      expect(find.text('Machine Learning'), findsOneWidget);
      expect(find.text('Deep Learning Lab'), findsOneWidget);
    });

    testWidgets('Day with 0 sessions displays "0 Sessions" and empty state', (tester) async {
      final mockFaculty = MockFacultyForSessionCount(schedule: singleSessionSchedule);

      await tester.pumpWidget(buildTestApp(mockFaculty));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      // Tap Thursday (0 sessions scheduled)
      await tester.tap(find.text('Thu'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('timetable_session_count_badge')), findsOneWidget);
      expect(find.text('0 Sessions'), findsOneWidget);
      expect(find.textContaining('No Classes'), findsWidgets);
    });

    testWidgets('Weekend (Sunday) displays "0 Sessions" and weekend resting state', (tester) async {
      final mockFaculty = MockFacultyForSessionCount(schedule: singleSessionSchedule);

      await tester.pumpWidget(buildTestApp(mockFaculty));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sun'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('timetable_session_count_badge')), findsOneWidget);
      expect(find.text('0 Sessions'), findsOneWidget);
      expect(find.textContaining('Sunday has no scheduled classes'), findsOneWidget);
    });

    testWidgets('CRITICAL: Attendance errorMessage does NOT cause badge to display "Error"', (tester) async {
      // In this scenario, an attendance or photo API call failed, setting facultyService.errorMessage.
      // But the timetable schedule was successfully fetched!
      final mockFaculty = MockFacultyForSessionCount(
        schedule: singleSessionSchedule,
        errorMessage: 'Failed to recognize faces in attendance photo',
        scheduleErrorMessage: null, // Schedule is valid!
      );

      await tester.pumpWidget(buildTestApp(mockFaculty));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mon'));
      await tester.pumpAndSettle();

      // The badge must NOT say "Error", it MUST say "1 Session"!
      expect(find.text('Error'), findsNothing);
      expect(find.byKey(const Key('timetable_session_count_badge_error')), findsNothing);
      expect(find.byKey(const Key('timetable_session_count_badge')), findsOneWidget);
      expect(find.text('1 Session'), findsOneWidget);
      expect(find.text('Foundations of Data Science'), findsOneWidget);
    });

    testWidgets('Network failure with empty schedule displays Retry badge and tapping triggers fetchSchedule', (tester) async {
      final mockFaculty = MockFacultyForSessionCount(
        schedule: [],
        scheduleErrorMessage: 'Failed to connect to timetable server',
      );

      await tester.pumpWidget(buildTestApp(mockFaculty));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      // Badge must show Retry error state
      expect(find.byKey(const Key('timetable_session_count_badge_error')), findsOneWidget);
      expect(find.text('Retry'), findsWidgets);

      // Tap the badge retry
      await tester.tap(find.byKey(const Key('timetable_session_count_badge_error')));
      await tester.pumpAndSettle();

      // Verify fetchSchedule was invoked
      expect(mockFaculty.fetchScheduleCallCount, greaterThan(0));
    });

    testWidgets('Network failure with cached schedule keeps displaying verified session count', (tester) async {
      // If timetable was already loaded and a background refresh failed:
      final mockFaculty = MockFacultyForSessionCount(
        schedule: singleSessionSchedule,
        scheduleErrorMessage: 'Background refresh timed out',
      );

      await tester.pumpWidget(buildTestApp(mockFaculty));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mon'));
      await tester.pumpAndSettle();

      // When cached data is available, do not break the session count UI
      expect(find.text('Error'), findsNothing);
      expect(find.byKey(const Key('timetable_session_count_badge')), findsOneWidget);
      expect(find.text('1 Session'), findsOneWidget);
      expect(find.text('Foundations of Data Science'), findsOneWidget);
    });

    testWidgets('Break and Lunch intervals are excluded from teaching session count', (tester) async {
      final scheduleWithBreaks = [
        FacultyScheduleItem(
          id: 701,
          dayOfWeek: 'MONDAY',
          periodId: 1,
          periodNumber: 1,
          periodName: 'Period 1',
          startTime: '09:10',
          endTime: '10:00',
          assignmentId: 7,
          subjectCode: 'CS401',
          subjectName: 'Foundations of Data Science',
          className: 'Class 1',
          facultyName: 'Santhiya',
        ),
        FacultyScheduleItem(
          id: 702,
          dayOfWeek: 'MONDAY',
          periodId: 2,
          periodNumber: 2,
          periodName: 'TEA BREAK',
          startTime: '10:00',
          endTime: '10:15',
          assignmentId: 0,
          subjectCode: 'BREAK',
          subjectName: 'Morning Tea Break',
          className: 'Class 1',
          facultyName: 'Santhiya',
        ),
        FacultyScheduleItem(
          id: 703,
          dayOfWeek: 'MONDAY',
          periodId: 3,
          periodNumber: 3,
          periodName: 'LUNCH',
          startTime: '12:45',
          endTime: '13:30',
          assignmentId: 0,
          subjectCode: 'LUNCH',
          subjectName: 'Lunch Break',
          className: 'Class 1',
          facultyName: 'Santhiya',
        ),
      ];

      final mockFaculty = MockFacultyForSessionCount(schedule: scheduleWithBreaks);

      await tester.pumpWidget(buildTestApp(mockFaculty));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mon'));
      await tester.pumpAndSettle();

      // Only 1 teaching session should be counted, breaks are excluded!
      expect(find.byKey(const Key('timetable_session_count_badge')), findsOneWidget);
      expect(find.text('1 Session'), findsOneWidget);
    });

    testWidgets('Duplicate period entries from table joins are deduplicated by periodNumber', (tester) async {
      final duplicateJoinSchedule = [
        FacultyScheduleItem(
          id: 701,
          dayOfWeek: 'MONDAY',
          periodId: 1,
          periodNumber: 1,
          periodName: 'Period 1',
          startTime: '09:10',
          endTime: '10:00',
          assignmentId: 7,
          subjectCode: 'CS401',
          subjectName: 'Foundations of Data Science',
          className: 'Class 1',
          facultyName: 'Santhiya',
        ),
        // Duplicate row for same period 1 from a secondary join
        FacultyScheduleItem(
          id: 702,
          dayOfWeek: 'MONDAY',
          periodId: 1,
          periodNumber: 1,
          periodName: 'Period 1',
          startTime: '09:10',
          endTime: '10:00',
          assignmentId: 7,
          subjectCode: 'CS401',
          subjectName: 'Foundations of Data Science',
          className: 'Class 1',
          facultyName: 'Santhiya (Assisting)',
        ),
      ];

      final mockFaculty = MockFacultyForSessionCount(schedule: duplicateJoinSchedule);

      await tester.pumpWidget(buildTestApp(mockFaculty));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mon'));
      await tester.pumpAndSettle();

      // Deduplication guarantees 1 Session
      expect(find.byKey(const Key('timetable_session_count_badge')), findsOneWidget);
      expect(find.text('1 Session'), findsOneWidget);
    });

    testWidgets('Loading state with empty schedule displays loading badge indicator', (tester) async {
      final mockFaculty = MockFacultyForSessionCount(
        schedule: [],
        isScheduleLoading: true,
      );

      await tester.pumpWidget(buildTestApp(mockFaculty));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Timetable'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('timetable_session_count_badge_loading')), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
    });
  });
}
