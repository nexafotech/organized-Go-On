import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_attendance_report_screen.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/models/faculty_report_model.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';

class MockFacultyServiceForResponsiveTest extends ChangeNotifier implements FacultyService {
  final FacultyAuthorizedReportOptionsModel mockOptions = FacultyAuthorizedReportOptionsModel(
    facultyId: 1,
    facultyName: 'Dr. Advisor',
    isClassAdvisor: true,
    attendanceStartDate: '2026-10-08',
    currentDate: '2026-10-19',
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

  final FacultyHistoricalMatrixModel mockHistoricalMatrix = FacultyHistoricalMatrixModel(
    classId: 1,
    className: 'II Year CSE Cyber Security - Class 1',
    subjectId: null,
    subjectCode: null,
    subjectName: null,
    startDate: '2026-10-08',
    endDate: '2026-10-19',
    attendanceStartDate: '2026-10-08',
    currentDate: '2026-10-19',
    totalDates: 12,
    isClassAdvisorScope: true,
    students: [
      FacultyStudentAttendanceRowModel(
        studentId: 1,
        rollNumber: '721025149001',
        fullName: 'ABINAYA B',
        total: 13,
        present: 13,
        absent: 0,
        od: 0,
        percentage: 100.0,
      ),
      FacultyStudentAttendanceRowModel(
        studentId: 2,
        rollNumber: '721025149002',
        fullName: 'ABISHEK A',
        total: 13,
        present: 11,
        absent: 2,
        od: 0,
        percentage: 84.6,
      ),
      FacultyStudentAttendanceRowModel(
        studentId: 3,
        rollNumber: '721025149003',
        fullName: 'AKASH K',
        total: 13,
        present: 13,
        absent: 0,
        od: 0,
        percentage: 100.0,
      ),
      FacultyStudentAttendanceRowModel(
        studentId: 4,
        rollNumber: '721025149004',
        fullName: 'ANANTHA BALAJI M',
        total: 13,
        present: 12,
        absent: 1,
        od: 0,
        percentage: 92.3,
      ),
    ],
    dates: [
      HistoricalMatrixDateEntryModel(
        date: '2026-10-19',
        dayOfWeek: 'Monday',
        periods: [
          DateMatrixPeriodHeaderModel(
            periodNumber: 1,
            periodName: 'Period 1',
            startTime: '09:10',
            endTime: '10:00',
            subjectCode: '23CS301',
            facultyName: 'Dr. Advisor',
            status: 'ALREADY_MARKED',
            totalMarked: 4,
          ),
        ],
        students: [
          DateMatrixStudentRowModel(
            studentId: 1,
            rollNumber: '721025149001',
            fullName: 'ABINAYA B',
            periodStatuses: {'1': 'PRESENT'},
            morningStatus: 'PRESENT',
            afternoonStatus: 'PRESENT',
            dailyResult: 'PRESENT',
          ),
        ],
      ),
    ],
  );

  @override
  Future<FacultyAuthorizedReportOptionsModel> fetchReportAuthorizedOptions() async {
    return mockOptions;
  }

  @override
  Future<FacultyHistoricalMatrixModel> fetchHistoricalMatrixReport({
    required int classId,
    int? subjectId,
    String? startDate,
    String? endDate,
  }) async {
    return mockHistoricalMatrix;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final Map<String, Size> testViewports = {
    'Narrow Phone (320x640)': const Size(320, 640),
    'Standard Android (360x800)': const Size(360, 800),
    'Samsung S24 (390x844)': const Size(390, 844),
    'Tablet Portrait (768x1024)': const Size(768, 1024),
    'Tablet Landscape (1024x768)': const Size(1024, 768),
    'Laptop (1366x768)': const Size(1366, 768),
    'Desktop (1920x1080)': const Size(1920, 1080),
  };

  group('Class Adviser Attendance Screen Responsive & Overflow Audit', () {
    for (final entry in testViewports.entries) {
      testWidgets('Renders Historical Matrix on ${entry.key} without RenderFlex overflow', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockService = MockFacultyServiceForResponsiveTest();

        await tester.pumpWidget(
          ChangeNotifierProvider<FacultyService>.value(
            value: mockService,
            child: const MaterialApp(
              home: FacultyAttendanceReportScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Switch to Historical Matrix tab (mode 2)
        final historicalTab = find.text('Historical');
        expect(historicalTab, findsOneWidget);
        await tester.ensureVisible(historicalTab);
        await tester.pumpAndSettle();
        await tester.tap(historicalTab);
        await tester.pumpAndSettle();

        // 1. Verify Mode Toggle tabs are all present and accessible
        expect(find.text('Summary'), findsOneWidget);
        expect(find.text('Daily Matrix'), findsOneWidget);
        expect(find.text('Historical'), findsOneWidget);
        expect(find.text('Date Range'), findsOneWidget);

        // 2. Verify Date Range bar is rendered with Filter Range action
        expect(find.textContaining('Range: 2026-10-08'), findsWidgets);
        expect(find.text('Filter Range'), findsOneWidget);

        // 3. Verify Class Summary card and badge
        expect(find.text('II Year CSE Cyber Security - Class 1'), findsWidgets);
        expect(find.text('Advisor Scope'), findsWidgets);
        expect(find.textContaining('12 Day(s) • 4 Students'), findsOneWidget);

        // 4. Verify Student Aggregate Table renders student rows
        expect(find.text('Student Aggregate in Range'), findsOneWidget);
        expect(find.text('ABINAYA B'), findsOneWidget);
        expect(find.text('721025149001'), findsOneWidget);
        expect(find.text('ABISHEK A'), findsOneWidget);
      });
    }

    testWidgets('Renders with 1.35x accessibility text scale on mobile without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockService = MockFacultyServiceForResponsiveTest();

      await tester.pumpWidget(
        ChangeNotifierProvider<FacultyService>.value(
          value: mockService,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                textScaler: TextScaler.linear(1.35),
              ),
              child: const FacultyAttendanceReportScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final historicalTab = find.text('Historical');
      expect(historicalTab, findsOneWidget);
      await tester.ensureVisible(historicalTab);
      await tester.pumpAndSettle();
      await tester.tap(historicalTab);
      await tester.pumpAndSettle();

      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('Historical'), findsOneWidget);
      expect(find.text('Filter Range'), findsOneWidget);
      expect(find.text('Student Aggregate in Range'), findsOneWidget);
      expect(find.text('ABINAYA B'), findsOneWidget);
    });
  });
}
