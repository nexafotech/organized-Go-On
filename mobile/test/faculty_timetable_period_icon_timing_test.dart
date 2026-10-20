import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/models/user_model.dart';
import 'package:attendance_marker_mobile/models/faculty_model.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/services/auth_service.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_dashboard_screen.dart';
import 'package:attendance_marker_mobile/utils/timezone_utils.dart';

class MockAuthForIconTest extends ChangeNotifier implements AuthService {
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

class MockFacultyForIconTest extends ChangeNotifier implements FacultyService {
  final List<FacultyScheduleItem> _schedule;

  MockFacultyForIconTest({
    List<FacultyScheduleItem>? schedule,
  }) : _schedule = schedule ?? [];

  @override
  List<FacultyScheduleItem> get schedule => _schedule;
  @override
  List<FacultyScheduleItem> get classAdvisorSchedule => [];
  @override
  String? get classAdvisorClassName => null;
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  bool get isScheduleLoading => false;
  @override
  String? get scheduleErrorMessage => null;
  @override
  bool get isClassAdvisorScheduleLoading => false;
  @override
  String? get classAdvisorScheduleErrorMessage => null;
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
  Future<void> loadDashboardData() async {}
  @override
  Future<void> fetchSchedule() async {}
  @override
  Future<void> fetchClassAdvisorTimetable() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('TimezoneUtils.isPeriodCompleted Unit Tests (Boundary & Logic Verification)', () {
    final today = DateTime(2026, 10, 20); // Tuesday, Oct 20, 2026
    final yesterday = DateTime(2026, 10, 19); // Monday, Oct 19, 2026
    final tomorrow = DateTime(2026, 10, 21); // Wednesday, Oct 21, 2026

    test('1. Before period starts on today -> returns false', () {
      final now = DateTime(2026, 10, 20, 12, 6, 0); // 12:06 PM
      final result = TimezoneUtils.isPeriodCompleted(
        targetDate: today,
        endTimeStr: '14:30', // 2:30 PM
        now: now,
      );
      expect(result, isFalse);
    });

    test('2. During period in progress on today -> returns false', () {
      final now = DateTime(2026, 10, 20, 14, 15, 0); // 2:15 PM (in progress: 1:40 - 2:30)
      final result = TimezoneUtils.isPeriodCompleted(
        targetDate: today,
        endTimeStr: '14:30',
        now: now,
      );
      expect(result, isFalse);
    });

    test('3. Exactly at period end time on today -> returns false (tick only after end time passed)', () {
      final now = DateTime(2026, 10, 20, 14, 30, 0); // Exactly 2:30:00 PM
      final result = TimezoneUtils.isPeriodCompleted(
        targetDate: today,
        endTimeStr: '14:30',
        now: now,
      );
      expect(result, isFalse);
    });

    test('4. Immediately after period end time (1 second after) -> returns true', () {
      final now = DateTime(2026, 10, 20, 14, 30, 1); // 2:30:01 PM
      final result = TimezoneUtils.isPeriodCompleted(
        targetDate: today,
        endTimeStr: '14:30',
        now: now,
      );
      expect(result, isTrue);
    });

    test('5. Past period earlier today (Period 1 finished at 10:00 AM) -> returns true', () {
      final now = DateTime(2026, 10, 20, 12, 6, 0); // 12:06 PM
      final result = TimezoneUtils.isPeriodCompleted(
        targetDate: today,
        endTimeStr: '10:00',
        now: now,
      );
      expect(result, isTrue);
    });

    test('6. Historical period on a past date (yesterday) -> returns true', () {
      final now = DateTime(2026, 10, 20, 12, 6, 0);
      final result = TimezoneUtils.isPeriodCompleted(
        targetDate: yesterday,
        endTimeStr: '14:30',
        now: now,
      );
      expect(result, isTrue);
    });

    test('7. Future period on a future date (tomorrow) -> returns false', () {
      final now = DateTime(2026, 10, 20, 12, 6, 0);
      final result = TimezoneUtils.isPeriodCompleted(
        targetDate: tomorrow,
        endTimeStr: '14:30',
        now: now,
      );
      expect(result, isFalse);
    });

    test('8. Missing, empty, or null end time -> returns false safely', () {
      final now = DateTime(2026, 10, 20, 12, 6, 0);
      expect(TimezoneUtils.isPeriodCompleted(targetDate: today, endTimeStr: null, now: now), isFalse);
      expect(TimezoneUtils.isPeriodCompleted(targetDate: today, endTimeStr: '', now: now), isFalse);
      expect(TimezoneUtils.isPeriodCompleted(targetDate: today, endTimeStr: '   ', now: now), isFalse);
    });

    test('9. Malformed end time strings -> returns false safely', () {
      final now = DateTime(2026, 10, 20, 12, 6, 0);
      expect(TimezoneUtils.isPeriodCompleted(targetDate: today, endTimeStr: 'invalid', now: now), isFalse);
      expect(TimezoneUtils.isPeriodCompleted(targetDate: today, endTimeStr: '25:00', now: now), isFalse);
      expect(TimezoneUtils.isPeriodCompleted(targetDate: today, endTimeStr: '14:75', now: now), isFalse);
    });
  });

  group('Faculty Timetable Period Icon Widget Tests (Controlled Clock Scenarios)', () {
    // Tuesday schedule matching user's reference screenshot:
    // 1. Period 1: 09:10 - 10:00 (Foundations of Data Science)
    // 2. Period 5: 13:40 - 14:30 (Object Oriented Programming Systems)
    // 3. Period 6: 14:30 - 15:20 (Linux Programming)
    final tuesdaySchedule = [
      FacultyScheduleItem(
        id: 701,
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
        id: 705,
        dayOfWeek: 'TUESDAY',
        periodId: 5,
        periodNumber: 5,
        periodName: 'Period 5',
        startTime: '13:40',
        endTime: '14:30',
        assignmentId: 8,
        subjectCode: 'OOPS',
        subjectName: 'Object Oriented Programming Systems',
        className: 'II Year CSE Cyber Security - Class 1',
        facultyName: 'Santhiya',
      ),
      FacultyScheduleItem(
        id: 706,
        dayOfWeek: 'TUESDAY',
        periodId: 6,
        periodNumber: 6,
        periodName: 'Period 6',
        startTime: '14:30',
        endTime: '15:20',
        assignmentId: 9,
        subjectCode: 'LP',
        subjectName: 'Linux Programming',
        className: 'II Year CSE Cyber Security - Class 2',
        facultyName: 'Santhiya',
      ),
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
        facultyName: 'Santhiya',
      ),
      FacultyScheduleItem(
        id: 703,
        dayOfWeek: 'WEDNESDAY',
        periodId: 2,
        periodNumber: 2,
        periodName: 'Period 2',
        startTime: '10:00',
        endTime: '10:50',
        assignmentId: 8,
        subjectCode: 'CS402',
        subjectName: 'Computer Networks',
        className: 'Class 1',
        facultyName: 'Santhiya',
      ),
    ];

    Widget buildTestApp({
      required MockFacultyForIconTest mockFaculty,
      DateTime? simulatedTime,
    }) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
          ChangeNotifierProvider<AuthService>.value(value: MockAuthForIconTest()),
        ],
        child: MaterialApp(
          home: FacultyDashboardScreen(simulatedTime: simulatedTime),
        ),
      );
    }

    testWidgets('10. Reference Screenshot Reproduction (Tuesday 12:06 PM): Period 5 & 6 display plain human icon, Period 1 displays tick', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Simulated clock at 12:06 PM on Tuesday, Oct 20, 2026 (exact time from reference screenshot status bar)
      final simulatedTime = DateTime(2026, 10, 20, 12, 6, 0);
      final mockFaculty = MockFacultyForIconTest(schedule: tuesdaySchedule);

      await tester.pumpWidget(buildTestApp(mockFaculty: mockFaculty, simulatedTime: simulatedTime));
      await tester.pumpAndSettle();

      // Navigate to Timetable tab
      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      // Ensure Tuesday is selected
      await tester.tap(find.text('Tue'));
      await tester.pumpAndSettle();

      // 1. Period 1 ended at 10:00 AM -> MUST show human-with-tick icon (Icons.how_to_reg_rounded)
      final p1Finder = find.byKey(const Key('period_action_icon_701'));
      expect(p1Finder, findsOneWidget);
      final p1Icon = tester.widget<Icon>(p1Finder);
      expect(p1Icon.icon, equals(Icons.how_to_reg_rounded));

      // 2. Period 5 ends at 2:30 PM (now is 12:06 PM) -> MUST show plain human icon (Icons.person_rounded)
      final p5Finder = find.byKey(const Key('period_action_icon_705'));
      expect(p5Finder, findsOneWidget);
      final p5Icon = tester.widget<Icon>(p5Finder);
      expect(p5Icon.icon, equals(Icons.person_rounded));

      // 3. Period 6 ends at 3:20 PM (now is 12:06 PM) -> MUST show plain human icon (Icons.person_rounded)
      final p6Finder = find.byKey(const Key('period_action_icon_706'));
      expect(p6Finder, findsOneWidget);
      final p6Icon = tester.widget<Icon>(p6Finder);
      expect(p6Icon.icon, equals(Icons.person_rounded));
    });

    testWidgets('11. During period in progress (Tuesday 2:15 PM): Period 5 shows plain human icon', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Period 5 runs 1:40 PM to 2:30 PM. Current time is 2:15 PM (in progress).
      final simulatedTime = DateTime(2026, 10, 20, 14, 15, 0);
      final mockFaculty = MockFacultyForIconTest(schedule: tuesdaySchedule);

      await tester.pumpWidget(buildTestApp(mockFaculty: mockFaculty, simulatedTime: simulatedTime));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tue'));
      await tester.pumpAndSettle();

      final p5Icon = tester.widget<Icon>(find.byKey(const Key('period_action_icon_705')));
      expect(p5Icon.icon, equals(Icons.person_rounded));
    });

    testWidgets('12. Boundary: Exactly at 2:30:00 PM -> Period 5 shows plain human icon', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Period 5 ends at 2:30 PM. Exactly at 2:30:00 PM, period end has not yet elapsed.
      final simulatedTime = DateTime(2026, 10, 20, 14, 30, 0);
      final mockFaculty = MockFacultyForIconTest(schedule: tuesdaySchedule);

      await tester.pumpWidget(buildTestApp(mockFaculty: mockFaculty, simulatedTime: simulatedTime));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tue'));
      await tester.pumpAndSettle();

      final p5Icon = tester.widget<Icon>(find.byKey(const Key('period_action_icon_705')));
      expect(p5Icon.icon, equals(Icons.person_rounded));
    });

    testWidgets('13. Immediately after end time (2:30:01 PM) -> Period 5 transitions to human-with-tick icon', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1 second after 2:30 PM. Scheduled end time has elapsed.
      final simulatedTime = DateTime(2026, 10, 20, 14, 30, 1);
      final mockFaculty = MockFacultyForIconTest(schedule: tuesdaySchedule);

      await tester.pumpWidget(buildTestApp(mockFaculty: mockFaculty, simulatedTime: simulatedTime));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tue'));
      await tester.pumpAndSettle();

      // Period 5 has finished -> MUST show human-with-tick
      final p5Icon = tester.widget<Icon>(find.byKey(const Key('period_action_icon_705')));
      expect(p5Icon.icon, equals(Icons.how_to_reg_rounded));

      // Period 6 (2:30 PM - 3:20 PM) is now in progress -> MUST show plain human icon
      final p6Icon = tester.widget<Icon>(find.byKey(const Key('period_action_icon_706')));
      expect(p6Icon.icon, equals(Icons.person_rounded));
    });

    testWidgets('14. Switching to Monday (past date) shows human-with-tick icon for all historical periods', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final simulatedTime = DateTime(2026, 10, 20, 12, 6, 0); // Tuesday
      final mockFaculty = MockFacultyForIconTest(schedule: tuesdaySchedule);

      await tester.pumpWidget(buildTestApp(mockFaculty: mockFaculty, simulatedTime: simulatedTime));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      // Tap Monday (yesterday)
      await tester.tap(find.text('Mon'));
      await tester.pumpAndSettle();

      final p1Icon = tester.widget<Icon>(find.byKey(const Key('period_action_icon_702')));
      expect(p1Icon.icon, equals(Icons.how_to_reg_rounded));
    });

    testWidgets('15. Switching to Wednesday (future date) shows plain human icon for all upcoming periods', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final simulatedTime = DateTime(2026, 10, 20, 12, 6, 0); // Tuesday
      final mockFaculty = MockFacultyForIconTest(schedule: tuesdaySchedule);

      await tester.pumpWidget(buildTestApp(mockFaculty: mockFaculty, simulatedTime: simulatedTime));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      // Tap Wednesday (tomorrow)
      await tester.tap(find.text('Wed'));
      await tester.pumpAndSettle();

      final p2Icon = tester.widget<Icon>(find.byKey(const Key('period_action_icon_703')));
      expect(p2Icon.icon, equals(Icons.person_rounded));
    });

    testWidgets('16. Invalid or missing endTime safely renders plain human icon without crash or tick', (tester) async {
      final invalidSchedule = [
        FacultyScheduleItem(
          id: 999,
          dayOfWeek: 'TUESDAY',
          periodId: 1,
          periodNumber: 1,
          periodName: 'Corrupted Period',
          startTime: 'invalid',
          endTime: 'invalid',
          assignmentId: 99,
          subjectCode: 'BAD',
          subjectName: 'Corrupted Timetable Entry',
          className: 'Class 1',
        ),
      ];

      final simulatedTime = DateTime(2026, 10, 20, 12, 6, 0);
      final mockFaculty = MockFacultyForIconTest(schedule: invalidSchedule);

      await tester.pumpWidget(buildTestApp(mockFaculty: mockFaculty, simulatedTime: simulatedTime));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tue'));
      await tester.pumpAndSettle();

      final badIcon = tester.widget<Icon>(find.byKey(const Key('period_action_icon_999')));
      expect(badIcon.icon, equals(Icons.person_rounded));
    });
  });
}
