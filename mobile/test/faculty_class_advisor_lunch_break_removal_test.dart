import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_class_advisor_screen.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';

class MockFacultyService extends FacultyService {
  final ClassAdvisorAvailablePeriodsResponse mockAvailable;
  final ClassAdvisorPeriodsForDateResponse mockPast;

  MockFacultyService({
    required this.mockAvailable,
    required this.mockPast,
  });

  @override
  Future<ClassAdvisorAvailablePeriodsResponse> fetchClassAdvisorAvailablePeriods() async {
    return mockAvailable;
  }

  @override
  Future<ClassAdvisorPeriodsForDateResponse> fetchClassAdvisorPeriodsForDate(String date) async {
    return mockPast;
  }
}

List<ClassAdvisorPeriodItem> _createSamplePeriods(String date, String dayOfWeek) {
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
      className: 'CSE - A',
      date: date,
      dayOfWeek: dayOfWeek,
      subjectFacultyName: 'Santhiya',
      status: 'AVAILABLE',
      canMark: true,
    ),
    ClassAdvisorPeriodItem(
      timetableEntryId: 102,
      periodId: 2,
      periodNumber: 2,
      periodName: 'Period 2',
      startTime: '10:00',
      endTime: '10:50',
      sessionType: 'MORNING',
      subjectCode: 'AIML',
      subjectName: 'Artificial Intelligence & Machine Learning',
      classId: 1,
      className: 'CSE - A',
      date: date,
      dayOfWeek: dayOfWeek,
      subjectFacultyName: 'Shankar',
      status: 'AVAILABLE',
      canMark: true,
    ),
    ClassAdvisorPeriodItem(
      timetableEntryId: 103,
      periodId: 3,
      periodNumber: 3,
      periodName: 'Period 3',
      startTime: '11:10',
      endTime: '12:00',
      sessionType: 'MORNING',
      subjectCode: 'CNS',
      subjectName: 'Cryptography & Network Security',
      classId: 1,
      className: 'CSE - A',
      date: date,
      dayOfWeek: dayOfWeek,
      subjectFacultyName: 'Dr. Ramesh',
      status: 'AVAILABLE',
      canMark: true,
    ),
    ClassAdvisorPeriodItem(
      timetableEntryId: 104,
      periodId: 4,
      periodNumber: 4,
      periodName: 'Period 4',
      startTime: '12:00',
      endTime: '12:50',
      sessionType: 'MORNING',
      subjectCode: 'SPM',
      subjectName: 'Software Project Management',
      classId: 1,
      className: 'CSE - A',
      date: date,
      dayOfWeek: dayOfWeek,
      subjectFacultyName: 'Priya',
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
      className: 'CSE - A',
      date: date,
      dayOfWeek: dayOfWeek,
      subjectFacultyName: 'Venkatesh',
      status: 'AVAILABLE',
      canMark: true,
    ),
    ClassAdvisorPeriodItem(
      timetableEntryId: 106,
      periodId: 6,
      periodNumber: 6,
      periodName: 'Period 6',
      startTime: '14:30',
      endTime: '15:20',
      sessionType: 'AFTERNOON',
      subjectCode: 'BDA',
      subjectName: 'Big Data Analytics',
      classId: 1,
      className: 'CSE - A',
      date: date,
      dayOfWeek: dayOfWeek,
      subjectFacultyName: 'Kavitha',
      status: 'AVAILABLE',
      canMark: true,
    ),
    ClassAdvisorPeriodItem(
      timetableEntryId: 107,
      periodId: 7,
      periodNumber: 7,
      periodName: 'Period 7',
      startTime: '15:20',
      endTime: '16:10',
      sessionType: 'AFTERNOON',
      subjectCode: 'MINI',
      subjectName: 'Mini Project',
      classId: 1,
      className: 'CSE - A',
      date: date,
      dayOfWeek: dayOfWeek,
      subjectFacultyName: 'Staff Team',
      status: 'AVAILABLE',
      canMark: true,
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final todayPeriods = _createSamplePeriods('2026-10-18', 'Sunday');
  final yesterdayPeriods = _createSamplePeriods('2026-10-17', 'Saturday');
  final pastPeriods = _createSamplePeriods('2026-10-16', 'Friday');

  final mockAvailable = ClassAdvisorAvailablePeriodsResponse(
    isClassAdvisor: true,
    advisedClass: AdvisedClassInfo(id: 1, name: 'CSE - A', academicYear: '2025-2026', gradeLevel: 'IV'),
    todayDate: '2026-10-18',
    todayDay: 'Sunday',
    yesterdayDate: '2026-10-17',
    yesterdayDay: 'Saturday',
    currentTime: '10:00',
    todayPeriods: todayPeriods,
    yesterdayPeriods: yesterdayPeriods,
    lunchBreak: LunchBreakInfo(),
  );

  final mockPast = ClassAdvisorPeriodsForDateResponse(
    isClassAdvisor: true,
    advisedClass: AdvisedClassInfo(id: 1, name: 'CSE - A', academicYear: '2025-2026', gradeLevel: 'IV'),
    date: '2026-10-16',
    dayOfWeek: 'Friday',
    isToday: false,
    periods: pastPeriods,
    lunchBreak: LunchBreakInfo(),
  );

  group('Faculty / Class Advisor Lunch Break Card Removal & Layout Tests', () {
    testWidgets('Today & Yesterday views do NOT render the Lunch Break card on Samsung Galaxy S24',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockService = MockFacultyService(
        mockAvailable: mockAvailable,
        mockPast: mockPast,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FacultyService>.value(value: mockService),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const FacultyClassAdvisorScreen(),
          ),
        ),
      );

      // Allow async initState callback to run and complete
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Confirm that the unwanted Lunch Break card is NOT found anywhere
      expect(find.text('Lunch Break (12:50 PM – 01:40 PM)'), findsNothing);
      expect(
        find.textContaining('Institutional College Break — Strictly excluded from attendance marking'),
        findsNothing,
      );
      expect(find.byIcon(Icons.restaurant_rounded), findsNothing);

      // 2. Confirm legitimate teaching sessions and periods remain present
      expect(find.text('MORNING SESSION (P1 – P4)'), findsOneWidget);
      expect(find.text('Cyber Forensics (CF)'), findsOneWidget); // P1
      expect(find.text('Artificial Intelligence & Machine Learning (AIML)'), findsOneWidget); // P2
      expect(find.textContaining('Short Break'), findsNothing); // All breaks removed across project
      expect(find.text('AFTERNOON SESSION (P5 – P7)'), findsOneWidget);
      expect(find.text('Cloud Computing (CC)'), findsOneWidget); // P5

      // 3. Confirm zero RenderFlex overflow occurs
      expect(tester.takeException(), isNull);

      // 4. Check YESTERDAY tab
      final yesterdayTab = find.text('YESTERDAY');
      expect(yesterdayTab, findsOneWidget);
      await tester.tap(yesterdayTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Lunch Break (12:50 PM – 01:40 PM)'), findsNothing);
      expect(
        find.textContaining('Institutional College Break — Strictly excluded from attendance marking'),
        findsNothing,
      );
      expect(find.byIcon(Icons.restaurant_rounded), findsNothing);
      expect(find.text('MORNING SESSION (P1 – P4)'), findsOneWidget);
      expect(find.text('AFTERNOON SESSION (P5 – P7)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Past Dates view does NOT render the Lunch Break card in Dark Theme',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockService = MockFacultyService(
        mockAvailable: mockAvailable,
        mockPast: mockPast,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FacultyService>.value(value: mockService),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const FacultyClassAdvisorScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Switch to PAST DATES tab
      final pastDatesTab = find.text('PAST DATES');
      expect(pastDatesTab, findsOneWidget);
      await tester.tap(pastDatesTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Confirm that the Lunch Break card is NOT found in Past Dates view either
      expect(find.text('Lunch Break (12:50 PM – 01:40 PM)'), findsNothing);
      expect(
        find.textContaining('Institutional College Break — Strictly excluded from attendance marking'),
        findsNothing,
      );
      expect(find.byIcon(Icons.restaurant_rounded), findsNothing);

      // Confirm legitimate teaching sessions in Past Dates view
      expect(find.text('MORNING SESSION (P1 – P4)'), findsOneWidget);
      expect(find.text('AFTERNOON SESSION (P5 – P7)'), findsOneWidget);
      expect(find.text('Cyber Forensics (CF)'), findsOneWidget);

      // Confirm zero layout exceptions in Dark Theme
      expect(tester.takeException(), isNull);
    });

    test('Data model & business rule preservation: Teaching periods exclude lunch break', () {
      final samplePeriods = [
        ClassAdvisorPeriodItem.fromJson({
          'timetable_entry_id': 1,
          'period_id': 10,
          'period_number': 1,
          'period_name': 'Period 1',
          'start_time': '09:10 AM',
          'end_time': '10:00 AM',
          'subject_name': 'Cyber Forensics',
          'subject_code': 'CF',
          'subject_faculty_name': 'Santhiya',
          'status': 'MARKED',
          'can_mark': true,
        }),
        ClassAdvisorPeriodItem.fromJson({
          'timetable_entry_id': 2,
          'period_id': 11,
          'period_number': 2,
          'period_name': 'Period 2',
          'start_time': '10:00 AM',
          'end_time': '10:50 AM',
          'subject_name': 'AIML',
          'subject_code': 'AIML',
          'subject_faculty_name': 'Shankar',
          'status': 'MARKED',
          'can_mark': true,
        }),
      ];

      // Teaching periods are strictly positive integers 1..7
      for (final p in samplePeriods) {
        expect(p.periodNumber >= 1 && p.periodNumber <= 7, isTrue);
      }
    });
  });
}
