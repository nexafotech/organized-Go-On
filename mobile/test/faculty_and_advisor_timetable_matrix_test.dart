import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/models/user_model.dart';
import 'package:attendance_marker_mobile/models/faculty_model.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/services/auth_service.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_dashboard_screen.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_class_advisor_screen.dart';
import 'package:attendance_marker_mobile/widgets/widgets.dart';

class MockAuthServiceForMatrix extends ChangeNotifier implements AuthService {
  final UserModel _user = UserModel(
    id: 7,
    username: 'fac05',
    fullName: 'Santhiya',
    email: 'santhiya@go-on.edu',
    role: 'FACULTY',
    isActive: true,
    department: 'CSE Cyber Security',
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

class MockFacultyServiceForMatrix extends ChangeNotifier implements FacultyService {
  final List<FacultyScheduleItem> _schedule;
  final List<FacultyScheduleItem> _classAdvisorSchedule;
  final String? _classAdvisorClassName;
  final bool _isClassAdvisor;
  final AdvisedClassInfo? _advisedClass;
  final ClassAdvisorAvailablePeriodsResponse? _advisorAvailable;
  final ClassAdvisorPeriodsForDateResponse? _advisorPast;

  MockFacultyServiceForMatrix({
    List<FacultyScheduleItem>? schedule,
    List<FacultyScheduleItem>? classAdvisorSchedule,
    String? classAdvisorClassName,
    bool isClassAdvisor = true,
    AdvisedClassInfo? advisedClass,
    ClassAdvisorAvailablePeriodsResponse? advisorAvailable,
    ClassAdvisorPeriodsForDateResponse? advisorPast,
  })  : _schedule = schedule ?? [],
        _classAdvisorSchedule = classAdvisorSchedule ?? [],
        _classAdvisorClassName = classAdvisorClassName,
        _isClassAdvisor = isClassAdvisor,
        _advisedClass = advisedClass,
        _advisorAvailable = advisorAvailable,
        _advisorPast = advisorPast;

  @override
  List<FacultyScheduleItem> get schedule => _schedule;
  @override
  List<FacultyScheduleItem> get classAdvisorSchedule => _classAdvisorSchedule;
  @override
  String? get classAdvisorClassName => _classAdvisorClassName;
  @override
  bool get isClassAdvisor => _isClassAdvisor;
  @override
  AdvisedClassInfo? get advisedClass => _advisedClass;
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  ActiveClassSlot? get activeSlot => null;
  @override
  bool get hasActiveSlot => false;
  @override
  int? get activeSessionId => null;
  @override
  String? get activeSessionStatus => null;
  @override
  List<RosterStudentModel> get roster => [];

  @override
  Future<void> loadDashboardData() async {}
  @override
  Future<void> fetchSchedule() async {}
  @override
  Future<void> fetchClassAdvisorTimetable() async {}
  @override
  Future<ClassAdvisorAvailablePeriodsResponse> fetchClassAdvisorAvailablePeriods() async {
    return _advisorAvailable ??
        ClassAdvisorAvailablePeriodsResponse(
          isClassAdvisor: _isClassAdvisor,
          advisedClass: _advisedClass,
          todayDate: '2026-10-19',
          todayDay: 'MONDAY',
          yesterdayDate: '2026-10-18',
          yesterdayDay: 'SUNDAY',
          currentTime: '10:00 AM',
          todayPeriods: [],
          yesterdayPeriods: [],
          lunchBreak: LunchBreakInfo(),
        );
  }
  @override
  Future<ClassAdvisorPeriodsForDateResponse> fetchClassAdvisorPeriodsForDate(String date) async {
    return _advisorPast ??
        ClassAdvisorPeriodsForDateResponse(
          isClassAdvisor: _isClassAdvisor,
          advisedClass: _advisedClass,
          date: date,
          dayOfWeek: 'MONDAY',
          isToday: false,
          periods: [],
          lunchBreak: LunchBreakInfo(),
        );
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final sampleClassSchedule = [
    FacultyScheduleItem(
      id: 201,
      dayOfWeek: 'MONDAY',
      periodId: 1,
      periodNumber: 1,
      periodName: 'Period 1',
      startTime: '08:45 AM',
      endTime: '09:40 AM',
      assignmentId: 10,
      subjectCode: 'FDS',
      subjectName: 'Fundamentals of Data Science',
      className: 'II Year CSE Cyber Security - Class 1',
      facultyName: 'Dr. Alan Turing',
      roomNo: 'LH-101',
      type: 'Theory',
    ),
    FacultyScheduleItem(
      id: 202,
      dayOfWeek: 'MONDAY',
      periodId: 2,
      periodNumber: 2,
      periodName: 'Period 2',
      startTime: '09:40 AM',
      endTime: '10:35 AM',
      assignmentId: 11,
      subjectCode: 'DMC',
      subjectName: 'Discrete Mathematics and Combinatorics',
      className: 'II Year CSE Cyber Security - Class 1',
      facultyName: 'Prof. Gauss',
      roomNo: 'LH-101',
      type: 'Theory',
    ),
    FacultyScheduleItem(
      id: 203,
      dayOfWeek: 'FRIDAY',
      periodId: 3,
      periodNumber: 3,
      periodName: 'Period 3',
      startTime: '10:55 AM',
      endTime: '11:50 AM',
      assignmentId: 12,
      subjectCode: 'CS204-LAB',
      subjectName: 'Java Programming Laboratory',
      className: 'II Year CSE Cyber Security - Class 1',
      facultyName: 'Santhiya',
      roomNo: 'Lab 3',
      type: 'Lab',
    ),
    FacultyScheduleItem(
      id: 204,
      dayOfWeek: 'FRIDAY',
      periodId: 4,
      periodNumber: 4,
      periodName: 'Period 4',
      startTime: '11:50 AM',
      endTime: '12:45 PM',
      assignmentId: 12,
      subjectCode: 'CS204-LAB',
      subjectName: 'Java Programming Laboratory',
      className: 'II Year CSE Cyber Security - Class 1',
      facultyName: 'Santhiya',
      roomNo: 'Lab 3',
      type: 'Lab',
    ),
  ];

  final sampleFacultySchedule = [
    FacultyScheduleItem(
      id: 101,
      dayOfWeek: 'MONDAY',
      periodId: 1,
      periodNumber: 1,
      periodName: 'Period 1',
      startTime: '08:45 AM',
      endTime: '09:40 AM',
      assignmentId: 1,
      subjectCode: 'DS',
      subjectName: 'Data Structures',
      className: 'II Year CSE - Section A',
      facultyName: 'Santhiya',
      roomNo: 'Room 201',
      type: 'Theory',
    ),
  ];

  final sampleAdvisedClass = AdvisedClassInfo(
    id: 4,
    name: 'II Year CSE Cyber Security - Class 1',
    gradeLevel: 'II',
    academicYear: '2026-2027',
  );

  group('WeeklyMatrixTimetableView Component Tests', () {
    testWidgets('Renders complete weekly matrix with all 7 days, time rail, break dividers, and pastel cards',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final items = sampleClassSchedule.map((i) => i.toTimetableItemModel()).toList();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: WeeklyMatrixTimetableView(
              items: items,
              title: 'Class Schedule',
              subtitle: 'II Year CSE Cyber Security - Class 1',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Verify Header
      expect(find.text('Class Schedule'), findsOneWidget);
      expect(find.text('II Year CSE Cyber Security - Class 1'), findsOneWidget);

      // 2. Verify 7 weekdays are present in header row
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);

      // 3. Verify Time Rail Periods
      expect(find.text('P1'), findsWidgets);
      expect(find.text('P2'), findsWidgets);
      expect(find.text('P3'), findsWidgets);
      expect(find.text('P4'), findsWidgets);
      expect(find.text('P5'), findsWidgets);
      expect(find.text('P6'), findsWidgets);
      expect(find.text('P7'), findsWidgets);

      // 4. Verify Break Dividers are NOT displayed
      expect(find.text('Tea break'), findsNothing);
      expect(find.text('Lunch'), findsNothing);

      // 5. Verify Subject Cards
      expect(find.text('FDS'), findsOneWidget);
      expect(find.text('DMC'), findsOneWidget);

      // 6. Verify tapping a card opens the simplified modal bottom sheet (Faculty & Time only)
      await tester.tap(find.text('FDS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Dr. Alan Turing'), findsOneWidget);
      expect(find.text('08:45 AM – 09:40 AM'), findsOneWidget);
      expect(find.text('Fundamentals of Data Science'), findsNothing);
      expect(find.text('LH-101'), findsNothing);
      expect(find.text('Close'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });
  });

  group('Faculty Dashboard Timetable Matrix & Class Advisor Scope Tests', () {
    testWidgets('Faculty Timetable tab allows toggling view mode and switching between faculty and advised class timetable',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 851);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockFaculty = MockFacultyServiceForMatrix(
        schedule: sampleFacultySchedule,
        classAdvisorSchedule: sampleClassSchedule,
        classAdvisorClassName: 'II Year CSE Cyber Security - Class 1',
        isClassAdvisor: true,
        advisedClass: sampleAdvisedClass,
      );

      final mockAuth = MockAuthServiceForMatrix();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const FacultyDashboardScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Navigate to Timetable tab in bottom navigation
      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      // 1. Initial view is Day Agenda mode with title 'Faculty Timetable'
      expect(find.text('Faculty Timetable'), findsOneWidget);
      expect(find.byKey(const Key('scope_my_schedule')), findsOneWidget);
      expect(find.byKey(const Key('scope_class_schedule')), findsOneWidget);

      // 2. Toggle to Weekly Matrix View via AppBar icon
      final viewModeBtn = find.byTooltip('Weekly Matrix View');
      expect(viewModeBtn, findsOneWidget);
      await tester.tap(viewModeBtn);
      await tester.pumpAndSettle();

      // Now WeeklyMatrixTimetableView is displayed
      expect(find.byType(WeeklyMatrixTimetableView), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tea break'), findsNothing);
      expect(find.text('Lunch'), findsNothing);

      // 3. Switch scope to Advised Class Schedule
      final classScopeBtn = find.byKey(const Key('scope_class_schedule'));
      await tester.tap(classScopeBtn);
      await tester.pumpAndSettle();

      // Class subjects are now displayed in matrix
      expect(find.text('FDS'), findsOneWidget);
      expect(find.text('DMC'), findsOneWidget);
      expect(find.text('Class Schedule'), findsOneWidget);
    });
  });

  group('Faculty Class Advisor Portal Timetable Tab Tests', () {
    testWidgets('Class Advisor Screen contains CLASS SCHEDULE tab rendering the weekly matrix view',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockFaculty = MockFacultyServiceForMatrix(
        schedule: sampleFacultySchedule,
        classAdvisorSchedule: sampleClassSchedule,
        classAdvisorClassName: 'II Year CSE Cyber Security - Class 1',
        isClassAdvisor: true,
        advisedClass: sampleAdvisedClass,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const FacultyClassAdvisorScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Verify 4 tabs exist: TODAY, YESTERDAY, PAST DATES, CLASS SCHEDULE
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('YESTERDAY'), findsOneWidget);
      expect(find.text('PAST DATES'), findsOneWidget);
      expect(find.byKey(const Key('tab_class_schedule')), findsOneWidget);

      // 2. Tap CLASS SCHEDULE tab
      final scheduleTab = find.byKey(const Key('tab_class_schedule'));
      await tester.ensureVisible(scheduleTab);
      await tester.tap(scheduleTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 3. Verify WeeklyMatrixTimetableView renders with advised class schedule
      expect(find.byType(WeeklyMatrixTimetableView), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('Tea break'), findsNothing);
      expect(find.text('Lunch'), findsNothing);
      expect(find.text('FDS'), findsOneWidget);
      expect(find.text('DMC'), findsOneWidget);

      // 4. Verify zero RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('Samsung Galaxy S24 (393 x 851 dp) in Dark Theme renders cleanly without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 851);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockFaculty = MockFacultyServiceForMatrix(
        schedule: sampleFacultySchedule,
        classAdvisorSchedule: sampleClassSchedule,
        classAdvisorClassName: 'II Year CSE Cyber Security - Class 1',
        isClassAdvisor: true,
        advisedClass: sampleAdvisedClass,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const FacultyClassAdvisorScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final scheduleTab = find.byKey(const Key('tab_class_schedule'));
      await tester.ensureVisible(scheduleTab);
      await tester.tap(scheduleTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(WeeklyMatrixTimetableView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
