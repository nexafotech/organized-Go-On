import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/core/network/api_client.dart';
import 'package:attendance_marker_mobile/core/utils/file_saver.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_attendance_report_screen.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/models/faculty_report_model.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';

class MockFacultyServiceForDownloadTests extends ChangeNotifier implements FacultyService {
  int pdfDownloadCallCount = 0;
  int excelDownloadCallCount = 0;
  bool shouldThrowNoRecords = false;
  bool shouldThrowNetworkError = false;

  final FacultyAuthorizedReportOptionsModel mockOptions = FacultyAuthorizedReportOptionsModel(
    facultyId: 1,
    facultyName: 'Dr. John Doe',
    isClassAdvisor: true,
    attendanceStartDate: '2026-10-01',
    currentDate: '2026-10-20',
    advisedClass: AdvisedClassInfo(id: 1, name: 'II Year CSE Cyber Security - Class 1'),
    classes: [
      AuthorizedClassOptionModel(
        id: 1,
        name: 'II Year CSE Cyber Security - Class 1',
        isAdvisorForClass: true,
        subjects: [
          AuthorizedSubjectOptionModel(id: 101, code: '23CS301', name: 'Data Structures', isTeaching: true),
        ],
      ),
    ],
  );

  final AttendanceRangeReportModel mockRangeReport = AttendanceRangeReportModel(
    classId: 1,
    className: 'II Year CSE Cyber Security - Class 1',
    subjectId: 101,
    subjectCode: '23CS301',
    subjectName: 'Data Structures',
    fromDate: '2026-10-14',
    toDate: '2026-10-20',
    totalDays: 7,
    isSingleDay: false,
    hasRecords: true,
    totalStudents: 64,
    totalPeriodsConducted: 8,
    present: 512,
    absent: 32,
    od: 8,
    totalMarked: 552,
    percentage: 94.2,
    percentageBasis: 'OD counted as Present',
    generatedAt: '2026-10-20T10:00:00',
    scopeNote: 'Class Advisor Scope (All Subjects)',
    summary: [
      RangeStudentSummaryModel(
        rollNumber: '721025149001',
        fullName: 'Abinaya B',
        present: 13,
        absent: 0,
        od: 0,
        totalMarked: 13,
        percentage: 100.0,
      ),
    ],
    periodSummary: [
      RangePeriodSummaryModel(
        date: '2026-10-14',
        periodNumber: 1,
        periodName: 'Period 1',
        subjectCode: '23CS301',
        subjectName: 'Data Structures',
        present: 60,
        absent: 4,
        od: 0,
        totalMarked: 64,
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
    if (shouldThrowNoRecords) {
      return AttendanceRangeReportModel(
        classId: 1,
        className: 'II Year CSE Cyber Security - Class 1',
        subjectId: null,
        subjectCode: null,
        subjectName: null,
        fromDate: fromDate,
        toDate: toDate,
        totalDays: 7,
        isSingleDay: false,
        hasRecords: false,
        totalStudents: 0,
        totalPeriodsConducted: 0,
        present: 0,
        absent: 0,
        od: 0,
        totalMarked: 0,
        percentage: null,
        percentageBasis: 'OD counted as Present',
        generatedAt: '2026-10-20T10:00:00',
        scopeNote: 'Class Advisor Scope',
        summary: [],
        periodSummary: [],
      );
    }
    return mockRangeReport;
  }

  @override
  Future<List<int>> downloadAttendanceRangePdf({
    required int classId,
    required String fromDate,
    required String toDate,
    int? subjectId,
  }) async {
    if (shouldThrowNoRecords) {
      throw ApiException(404, 'No attendance records were found between $fromDate and $toDate.');
    }
    if (shouldThrowNetworkError) {
      throw ApiException(0, 'Unable to reach the server. Check your connection.');
    }
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
    if (shouldThrowNoRecords) {
      throw ApiException(404, 'No attendance records were found between $fromDate and $toDate.');
    }
    if (shouldThrowNetworkError) {
      throw ApiException(0, 'Unable to reach the server. Check your connection.');
    }
    excelDownloadCallCount++;
    return [0x50, 0x4B, 0x03, 0x04]; // PK zip (XLSX)
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget createTestWidget({
    required MockFacultyServiceForDownloadTests facultyService,
  }) {
    return ChangeNotifierProvider<FacultyService>.value(
      value: facultyService,
      child: const MaterialApp(
        home: FacultyAttendanceReportScreen(),
      ),
    );
  }

  group('Real PDF and Excel Download Verification Tests', () {
    testWidgets('1. Generate PDF button fetches real PDF bytes and saves with meaningful filename', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForDownloadTests();
      await tester.pumpWidget(createTestWidget(facultyService: service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Date Range'));
      await tester.pumpAndSettle();

      final pdfBtn = find.text('Generate PDF');
      expect(pdfBtn, findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(pdfBtn);
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(service.pdfDownloadCallCount, 1);
      expect(find.textContaining('PDF generated: go-on_attendance_'), findsOneWidget);
      expect(find.textContaining('Saved to:'), findsOneWidget);
    });

    testWidgets('2. Export Excel button fetches real XLSX bytes and saves with meaningful filename', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForDownloadTests();
      await tester.pumpWidget(createTestWidget(facultyService: service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Date Range'));
      await tester.pumpAndSettle();

      final excelBtn = find.text('Export Excel');
      expect(excelBtn, findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(excelBtn);
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(service.excelDownloadCallCount, 1);
      expect(find.textContaining('Excel generated: go-on_attendance_'), findsOneWidget);
      expect(find.textContaining('Saved to:'), findsOneWidget);
    });

    testWidgets('3. Empty attendance records in date range displays clean error and does not produce dummy files', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForDownloadTests();
      service.shouldThrowNoRecords = true;

      await tester.pumpWidget(createTestWidget(facultyService: service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Date Range'));
      await tester.pumpAndSettle();

      final pdfBtn = find.text('Generate PDF');
      await tester.runAsync(() async {
        await tester.tap(pdfBtn);
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.textContaining('No attendance records were found'), findsOneWidget);
    });

    testWidgets('4. Network failure displays retryable error notification', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForDownloadTests();
      service.shouldThrowNetworkError = true;

      await tester.pumpWidget(createTestWidget(facultyService: service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Date Range'));
      await tester.pumpAndSettle();

      final excelBtn = find.text('Export Excel');
      await tester.runAsync(() async {
        await tester.tap(excelBtn);
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.textContaining('Unable to reach the server'), findsOneWidget);
    });

    test('5. SaveFileResult data model correctly preserves file path and open capability', () {
      const result = SaveFileResult(
        success: true,
        fileName: 'go-on_attendance_Class1_all_subjects_2026-10-14_to_2026-10-20.pdf',
        path: '/storage/emulated/0/Download/go-on_attendance_Class1_all_subjects_2026-10-14_to_2026-10-20.pdf',
        uriString: 'content://media/external/downloads/100',
        userDisplayPath: 'Downloads/go-on_attendance_Class1_all_subjects_2026-10-14_to_2026-10-20.pdf',
        canOpen: true,
      );

      expect(result.success, isTrue);
      expect(result.canOpen, isTrue);
      expect(result.destinationDisplay, contains('Downloads/'));
    });
  });
}
