import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_attendance_report_screen.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/models/faculty_report_model.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';
import 'package:attendance_marker_mobile/utils/timezone_utils.dart';

String formatDate(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

class MockFacultyServiceForSummary extends ChangeNotifier implements FacultyService {
  int fetchSummaryCallCount = 0;
  int? lastClassId;
  int? lastSubjectId;
  String? lastStartDate;
  String? lastEndDate;

  FacultyClassSummaryModel? customSummaryResponse;

  FacultyAuthorizedReportOptionsModel mockOptions = FacultyAuthorizedReportOptionsModel(
    facultyId: 1,
    facultyName: 'Dr. Summary Advisor',
    isClassAdvisor: true,
    attendanceStartDate: '2026-01-01',
    currentDate: formatDate(TimezoneUtils.todayIst()),
    advisedClass: AdvisedClassInfo(
      id: 4,
      name: 'II Year CSE Cyber Security - Class 1',
    ),
    classes: [
      AuthorizedClassOptionModel(
        id: 4,
        name: 'II Year CSE Cyber Security - Class 1',
        isAdvisorForClass: true,
        subjects: [
          AuthorizedSubjectOptionModel(
            id: 101,
            code: '23CS301',
            name: 'Data Structures',
            isTeaching: true,
          ),
          AuthorizedSubjectOptionModel(
            id: 102,
            code: '23CS302',
            name: 'Operating Systems',
            isTeaching: true,
          ),
        ],
      ),
    ],
  );

  FacultyClassSummaryModel defaultSummary = FacultyClassSummaryModel(
    classId: 4,
    className: 'II Year CSE Cyber Security - Class 1',
    isClassAdvisorScope: true,
    totalPeriods: 13,
    totalStudents: 64,
    present: 640,
    purePresent: 639,
    absent: 192,
    od: 1,
    totalMarks: 832,
    percentage: 76.92,
    startDate: '2026-10-08',
    endDate: '2026-10-19',
    dateRangeDisplay: '08 Oct 2026 – 19 Oct 2026',
    isSunday: false,
    hasScheduledClasses: true,
    students: [
      FacultyStudentAttendanceRowModel(
        studentId: 1,
        rollNumber: '25CS001',
        fullName: 'Student 1',
        total: 13,
        present: 10,
        purePresent: 10,
        absent: 3,
        od: 0,
        percentage: 76.92,
      ),
      FacultyStudentAttendanceRowModel(
        studentId: 2,
        rollNumber: '25CS002',
        fullName: 'Student 2',
        total: 13,
        present: 10, // Under COUNT_AS_PRESENT
        purePresent: 9,  // Pure classroom attendance
        absent: 3,
        od: 1,
        percentage: 76.92,
      ),
    ],
  );

  @override
  Future<FacultyAuthorizedReportOptionsModel> fetchReportAuthorizedOptions() async {
    return mockOptions;
  }

  @override
  Future<FacultyClassSummaryModel> fetchClassSummaryReport({
    required int classId,
    int? subjectId,
    String? startDate,
    String? endDate,
  }) async {
    fetchSummaryCallCount++;
    lastClassId = classId;
    lastSubjectId = subjectId;
    lastStartDate = startDate;
    lastEndDate = endDate;

    if (customSummaryResponse != null) {
      return customSummaryResponse!;
    }
    return defaultSummary;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget createTestApp(FacultyService service, {ThemeData? theme}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<FacultyService>.value(value: service),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      home: const FacultyAttendanceReportScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Class Adviser Attendance Summary Model Tests', () {
    test('FacultyClassSummaryModel correctly parses new aggregation fields and fallbacks', () {
      final json = {
        'class_id': 4,
        'class_name': 'II Year CSE Cyber Security - Class 1',
        'is_class_advisor_scope': true,
        'total_periods': 13,
        'total_students': 64,
        'present': 640,
        'pure_present': 639,
        'absent': 192,
        'od': 1,
        'total_marks': 832,
        'percentage': 76.92,
        'start_date': '2026-10-08',
        'end_date': '2026-10-19',
        'date_range_display': '08 Oct 2026 – 19 Oct 2026',
        'is_sunday': false,
        'has_scheduled_classes': true,
        'students': [
          {
            'student_id': 1,
            'roll_number': '25CS001',
            'full_name': 'Student 1',
            'total': 13,
            'present': 10,
            'pure_present': 10,
            'absent': 3,
            'od': 0,
            'percentage': 76.92,
          },
          {
            'student_id': 2,
            'roll_number': '25CS002',
            'full_name': 'Student 2',
            'total': 13,
            'present': 10,
            'pure_present': 9,
            'absent': 3,
            'od': 1,
            'percentage': 76.92,
          },
        ],
      };

      final model = FacultyClassSummaryModel.fromJson(json);
      expect(model.classId, 4);
      expect(model.totalPeriods, 13);
      expect(model.totalStudents, 64);
      expect(model.effectiveTotalStudents, 64);
      expect(model.present, 640);
      expect(model.purePresent, 639);
      expect(model.absent, 192);
      expect(model.od, 1);
      expect(model.totalMarks, 832);
      expect(model.effectiveTotalMarks, 832);
      expect(model.percentage, 76.92);
      expect(model.dateRangeDisplay, '08 Oct 2026 – 19 Oct 2026');
      expect(model.isSunday, false);
      expect(model.hasScheduledClasses, true);

      // Verify student row pure present
      expect(model.students[0].purePresent, 10);
      expect(model.students[1].purePresent, 9);
      expect(model.students[1].present, 10);
      expect(model.students[1].od, 1);
    });

    test('FacultyClassSummaryModel gracefully falls back when total_students or total_marks are omitted', () {
      final json = {
        'class_id': 4,
        'class_name': 'Legacy Class',
        'total_periods': 5,
        'present': 45,
        'absent': 5,
        'od': 0,
        'percentage': 90.0,
        'students': [
          {
            'student_id': 1,
            'roll_number': '25CS001',
            'full_name': 'Alice',
            'total': 5,
            'present': 5,
            'absent': 0,
            'od': 0,
            'percentage': 100.0,
          },
          {
            'student_id': 2,
            'roll_number': '25CS002',
            'full_name': 'Bob',
            'total': 5,
            'present': 4,
            'absent': 1,
            'od': 0,
            'percentage': 80.0,
          },
        ],
      };

      final model = FacultyClassSummaryModel.fromJson(json);
      expect(model.totalStudents, 2);
      expect(model.effectiveTotalStudents, 2);
      expect(model.effectiveTotalMarks, 10); // 2 students * 5 periods
    });
  });

  group('Class Adviser Attendance Summary UI & Aggregation Tests', () {
    testWidgets('1. Summary card renders explicit P (Marks), A (Marks), OD (Marks) and Students',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForSummary();
      await tester.pumpWidget(createTestApp(service));
      await tester.pumpAndSettle();

      // Verify Tab 0 is selected by default
      expect(find.text('Summary'), findsOneWidget);

      // Verify Class and Scope Headers
      expect(find.text('II Year CSE Cyber Security - Class 1'), findsWidgets);
      expect(find.text('All Subjects Aggregate'), findsOneWidget);
      expect(find.text('08 Oct 2026 – 19 Oct 2026'), findsOneWidget);
      expect(find.text('76.9% Avg'), findsOneWidget);

      // Verify distinct labels and stat values: Periods, P (Marks), A (Marks), OD (Marks), Students
      expect(find.text('Periods'), findsOneWidget);
      expect(find.byKey(const Key('mini_stat_value_Periods')), findsOneWidget);
      expect((tester.widget(find.byKey(const Key('mini_stat_value_Periods'))) as Text).data, '13');

      expect(find.text('P (Marks)'), findsOneWidget);
      expect(find.byKey(const Key('mini_stat_value_P (Marks)')), findsOneWidget);
      expect((tester.widget(find.byKey(const Key('mini_stat_value_P (Marks)'))) as Text).data, '640');

      expect(find.text('A (Marks)'), findsOneWidget);
      expect(find.byKey(const Key('mini_stat_value_A (Marks)')), findsOneWidget);
      expect((tester.widget(find.byKey(const Key('mini_stat_value_A (Marks)'))) as Text).data, '192');

      expect(find.text('OD (Marks)'), findsOneWidget);
      expect(find.byKey(const Key('mini_stat_value_OD (Marks)')), findsOneWidget);
      expect((tester.widget(find.byKey(const Key('mini_stat_value_OD (Marks)'))) as Text).data, '1');

      expect(find.text('Students'), findsOneWidget);
      expect(find.byKey(const Key('mini_stat_value_Students')), findsOneWidget);
      expect((tester.widget(find.byKey(const Key('mini_stat_value_Students'))) as Text).data, '64');

      // Verify explanatory footnote distinguishing marks from student count
      expect(
        find.text(
          '* Attendance marks count 64 enrolled students across 13 conducted periods (832 total marks).',
        ),
        findsOneWidget,
      );

      // Verify student row displays pure present without arithmetic confusion
      // Student 1: 10 present, 3 absent, 0 OD
      expect(find.text('Roll: 25CS001 • P: 10 | A: 3 | OD: 0'), findsOneWidget);
      // Student 2: pure 9 present, 3 absent, 1 OD (9 + 3 + 1 = 13 periods)
      expect(find.text('Roll: 25CS002 • P: 9 | A: 3 | OD: 1'), findsOneWidget);
    });

    testWidgets('2. Date preset chips filter Tab 0 scope and invoke API with date bounds',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForSummary();
      await tester.pumpWidget(createTestApp(service));
      await tester.pumpAndSettle();

      // Verify preset chips exist on Tab 0
      expect(find.text('All Recorded'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Past 7 Days'), findsOneWidget);
      expect(find.text('Custom Range'), findsOneWidget);

      // Tap "Today" preset
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      expect(service.fetchSummaryCallCount, greaterThanOrEqualTo(2));
      final todayStr = formatDate(TimezoneUtils.todayIst());
      expect(service.lastStartDate, todayStr);
      expect(service.lastEndDate, todayStr);

      // Tap "Yesterday" preset
      await tester.tap(find.text('Yesterday'));
      await tester.pumpAndSettle();

      final yesterdayStr = formatDate(TimezoneUtils.todayIst().subtract(const Duration(days: 1)));
      expect(service.lastStartDate, yesterdayStr);
      expect(service.lastEndDate, yesterdayStr);

      // Tap "All Recorded" to reset
      await tester.tap(find.text('All Recorded'));
      await tester.pumpAndSettle();
      expect(service.lastStartDate, isNull);
      expect(service.lastEndDate, isNull);
    });

    testWidgets('3. Sunday with no scheduled classes displays friendly message card',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForSummary();
      service.customSummaryResponse = FacultyClassSummaryModel(
        classId: 4,
        className: 'II Year CSE Cyber Security - Class 1',
        totalPeriods: 0,
        totalStudents: 64,
        present: 0,
        purePresent: 0,
        absent: 0,
        od: 0,
        totalMarks: 0,
        percentage: 0.0,
        isSunday: true,
        hasScheduledClasses: false,
        noClassMessage: 'No Classes on Sunday\nThere are no scheduled classes on Sunday. Enjoy your day off!',
        students: [],
      );

      await tester.pumpWidget(createTestApp(service));
      await tester.pumpAndSettle();

      // Verify Sunday message and icon
      expect(find.text('No Classes on Sunday'), findsOneWidget);
      expect(find.text('There are no scheduled classes on Sunday. Enjoy your day off!'), findsOneWidget);
      expect(find.byIcon(Icons.beach_access_rounded), findsOneWidget);

      // Ensure no raw/empty error message
      expect(find.text('Error'), findsNothing);
    });

    testWidgets('4. Responsive and dark theme rendering verification',
        (WidgetTester tester) async {
      // Test on mobile screen (1080x2340 @ 2.0x = 540x1170 logical)
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForSummary();
      await tester.pumpWidget(createTestApp(service, theme: AppTheme.darkTheme));
      await tester.pumpAndSettle();

      // No rendering overflow or exceptions
      expect(tester.takeException(), isNull);
      expect(find.text('P (Marks)'), findsOneWidget);
      expect(find.text('Students'), findsOneWidget);
    });
  });
}
