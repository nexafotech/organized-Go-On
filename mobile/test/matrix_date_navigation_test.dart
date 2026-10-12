import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/models/user_model.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/models/faculty_report_model.dart';
import 'package:attendance_marker_mobile/services/auth_service.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_attendance_report_screen.dart';

class MockAuthServiceForMatrix extends ChangeNotifier implements AuthService {
  final UserModel _user = UserModel(
    id: 1,
    username: 'advisor',
    email: 'advisor@college.edu',
    role: 'FACULTY',
    isActive: true,
    fullName: 'Class Advisor Dr. Smith',
  );

  @override
  UserModel? get currentUser => _user;
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  bool get isAuthenticated => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFacultyServiceForMatrix extends ChangeNotifier implements FacultyService {
  String requestedDate = '2026-10-05';

  @override
  bool get isClassAdvisor => true;

  @override
  Future<FacultyAuthorizedReportOptionsModel> fetchReportAuthorizedOptions() async {
    return FacultyAuthorizedReportOptionsModel(
      facultyId: 1,
      facultyName: 'Dr. Smith',
      isClassAdvisor: true,
      attendanceStartDate: '2026-10-05',
      currentDate: '2026-10-05',
      advisedClass: AdvisedClassInfo(
        id: 4,
        name: 'II Year CSE Cyber Security - Class 1',
      ),
      classes: [
        AuthorizedClassOptionModel(
          id: 4,
          name: 'II Year CSE Cyber Security - Class 1',
          isAdvisorForClass: true,
          subjects: [],
        ),
      ],
    );
  }

  @override
  Future<FacultyDateMatrixModel> fetchDateMatrixReport({
    required int classId,
    required String date,
    int? subjectId,
  }) async {
    requestedDate = date;
    if (date == '2026-10-05') {
      // Date WITH attendance records
      return FacultyDateMatrixModel(
        classId: classId,
        className: 'II Year CSE Cyber Security - Class 1',
        isClassAdvisorScope: true,
        date: '2026-10-05',
        dayOfWeek: 'MONDAY',
        lunchInterval: '12:50 PM - 01:40 PM (Not Counted)',
        periods: [
          DateMatrixPeriodHeaderModel(
            periodNumber: 1,
            periodName: 'Period 1',
            startTime: '09:10',
            endTime: '10:00',
            status: 'MARKED',
            totalMarked: 64,
            presentCount: 60,
            absentCount: 4,
          ),
          DateMatrixPeriodHeaderModel(
            periodNumber: 2,
            periodName: 'Period 2',
            startTime: '10:00',
            endTime: '10:50',
            status: 'MARKED',
            totalMarked: 64,
            presentCount: 60,
            absentCount: 4,
          ),
        ],
        students: [
          DateMatrixStudentRowModel(
            studentId: 1,
            rollNumber: '721025149001',
            fullName: 'Aarav Patel',
            periodStatuses: {'1': 'PRESENT', '2': 'PRESENT'},
            morningStatus: 'PRESENT',
            afternoonStatus: 'PRESENT',
            dailyResult: 'FULL DAY PRESENT',
          ),
          DateMatrixStudentRowModel(
            studentId: 2,
            rollNumber: '721025149002',
            fullName: 'Abishek A',
            periodStatuses: {'1': 'ABSENT', '2': 'ABSENT'},
            morningStatus: 'ABSENT',
            afternoonStatus: 'ABSENT',
            dailyResult: 'FULL DAY ABSENT',
          ),
        ],
      );
    } else {
      // Date WITHOUT attendance records (e.g. 2026-10-01, 2026-10-02, future date)
      return FacultyDateMatrixModel(
        classId: classId,
        className: 'II Year CSE Cyber Security - Class 1',
        isClassAdvisorScope: true,
        date: date,
        dayOfWeek: 'THURSDAY',
        lunchInterval: '12:50 PM - 01:40 PM (Not Counted)',
        periods: [
          DateMatrixPeriodHeaderModel(
            periodNumber: 1,
            periodName: 'Period 1',
            startTime: '09:10',
            endTime: '10:00',
            status: 'PENDING',
            totalMarked: 0,
            presentCount: 0,
            absentCount: 0,
          ),
        ],
        students: [
          DateMatrixStudentRowModel(
            studentId: 1,
            rollNumber: '721025149001',
            fullName: 'Aarav Patel',
            periodStatuses: {'1': 'NOT_ENTERED'},
            morningStatus: 'NOT_ENTERED',
            afternoonStatus: 'NOT_ENTERED',
            dailyResult: 'NOT ENTERED',
          ),
        ],
      );
    }
  }

  @override
  Future<FacultyClassSummaryModel> fetchClassSummaryReport({
    required int classId,
    int? subjectId,
    String? startDate,
    String? endDate,
  }) async {
    return FacultyClassSummaryModel(
      classId: classId,
      className: 'II Year CSE Cyber Security - Class 1',
      totalPeriods: 0,
      present: 0,
      absent: 0,
      od: 0,
      percentage: 0.0,
      students: [],
    );
  }

  @override
  Future<FacultyHistoricalMatrixModel> fetchHistoricalMatrixReport({
    required int classId,
    int? subjectId,
    String? startDate,
    String? endDate,
  }) async {
    return FacultyHistoricalMatrixModel(
      classId: classId,
      className: 'II Year CSE Cyber Security - Class 1',
      attendanceStartDate: '2026-10-05',
      currentDate: '2026-10-05',
      startDate: startDate ?? '2026-10-01',
      endDate: endDate ?? '2026-10-05',
      totalDates: 0,
      dates: [],
      students: [],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockAuthServiceForMatrix mockAuthService;
  late MockFacultyServiceForMatrix mockFacultyService;

  setUp(() {
    mockAuthService = MockAuthServiceForMatrix();
    mockFacultyService = MockFacultyServiceForMatrix();
  });

  Widget buildTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<FacultyService>.value(value: mockFacultyService),
      ],
      child: const MaterialApp(
        home: FacultyAttendanceReportScreen(),
      ),
    );
  }

  group('Class Advisor Attendance Matrix Date Navigation', () {
    testWidgets('Date with records renders matrix table with students and periods', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Switch to Daily Matrix mode tab
      final matrixTabFinder = find.text('Daily Matrix');
      expect(matrixTabFinder, findsOneWidget);
      await tester.tap(matrixTabFinder);
      await tester.pumpAndSettle();

      // On 2026-10-05 (date with records)
      expect(find.text('Date: 2026-10-05'), findsOneWidget);
      expect(find.text('Change Date'), findsOneWidget);

      // Verify matrix table contents
      expect(find.text('Aarav Patel'), findsOneWidget);
      expect(find.text('Abishek A'), findsOneWidget);
      expect(find.text('721025149001'), findsOneWidget);
      expect(find.text('721025149002'), findsOneWidget);
      expect(find.text('FULL DAY PRESENT'), findsOneWidget);
      expect(find.text('FULL DAY ABSENT'), findsOneWidget);

      // Lunch break column is present and marked Not Counted
      expect(find.text('LUNCH\n(Not Counted)'), findsOneWidget);
      expect(find.text('LUNCH BREAK'), findsOneWidget);
    });

    testWidgets('Date without records renders semantic NO RECORDS AVAILABLE empty state', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Switch to Daily Matrix mode tab
      await tester.tap(find.text('Daily Matrix'));
      await tester.pumpAndSettle();

      // Tap Change Date to open date picker
      final changeDateFinder = find.text('Change Date');
      expect(changeDateFinder, findsOneWidget);
      await tester.tap(changeDateFinder);
      await tester.pumpAndSettle();

      // Date picker dialog is displayed
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // In the calendar dialog, October 1 is selectable
      final day1Finder = find.text('1');
      expect(day1Finder, findsWidgets);
      await tester.tap(day1Finder.first);
      await tester.pumpAndSettle();

      // Tap OK
      final okFinder = find.text('OK');
      expect(okFinder, findsOneWidget);
      await tester.tap(okFinder);
      await tester.pumpAndSettle();

      // Now date is 2026-10-01
      expect(find.text('Date: 2026-10-01'), findsOneWidget);

      // Verify the semantic empty state is rendered
      expect(find.text('NO RECORDS AVAILABLE'), findsOneWidget);
      expect(
        find.text('No attendance records are available for 2026-10-01. The class has no recorded attendance for this date.'),
        findsOneWidget,
      );

      // Verify it does NOT render false attendance values or student rows
      expect(find.text('FULL DAY PRESENT'), findsNothing);
      expect(find.text('Present: 0'), findsNothing);
      expect(find.text('Absent: 0'), findsNothing);
    });

    testWidgets('Summary tab renders NO RECORDS AVAILABLE when total periods is zero', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Mode 0: Summary Tab
      expect(find.text('NO RECORDS AVAILABLE'), findsOneWidget);
      expect(
        find.text('No attendance records are available for this class selection. The class has no recorded attendance.'),
        findsOneWidget,
      );

      // Must NOT display Present = 0, Absent = 0 stat badges
      expect(find.text('0.0% Avg'), findsNothing);
    });

    testWidgets('Historical tab renders NO RECORDS AVAILABLE when date range has no records', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Switch to Historical tab
      final histTabFinder = find.text('Historical');
      expect(histTabFinder, findsOneWidget);
      await tester.tap(histTabFinder);
      await tester.pumpAndSettle();

      // Historical tab shows NO RECORDS AVAILABLE empty state
      expect(find.text('NO RECORDS AVAILABLE'), findsOneWidget);
      expect(find.textContaining('No attendance records are available for'), findsOneWidget);
    });
  });
}
