import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/models/user_model.dart';
import 'package:attendance_marker_mobile/models/faculty_model.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/services/auth_service.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_dashboard_screen.dart';

class MockAuthForTimetable extends ChangeNotifier implements AuthService {
  final UserModel _user = UserModel(
    id: 10,
    username: 'fac_cs01',
    fullName: 'Dr. Alan Turing',
    email: 'turing@go-on.edu',
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

class MockFacultyForTimetable extends ChangeNotifier implements FacultyService {
  final List<FacultyScheduleItem> _schedule;
  final bool _isLoading;
  final String? _errorMessage;

  MockFacultyForTimetable({
    List<FacultyScheduleItem>? schedule,
    bool isLoading = false,
    String? errorMessage,
  })  : _schedule = schedule ?? [],
        _isLoading = isLoading,
        _errorMessage = errorMessage;

  @override
  List<FacultyScheduleItem> get schedule => _schedule;
  @override
  bool get isLoading => _isLoading;
  @override
  String? get errorMessage => _errorMessage;
  @override
  bool get isClassAdvisor => false;
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
  bool get isScheduleLoading => false;
  @override
  String? get scheduleErrorMessage => null;
  @override
  bool get isClassAdvisorScheduleLoading => false;
  @override
  String? get classAdvisorScheduleErrorMessage => null;
  @override
  List<FacultyScheduleItem> get classAdvisorSchedule => [];
  @override
  String? get classAdvisorClassName => null;

  @override
  Future<void> loadDashboardData() async {}
  @override
  Future<void> fetchSchedule() async {}
  @override
  Future<void> fetchClassAdvisorTimetable() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Faculty Timetable Redesign Tests (Reference Image 1 Alignment)', () {
    final testSchedule = [
      FacultyScheduleItem(
        id: 101,
        dayOfWeek: 'MONDAY',
        periodId: 1,
        periodNumber: 1,
        periodName: 'Period 1',
        startTime: '09:00',
        endTime: '09:50',
        assignmentId: 1,
        subjectCode: 'CS201',
        subjectName: 'Design and Analysis of Algorithms',
        className: 'II Year CSE - Section A',
        facultyName: 'Dr. Alan Turing',
      ),
      FacultyScheduleItem(
        id: 102,
        dayOfWeek: 'MONDAY',
        periodId: 2,
        periodNumber: 2,
        periodName: 'Period 2',
        startTime: '10:00',
        endTime: '10:50',
        assignmentId: 2,
        subjectCode: 'CS202',
        subjectName: 'Computer Architecture',
        className: 'II Year CSE - Section B',
      ),
      FacultyScheduleItem(
        id: 103,
        dayOfWeek: 'FRIDAY',
        periodId: 3,
        periodNumber: 3,
        periodName: 'Period 3',
        startTime: '11:10',
        endTime: '12:00',
        assignmentId: 3,
        subjectCode: 'CS301',
        subjectName: 'Artificial Intelligence & Neural Nets',
        className: 'III Year CSE - AI/ML',
      ),
    ];

    testWidgets('Renders complete 7-day capsule selector with dynamic day labels and numbers', (tester) async {
      final mockFaculty = MockFacultyForTimetable(schedule: testSchedule);
      final mockAuth = MockAuthForTimetable();

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

      // Navigate to Timetable tab
      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      // Check all 7 weekday labels exist
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
    });

    testWidgets('Selecting Monday renders session cards matching Reference Image 1', (tester) async {
      final mockFaculty = MockFacultyForTimetable(schedule: testSchedule);
      final mockAuth = MockAuthForTimetable();

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

      // Navigate to Timetable tab
      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      // Tap Mon in the 7-day strip
      await tester.tap(find.text('Mon'));
      await tester.pumpAndSettle();

      // Verify Header & Subheader elements
      expect(find.text('Faculty Timetable'), findsOneWidget);
      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('2 Sessions'), findsOneWidget);

      // Verify Session 1 card
      expect(find.text('Design and Analysis of Algorithms'), findsOneWidget);
      expect(find.text('Code: CS201 | Class: II Year CSE - Section A'), findsOneWidget);
      expect(find.text('Dr. Alan Turing'), findsOneWidget);

      // Verify Session 2 card
      expect(find.text('Computer Architecture'), findsOneWidget);
      expect(find.text('Code: CS202 | Class: II Year CSE - Section B'), findsOneWidget);
    });

    testWidgets('Selecting Sunday renders welcoming empty state with recharge message', (tester) async {
      final mockFaculty = MockFacultyForTimetable(schedule: testSchedule);
      final mockAuth = MockAuthForTimetable();

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

      // Navigate to Timetable tab
      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      // Tap Sun in the 7-day strip
      await tester.tap(find.text('Sun'));
      await tester.pumpAndSettle();

      expect(find.text('Weekend — No Classes Scheduled'), findsOneWidget);
      expect(find.text('Sunday has no scheduled classes. Relax and recharge.'), findsOneWidget);
      expect(find.text('0 Sessions'), findsOneWidget);
    });

    testWidgets('Tapping non-today session card opens detail bottom sheet', (tester) async {
      final mockFaculty = MockFacultyForTimetable(schedule: testSchedule);
      final mockAuth = MockAuthForTimetable();

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

      // Navigate to Timetable tab
      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      // Switch to Friday
      await tester.tap(find.text('Fri'));
      await tester.pumpAndSettle();

      expect(find.text('Artificial Intelligence & Neural Nets'), findsOneWidget);

      // Tap the card or circular action button
      await tester.tap(find.text('Artificial Intelligence & Neural Nets'));
      await tester.pumpAndSettle();

      // Modal bottom sheet should be visible
      expect(find.text('Close'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });
  });
}
