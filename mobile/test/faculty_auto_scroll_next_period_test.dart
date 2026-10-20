import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_class_advisor_screen.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/models/faculty_model.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';

class MockAutoScrollFacultyService extends FacultyService {
  final ClassAdvisorAvailablePeriodsResponse mockAvailable;
  final ClassAdvisorPeriodsForDateResponse mockPast;

  MockAutoScrollFacultyService({
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

  @override
  List<FacultyScheduleItem> get classAdvisorSchedule => [];
}

List<ClassAdvisorPeriodItem> _createTestPeriods({
  required String date,
  required String dayOfWeek,
  Map<int, String>? statuses,
}) {
  final defaultStatuses = {
    1: 'AVAILABLE',
    2: 'AVAILABLE',
    3: 'AVAILABLE',
    4: 'AVAILABLE',
    5: 'AVAILABLE',
    6: 'AVAILABLE',
    7: 'AVAILABLE',
  };
  if (statuses != null) {
    defaultStatuses.addAll(statuses);
  }

  final periodTimes = [
    {'num': 1, 'start': '09:10', 'end': '10:00', 'code': 'CF', 'name': 'Cyber Forensics'},
    {'num': 2, 'start': '10:00', 'end': '10:50', 'code': 'AIML', 'name': 'AI & ML'},
    {'num': 3, 'start': '11:10', 'end': '12:00', 'code': 'CNS', 'name': 'Cryptography'},
    {'num': 4, 'start': '12:00', 'end': '12:50', 'code': 'SPM', 'name': 'Software PM'},
    {'num': 5, 'start': '13:40', 'end': '14:30', 'code': 'CC', 'name': 'Cloud Computing'},
    {'num': 6, 'start': '14:30', 'end': '15:20', 'code': 'IOT', 'name': 'Internet of Things'},
    {'num': 7, 'start': '15:20', 'end': '16:10', 'code': 'LIB', 'name': 'Library / Mentoring'},
  ];

  return periodTimes.map((item) {
    final pNum = item['num'] as int;
    final status = defaultStatuses[pNum] ?? 'AVAILABLE';
    return ClassAdvisorPeriodItem(
      timetableEntryId: 200 + pNum,
      periodId: pNum,
      periodNumber: pNum,
      periodName: 'Period $pNum',
      startTime: item['start'] as String,
      endTime: item['end'] as String,
      sessionType: pNum <= 4 ? 'MORNING' : 'AFTERNOON',
      subjectCode: item['code'] as String,
      subjectName: item['name'] as String,
      classId: 10,
      className: 'CSE - A',
      date: date,
      dayOfWeek: dayOfWeek,
      subjectFacultyName: 'Faculty $pNum',
      status: status,
      canMark: status == 'AVAILABLE',
      recordCount: status == 'ALREADY_MARKED' ? 45 : 0,
    );
  }).toList();
}

ClassAdvisorPeriodItem? findNextEligiblePeriod(
  List<ClassAdvisorPeriodItem> periods,
  int savedPeriodNumber,
) {
  final sortedPeriods = List<ClassAdvisorPeriodItem>.from(periods)
    ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));

  for (final p in sortedPeriods) {
    if (p.periodNumber > savedPeriodNumber) {
      final bool isAlreadyMarked = p.status == 'ALREADY_MARKED';
      final bool isEligible = (p.status == 'AVAILABLE' || p.canMark) && !isAlreadyMarked;
      if (isEligible) {
        return p;
      }
    }
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testDate = '2026-10-19';
  const testDay = 'Monday';

  group('Next Eligible Period Determination Logic', () {
    test('Saving Period 1 identifies Period 2 as next eligible', () {
      final periods = _createTestPeriods(date: testDate, dayOfWeek: testDay);
      final next = findNextEligiblePeriod(periods, 1);
      expect(next, isNotNull);
      expect(next!.periodNumber, equals(2));
      expect(next.subjectCode, equals('AIML'));
    });

    test('Saving Period 2 skips short tea break and identifies Period 3', () {
      final periods = _createTestPeriods(date: testDate, dayOfWeek: testDay);
      final next = findNextEligiblePeriod(periods, 2);
      expect(next, isNotNull);
      expect(next!.periodNumber, equals(3));
      expect(next.subjectCode, equals('CNS'));
    });

    test('Saving Period 4 skips lunch break and identifies Period 5', () {
      final periods = _createTestPeriods(date: testDate, dayOfWeek: testDay);
      final next = findNextEligiblePeriod(periods, 4);
      expect(next, isNotNull);
      expect(next!.periodNumber, equals(5));
      expect(next.subjectCode, equals('CC'));
    });

    test('Skips already marked periods (e.g., P2 already marked -> goes to P3)', () {
      final periods = _createTestPeriods(
        date: testDate,
        dayOfWeek: testDay,
        statuses: {2: 'ALREADY_MARKED'},
      );
      final next = findNextEligiblePeriod(periods, 1);
      expect(next, isNotNull);
      expect(next!.periodNumber, equals(3));
    });

    test('Skips multiple already marked periods (P2 and P3 marked -> goes to P4)', () {
      final periods = _createTestPeriods(
        date: testDate,
        dayOfWeek: testDay,
        statuses: {
          2: 'ALREADY_MARKED',
          3: 'ALREADY_MARKED',
        },
      );
      final next = findNextEligiblePeriod(periods, 1);
      expect(next, isNotNull);
      expect(next!.periodNumber, equals(4));
    });

    test('Returns null when saved period is the last period (Period 7)', () {
      final periods = _createTestPeriods(date: testDate, dayOfWeek: testDay);
      final next = findNextEligiblePeriod(periods, 7);
      expect(next, isNull);
    });

    test('Returns null when all subsequent periods are already marked', () {
      final periods = _createTestPeriods(
        date: testDate,
        dayOfWeek: testDay,
        statuses: {
          5: 'ALREADY_MARKED',
          6: 'ALREADY_MARKED',
          7: 'ALREADY_MARKED',
        },
      );
      final next = findNextEligiblePeriod(periods, 4);
      expect(next, isNull);
    });

    test('Handles out-of-order period arrays correctly by sorting', () {
      final periods = _createTestPeriods(date: testDate, dayOfWeek: testDay).reversed.toList();
      final next = findNextEligiblePeriod(periods, 2);
      expect(next, isNotNull);
      expect(next!.periodNumber, equals(3));
    });
  });

  group('FacultyClassAdvisorScreen Widget and Auto-Scroll Structure', () {
    Widget buildTestApp(FacultyService mockService) {
      return ChangeNotifierProvider<FacultyService>.value(
        value: mockService,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: FacultyClassAdvisorScreen(isStandalone: false),
          ),
        ),
      );
    }

    testWidgets('Renders all periods and attaches GlobalKeys for auto-scroll targets', (tester) async {
      final periods = _createTestPeriods(date: testDate, dayOfWeek: testDay);
      final mockData = ClassAdvisorAvailablePeriodsResponse(
        isClassAdvisor: true,
        advisedClass: AdvisedClassInfo(id: 10, name: 'CSE - A', academicYear: '2026-2027', gradeLevel: 'IV'),
        todayDate: testDate,
        todayDay: testDay,
        yesterdayDate: '2026-10-18',
        yesterdayDay: 'Sunday',
        currentTime: '10:05',
        todayPeriods: periods,
        yesterdayPeriods: [],
        lunchBreak: LunchBreakInfo(),
      );

      final mockService = MockAutoScrollFacultyService(
        mockAvailable: mockData,
        mockPast: ClassAdvisorPeriodsForDateResponse(
          isClassAdvisor: true,
          date: '2026-10-18',
          dayOfWeek: 'Sunday',
          isToday: false,
          periods: [],
          lunchBreak: LunchBreakInfo(),
        ),
      );

      // S24 physical resolution approximation
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(mockService));
      await tester.pumpAndSettle();

      // P1 and P2 should be immediately visible
      expect(find.text('P1'), findsOneWidget);
      expect(find.text('P2'), findsOneWidget);

      // Scroll ListView down
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.textContaining('Short Break'), findsNothing);

      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('P5'), findsOneWidget);
    });

    testWidgets('Tab bar switching works properly and maintains active index', (tester) async {
      final periods = _createTestPeriods(date: testDate, dayOfWeek: testDay);
      final mockData = ClassAdvisorAvailablePeriodsResponse(
        isClassAdvisor: true,
        advisedClass: AdvisedClassInfo(id: 10, name: 'CSE - A'),
        todayDate: testDate,
        todayDay: testDay,
        yesterdayDate: '2026-10-18',
        yesterdayDay: 'Sunday',
        currentTime: '10:05',
        todayPeriods: periods,
        yesterdayPeriods: periods,
        lunchBreak: LunchBreakInfo(),
      );

      final mockService = MockAutoScrollFacultyService(
        mockAvailable: mockData,
        mockPast: ClassAdvisorPeriodsForDateResponse(
          isClassAdvisor: true,
          date: '2026-10-18',
          dayOfWeek: 'Sunday',
          isToday: false,
          periods: [],
          lunchBreak: LunchBreakInfo(),
        ),
      );

      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(mockService));
      await tester.pumpAndSettle();

      // Tap YESTERDAY tab
      await tester.tap(find.text('YESTERDAY'));
      await tester.pumpAndSettle();

      expect(find.text("Yesterday's Periods (Sunday, 2026-10-18)"), findsOneWidget);

      // Tap PAST DATES tab
      await tester.tap(find.text('PAST DATES'));
      await tester.pumpAndSettle();

      expect(find.text('Change Date'), findsOneWidget);
    });
  });
}
