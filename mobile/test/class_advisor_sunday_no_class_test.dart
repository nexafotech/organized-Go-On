import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_class_advisor_screen.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';

class MockFacultyServiceForSunday extends FacultyService {
  final Future<ClassAdvisorAvailablePeriodsResponse> Function()? onFetchAvailable;
  final Future<ClassAdvisorPeriodsForDateResponse> Function(String date)? onFetchPast;

  MockFacultyServiceForSunday({
    this.onFetchAvailable,
    this.onFetchPast,
  });

  @override
  Future<ClassAdvisorAvailablePeriodsResponse> fetchClassAdvisorAvailablePeriods() async {
    if (onFetchAvailable != null) {
      return onFetchAvailable!();
    }
    throw Exception('Failed to load class advisor periods');
  }

  @override
  Future<ClassAdvisorPeriodsForDateResponse> fetchClassAdvisorPeriodsForDate(String date) async {
    if (onFetchPast != null) {
      return onFetchPast!(date);
    }
    throw Exception('Failed to load past periods');
  }
}

List<ClassAdvisorPeriodItem> _samplePeriods(String date, String dayOfWeek) {
  return [
    ClassAdvisorPeriodItem(
      timetableEntryId: 101,
      periodId: 1,
      periodNumber: 1,
      periodName: 'Period 1',
      startTime: '09:10',
      endTime: '10:00',
      sessionType: 'MORNING',
      subjectCode: 'CF',
      subjectName: 'Cyber Forensics',
      classId: 1,
      className: 'II Year CSE Cyber Security - Class 1',
      date: date,
      dayOfWeek: dayOfWeek,
      subjectFacultyName: 'Santhiya',
      status: 'AVAILABLE',
      canMark: true,
    ),
    ClassAdvisorPeriodItem(
      timetableEntryId: 105,
      periodId: 5,
      periodNumber: 5,
      periodName: 'Period 5',
      startTime: '13:40',
      endTime: '14:30',
      sessionType: 'AFTERNOON',
      subjectCode: 'CC',
      subjectName: 'Cloud Computing',
      classId: 1,
      className: 'II Year CSE Cyber Security - Class 1',
      date: date,
      dayOfWeek: dayOfWeek,
      subjectFacultyName: 'Venkatesh',
      status: 'AVAILABLE',
      canMark: true,
    ),
  ];
}

Widget createTestApp(FacultyService service, {ThemeData? theme}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<FacultyService>.value(value: service),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      home: const FacultyClassAdvisorScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Class Adviser Sunday & No-Class Display Tests', () {
    testWidgets('1. Today is Sunday and no periods scheduled: displays "No Classes Today"',
        (WidgetTester tester) async {
      final mockService = MockFacultyServiceForSunday(
        onFetchAvailable: () async => ClassAdvisorAvailablePeriodsResponse(
          isClassAdvisor: true,
          advisedClass: AdvisedClassInfo(id: 1, name: 'II Year CSE Cyber Security - Class 1'),
          todayDate: '2026-10-18',
          todayDay: 'Sunday',
          yesterdayDate: '2026-10-17',
          yesterdayDay: 'Saturday',
          currentTime: '10:00',
          todayPeriods: [], // Unscheduled Sunday
          yesterdayPeriods: _samplePeriods('2026-10-17', 'Saturday'),
          lunchBreak: LunchBreakInfo(),
        ),
      );

      await tester.pumpWidget(createTestApp(mockService));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verifies centered Sunday message
      expect(find.text('No Classes Today'), findsOneWidget);
      expect(find.text('There are no scheduled classes on Sunday. Enjoy your day off!'), findsOneWidget);

      // Verifies unwanted sections are hidden
      expect(find.text('MORNING SESSION (P1 – P4)'), findsNothing);
      expect(find.text('AFTERNOON SESSION (P5 – P7)'), findsNothing);
      expect(find.text('No morning timetable periods scheduled.'), findsNothing);
      expect(find.text('No afternoon timetable periods scheduled.'), findsNothing);
      expect(find.text('Authoritative College Day Ends at 4:10 PM'), findsNothing);
      expect(find.text('View Daily Half-Day Summary for this date'), findsNothing);
    });

    testWidgets('2. Yesterday was Sunday and no periods scheduled: displays "No Classes Yesterday" (Reference Bug)',
        (WidgetTester tester) async {
      final mockService = MockFacultyServiceForSunday(
        onFetchAvailable: () async => ClassAdvisorAvailablePeriodsResponse(
          isClassAdvisor: true,
          advisedClass: AdvisedClassInfo(id: 1, name: 'II Year CSE Cyber Security - Class 1'),
          todayDate: '2026-10-19',
          todayDay: 'Monday',
          yesterdayDate: '2026-10-18',
          yesterdayDay: 'Sunday',
          currentTime: '10:00',
          todayPeriods: _samplePeriods('2026-10-19', 'Monday'),
          yesterdayPeriods: [], // Unscheduled Sunday Yesterday
          lunchBreak: LunchBreakInfo(),
        ),
      );

      await tester.pumpWidget(createTestApp(mockService));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Switch to YESTERDAY tab
      await tester.tap(find.text('YESTERDAY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verifies centered message for Yesterday
      expect(find.text('No Classes Yesterday'), findsOneWidget);
      expect(find.text('There are no scheduled classes on Sunday. Enjoy your day off!'), findsOneWidget);

      // Verifies confusing sections from the user screenshot are completely hidden
      expect(find.text('MORNING SESSION (P1 – P4)'), findsNothing);
      expect(find.text('AFTERNOON SESSION (P5 – P7)'), findsNothing);
      expect(find.text('No morning timetable periods scheduled.'), findsNothing);
      expect(find.text('No afternoon timetable periods scheduled.'), findsNothing);
      expect(find.text('Authoritative College Day Ends at 4:10 PM'), findsNothing);
      expect(find.text('View Daily Half-Day Summary for this date'), findsNothing);
    });

    testWidgets('3. Past Dates tab with previous Sunday selected: displays "No Classes on Sunday"',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockService = MockFacultyServiceForSunday(
        onFetchAvailable: () async => ClassAdvisorAvailablePeriodsResponse(
          isClassAdvisor: true,
          advisedClass: AdvisedClassInfo(id: 1, name: 'II Year CSE Cyber Security - Class 1'),
          todayDate: '2026-10-20',
          todayDay: 'Tuesday',
          yesterdayDate: '2026-10-19',
          yesterdayDay: 'Monday',
          currentTime: '10:00',
          todayPeriods: _samplePeriods('2026-10-20', 'Tuesday'),
          yesterdayPeriods: _samplePeriods('2026-10-19', 'Monday'),
          lunchBreak: LunchBreakInfo(),
        ),
        onFetchPast: (date) async => ClassAdvisorPeriodsForDateResponse(
          isClassAdvisor: true,
          advisedClass: AdvisedClassInfo(id: 1, name: 'II Year CSE Cyber Security - Class 1'),
          date: date,
          dayOfWeek: 'Sunday',
          isToday: false,
          periods: [], // Empty Sunday in past
          lunchBreak: LunchBreakInfo(),
        ),
      );

      await tester.pumpWidget(createTestApp(mockService));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Switch to PAST DATES tab
      await tester.tap(find.text('PAST DATES'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verifies centered message for Previous Sunday
      expect(find.text('No Classes on Sunday'), findsOneWidget);
      expect(find.text('There are no scheduled classes on Sunday. Enjoy your day off!'), findsOneWidget);

      // Verifies summary button is hidden when no attendance records
      expect(find.text('View Daily Half-Day Summary for this date'), findsNothing);
    });

    testWidgets('4. Weekday with scheduled periods displays periods and session headers normally',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockService = MockFacultyServiceForSunday(
        onFetchAvailable: () async => ClassAdvisorAvailablePeriodsResponse(
          isClassAdvisor: true,
          advisedClass: AdvisedClassInfo(id: 1, name: 'II Year CSE Cyber Security - Class 1'),
          todayDate: '2026-10-19',
          todayDay: 'Monday',
          yesterdayDate: '2026-10-18',
          yesterdayDay: 'Sunday',
          currentTime: '10:00',
          todayPeriods: _samplePeriods('2026-10-19', 'Monday'),
          yesterdayPeriods: [],
          lunchBreak: LunchBreakInfo(),
        ),
      );

      await tester.pumpWidget(createTestApp(mockService));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verifies weekday schedule is rendered normally
      expect(find.text('MORNING SESSION (P1 – P4)'), findsOneWidget);
      expect(find.text('AFTERNOON SESSION (P5 – P7)'), findsOneWidget);
      expect(find.textContaining('Cyber Forensics'), findsOneWidget);
      expect(find.textContaining('Cloud Computing'), findsOneWidget);
      expect(find.text('Authoritative College Day Ends at 4:10 PM'), findsOneWidget);
      expect(find.text('View Daily Half-Day Summary for this date'), findsOneWidget);
    });

    testWidgets('5. Weekday without scheduled periods displays "No classes scheduled for this date"',
        (WidgetTester tester) async {
      final mockService = MockFacultyServiceForSunday(
        onFetchAvailable: () async => ClassAdvisorAvailablePeriodsResponse(
          isClassAdvisor: true,
          advisedClass: AdvisedClassInfo(id: 1, name: 'II Year CSE Cyber Security - Class 1'),
          todayDate: '2026-10-21',
          todayDay: 'Wednesday',
          yesterdayDate: '2026-10-20',
          yesterdayDay: 'Tuesday',
          currentTime: '10:00',
          todayPeriods: [], // Unscheduled Wednesday
          yesterdayPeriods: _samplePeriods('2026-10-20', 'Tuesday'),
          lunchBreak: LunchBreakInfo(),
        ),
      );

      await tester.pumpWidget(createTestApp(mockService));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('No classes scheduled for this date'), findsOneWidget);
      expect(find.text('There are no scheduled teaching periods for Wednesday (2026-10-21).'), findsOneWidget);
      expect(find.text('MORNING SESSION (P1 – P4)'), findsNothing);
      expect(find.text('AFTERNOON SESSION (P5 – P7)'), findsNothing);
    });

    testWidgets('6. Sunday with explicitly configured classes displays periods and attendance actions normally',
        (WidgetTester tester) async {
      final mockService = MockFacultyServiceForSunday(
        onFetchAvailable: () async => ClassAdvisorAvailablePeriodsResponse(
          isClassAdvisor: true,
          advisedClass: AdvisedClassInfo(id: 1, name: 'II Year CSE Cyber Security - Class 1'),
          todayDate: '2026-10-18',
          todayDay: 'Sunday',
          yesterdayDate: '2026-10-17',
          yesterdayDay: 'Saturday',
          currentTime: '10:00',
          todayPeriods: _samplePeriods('2026-10-18', 'Sunday'), // Scheduled classes on Sunday
          yesterdayPeriods: _samplePeriods('2026-10-17', 'Saturday'),
          lunchBreak: LunchBreakInfo(),
        ),
      );

      await tester.pumpWidget(createTestApp(mockService));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Classes on Sunday must be rendered normally!
      expect(find.text('MORNING SESSION (P1 – P4)'), findsOneWidget);
      expect(find.text('AFTERNOON SESSION (P5 – P7)'), findsOneWidget);
      expect(find.textContaining('Cyber Forensics'), findsOneWidget);
      expect(find.text('RECORD ATTENDANCE'), findsNWidgets(2));
      expect(find.text('No Classes Today'), findsNothing);
    });

    testWidgets('7. Timetable / API loading failure displays error state, not holiday',
        (WidgetTester tester) async {
      final mockService = MockFacultyServiceForSunday(
        onFetchAvailable: () async {
          throw Exception('Connection timed out to attendance server');
        },
      );

      await tester.pumpWidget(createTestApp(mockService));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Must show error state and retry button, not declare holiday
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('No Classes Today'), findsNothing);
    });

    testWidgets('8. Sunday empty state renders readable contrast in dark theme',
        (WidgetTester tester) async {
      final mockService = MockFacultyServiceForSunday(
        onFetchAvailable: () async => ClassAdvisorAvailablePeriodsResponse(
          isClassAdvisor: true,
          advisedClass: AdvisedClassInfo(id: 1, name: 'II Year CSE Cyber Security - Class 1'),
          todayDate: '2026-10-18',
          todayDay: 'Sunday',
          yesterdayDate: '2026-10-17',
          yesterdayDay: 'Saturday',
          currentTime: '10:00',
          todayPeriods: [],
          yesterdayPeriods: [],
          lunchBreak: LunchBreakInfo(),
        ),
      );

      await tester.pumpWidget(createTestApp(mockService, theme: AppTheme.darkTheme));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('No Classes Today'), findsOneWidget);
      expect(find.text('There are no scheduled classes on Sunday. Enjoy your day off!'), findsOneWidget);
    });
  });
}
