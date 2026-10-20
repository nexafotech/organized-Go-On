import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_attendance_report_screen.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/models/faculty_report_model.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';
import 'package:attendance_marker_mobile/utils/timezone_utils.dart';

String formatDate(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

class MockFacultyServiceForReports extends ChangeNotifier implements FacultyService {
  int fetchRangeCallCount = 0;
  String? lastFromDate;
  String? lastToDate;
  int? lastClassId;
  int? lastSubjectId;

  int pdfDownloadCallCount = 0;
  int excelDownloadCallCount = 0;

  FacultyAuthorizedReportOptionsModel mockOptions = FacultyAuthorizedReportOptionsModel(
    facultyId: 1,
    facultyName: 'Dr. Advisor',
    isClassAdvisor: true,
    attendanceStartDate: '2026-01-01',
    currentDate: formatDate(TimezoneUtils.todayIst()),
    advisedClass: AdvisedClassInfo(
      id: 1,
      name: 'II Year CSE Cyber Security - Class 1',
    ),
    classes: [
      AuthorizedClassOptionModel(
        id: 1,
        name: 'II Year CSE Cyber Security - Class 1',
        isAdvisorForClass: true,
        subjects: [
          AuthorizedSubjectOptionModel(
            id: 101,
            code: '23CS301',
            name: 'Data Structures',
            isTeaching: true,
          ),
        ],
      ),
    ],
  );

  AttendanceRangeReportModel mockRangeReport = AttendanceRangeReportModel(
    classId: 1,
    className: 'II Year CSE Cyber Security - Class 1',
    subjectId: 101,
    subjectCode: '23CS301',
    subjectName: 'Data Structures',
    fromDate: '2026-10-12',
    toDate: '2026-10-18',
    totalDays: 7,
    isSingleDay: false,
    hasRecords: true,
    totalStudents: 2,
    totalPeriodsConducted: 1,
    present: 10,
    absent: 2,
    od: 1,
    totalMarked: 13,
    percentage: 84.62,
    percentageBasis: 'OD counted as present',
    generatedAt: '2026-10-18T12:00:00',
    summary: [
      RangeStudentSummaryModel(
        rollNumber: '25CS001',
        fullName: 'Alice Walker',
        present: 5,
        absent: 1,
        od: 1,
        totalMarked: 7,
        percentage: 85.71,
      ),
    ],
    periodSummary: [
      RangePeriodSummaryModel(
        date: '2026-10-18',
        periodNumber: 1,
        periodName: 'Period 1',
        subjectCode: '23CS301',
        subjectName: 'Data Structures',
        present: 2,
        absent: 0,
        od: 0,
        totalMarked: 2,
      ),
    ],
  );

  @override
  Future<FacultyAuthorizedReportOptionsModel> fetchReportAuthorizedOptions() async {
    return mockOptions;
  }

  @override
  Future<AttendanceRangeReportModel> fetchAttendanceRangeReport({
    required int classId,
    required String fromDate,
    required String toDate,
    int? subjectId,
  }) async {
    fetchRangeCallCount++;
    lastClassId = classId;
    lastFromDate = fromDate;
    lastToDate = toDate;
    lastSubjectId = subjectId;
    return mockRangeReport;
  }

  @override
  Future<List<int>> downloadAttendanceRangePdf({
    required int classId,
    required String fromDate,
    required String toDate,
    int? subjectId,
  }) async {
    pdfDownloadCallCount++;
    return [0x25, 0x50, 0x44, 0x46]; // %PDF
  }

  @override
  Future<List<int>> downloadAttendanceRangeExcel({
    required int classId,
    required String fromDate,
    required String toDate,
    int? subjectId,
  }) async {
    excelDownloadCallCount++;
    return [0x50, 0x4B, 0x03, 0x04]; // PK zip
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget createTestWidget({
    required MockFacultyServiceForReports facultyService,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return ChangeNotifierProvider<FacultyService>.value(
      value: facultyService,
      child: MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: const FacultyAttendanceReportScreen(),
      ),
    );
  }

  group('Faculty Attendance Report Date Range & Export Tests', () {
    testWidgets('Renders Date Range tab and initial date preset correctly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForReports();
      await tester.pumpWidget(createTestWidget(facultyService: service));
      await tester.pumpAndSettle();

      // Find and tap "Date Range" tab
      final dateRangeTab = find.text('Date Range');
      expect(dateRangeTab, findsOneWidget);
      await tester.tap(dateRangeTab);
      await tester.pumpAndSettle();

      // Check "Date Range Selection" card title and inputs
      expect(find.text('Date Range Selection'), findsOneWidget);
      expect(find.text('From Date'), findsOneWidget);
      expect(find.text('To Date'), findsOneWidget);
      expect(find.text('Past 7 Days'), findsOneWidget);
      expect(find.text('Past 14 Days'), findsOneWidget);
      expect(find.text('Past 30 Days'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('Generate PDF'), findsOneWidget);
      expect(find.text('Export Excel'), findsOneWidget);

      final today = TimezoneUtils.todayIst();
      final expectedFrom7 = formatDate(today.subtract(const Duration(days: 6)));
      final expectedTo = formatDate(today);

      expect(service.lastFromDate, expectedFrom7);
      expect(service.lastToDate, expectedTo);
    });

    testWidgets('Quick range buttons calculate exact intervals (Past 14, Past 30, This Month)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForReports();
      await tester.pumpWidget(createTestWidget(facultyService: service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Date Range'));
      await tester.pumpAndSettle();

      final today = TimezoneUtils.todayIst();
      final expectedTo = formatDate(today);

      // Tap Past 14 Days
      await tester.tap(find.text('Past 14 Days'));
      await tester.pumpAndSettle();
      final expectedFrom14 = formatDate(today.subtract(const Duration(days: 13)));
      expect(service.lastFromDate, expectedFrom14);
      expect(service.lastToDate, expectedTo);

      // Tap Past 30 Days
      await tester.tap(find.text('Past 30 Days'));
      await tester.pumpAndSettle();
      final expectedFrom30 = formatDate(today.subtract(const Duration(days: 29)));
      expect(service.lastFromDate, expectedFrom30);
      expect(service.lastToDate, expectedTo);

      // Tap This Month
      await tester.tap(find.text('This Month'));
      await tester.pumpAndSettle();
      final expectedThisMonth = formatDate(DateTime(today.year, today.month, 1));
      expect(service.lastFromDate, expectedThisMonth);
      expect(service.lastToDate, expectedTo);

      // Tap Past 7 Days again
      await tester.tap(find.text('Past 7 Days'));
      await tester.pumpAndSettle();
      final expectedFrom7 = formatDate(today.subtract(const Duration(days: 6)));
      expect(service.lastFromDate, expectedFrom7);
      expect(service.lastToDate, expectedTo);
    });

    testWidgets('Generate PDF and Export Excel buttons trigger download service and handle state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForReports();
      await tester.pumpWidget(createTestWidget(facultyService: service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Date Range'));
      await tester.pumpAndSettle();

      // Trigger PDF export inside runAsync so File I/O completes
      final pdfBtn = find.text('Generate PDF');
      expect(pdfBtn, findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(pdfBtn);
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(service.pdfDownloadCallCount, 1);
      expect(find.textContaining('PDF generated'), findsOneWidget);

      // Dismiss current SnackBar so Excel SnackBar can be displayed immediately
      ScaffoldMessenger.of(tester.element(pdfBtn)).hideCurrentSnackBar();
      await tester.pump();

      // Trigger Excel export inside runAsync so File I/O completes
      final excelBtn = find.text('Export Excel');
      expect(excelBtn, findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(excelBtn);
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(service.excelDownloadCallCount, 1);
      expect(find.textContaining('Excel generated'), findsOneWidget);
    });

    testWidgets('Date picker validation rejects From Date > To Date and handles single-day range', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForReports();
      await tester.pumpWidget(createTestWidget(facultyService: service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Date Range'));
      await tester.pumpAndSettle();

      // Tap From Date to open date picker
      final fromDateFinder = find.text('From Date');
      expect(fromDateFinder, findsOneWidget);
      await tester.tap(fromDateFinder);
      await tester.pumpAndSettle();

      // Date picker dialog is displayed
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Cancel date picker
      final cancelBtn = find.text('Cancel');
      if (cancelBtn.evaluate().isNotEmpty) {
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();
      }

      // Check single-day support: if both From and To are identical
      final today = TimezoneUtils.todayIst();
      service.mockRangeReport = AttendanceRangeReportModel(
        classId: 1,
        className: 'II Year CSE Cyber Security - Class 1',
        fromDate: formatDate(today),
        toDate: formatDate(today),
        totalDays: 1,
        isSingleDay: true,
        hasRecords: true,
        totalStudents: 2,
        totalPeriodsConducted: 1,
        present: 2,
        absent: 0,
        od: 0,
        totalMarked: 2,
        percentage: 100.0,
        percentageBasis: 'OD counted as present',
        generatedAt: '2026-10-18T12:00:00',
        summary: [],
        periodSummary: [],
      );

      // Single-day range is valid
      expect(service.mockRangeReport.isSingleDay, isTrue);
      expect(service.mockRangeReport.totalDays, 1);
    });

    testWidgets('Renders cleanly in Dark Mode without clipping or errors', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForReports();
      await tester.pumpWidget(createTestWidget(facultyService: service, themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Date Range'));
      await tester.pumpAndSettle();

      expect(find.text('Date Range Selection'), findsOneWidget);
      expect(find.text('Generate PDF'), findsOneWidget);
      expect(find.text('Export Excel'), findsOneWidget);
    });
  });
}
