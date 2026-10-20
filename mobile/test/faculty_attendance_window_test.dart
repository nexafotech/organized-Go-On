import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/core/network/api_client.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_attendance_screen.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_attendance_entry_screen.dart';

class MockFacultyServiceForAttendanceWindow extends ChangeNotifier
    implements FacultyService {
  AvailablePeriodsResponse? mockPeriodsResponse;
  FacultyAttendanceRosterResponse? mockRosterResponse;
  bool submitCalled = false;
  bool shouldFailSubmit = false;
  String? submitErrorMessage;
  List<Map<String, dynamic>>? lastSubmittedRecords;

  @override
  Future<AvailablePeriodsResponse> fetchAvailableAttendancePeriods() async {
    return mockPeriodsResponse ??
        AvailablePeriodsResponse(
          todayDate: '2026-09-29',
          todayDay: 'Tuesday',
          yesterdayDate: '2026-09-28',
          yesterdayDay: 'Monday',
          currentTime: '14:00',
          todayPeriods: [
            AvailablePeriodItem(
              timetableEntryId: 160,
              periodId: 2,
              periodNumber: 2,
              periodName: 'Period 2',
              startTime: '10:00',
              endTime: '10:50',
              subjectCode: 'AIML',
              subjectName: 'Artificial Intelligence & Machine Learning',
              classId: 2,
              className: 'III Year CSE Cyber Security - Class 2',
              date: '2026-09-29',
              dayOfWeek: 'Tuesday',
              facultyName: 'Dr. Shankar',
              status: 'AVAILABLE',
              canMark: true,
            ),
            AvailablePeriodItem(
              timetableEntryId: 164,
              periodId: 6,
              periodNumber: 6,
              periodName: 'Period 6',
              startTime: '14:30',
              endTime: '15:20',
              subjectCode: 'LP',
              subjectName: 'Language Processing',
              classId: 2,
              className: 'III Year CSE Cyber Security - Class 2',
              date: '2026-09-29',
              dayOfWeek: 'Tuesday',
              facultyName: 'Dr. Shankar',
              status: 'LOCKED',
              canMark: false,
              lockReason: 'Attendance opens at 2:30 PM',
            ),
            AvailablePeriodItem(
              timetableEntryId: 165,
              periodId: 7,
              periodNumber: 7,
              periodName: 'Period 7',
              startTime: '15:20',
              endTime: '16:10',
              subjectCode: 'E&I',
              subjectName: 'Electronics & Instrumentation',
              classId: 2,
              className: 'III Year CSE Cyber Security - Class 2',
              date: '2026-09-29',
              dayOfWeek: 'Tuesday',
              facultyName: 'Dr. Shankar',
              status: 'LOCKED',
              canMark: false,
              lockReason: 'Attendance opens at 3:20 PM',
            ),
          ],
          yesterdayPeriods: [
            AvailablePeriodItem(
              timetableEntryId: 152,
              periodId: 1,
              periodNumber: 1,
              periodName: 'Period 1',
              startTime: '09:10',
              endTime: '10:00',
              subjectCode: 'AIML',
              subjectName: 'Artificial Intelligence & Machine Learning',
              classId: 2,
              className: 'III Year CSE Cyber Security - Class 2',
              date: '2026-09-28',
              dayOfWeek: 'Monday',
              facultyName: 'Dr. Shankar',
              status: 'AVAILABLE',
              canMark: true,
            ),
            AvailablePeriodItem(
              timetableEntryId: 154,
              periodId: 3,
              periodNumber: 3,
              periodName: 'Period 3',
              startTime: '11:10',
              endTime: '12:00',
              subjectCode: 'SDBMS',
              subjectName: 'Secure Database Management Systems',
              classId: 2,
              className: 'III Year CSE Cyber Security - Class 2',
              date: '2026-09-28',
              dayOfWeek: 'Monday',
              facultyName: 'Dr. Shankar',
              status: 'ALREADY_MARKED',
              canMark: false,
              lockReason: 'Attendance has already been recorded for this period.',
            ),
          ],
        );
  }

  @override
  Future<FacultyAttendanceRosterResponse> fetchAttendanceRoster(
      int timetableEntryId, String date) async {
    return mockRosterResponse ??
        FacultyAttendanceRosterResponse(
          timetableEntryId: timetableEntryId,
          date: date,
          dayOfWeek: 'Tuesday',
          periodId: 2,
          periodNumber: 2,
          periodName: 'Period 2',
          startTime: '10:00',
          endTime: '10:50',
          subjectCode: 'AIML',
          subjectName: 'Artificial Intelligence & Machine Learning',
          classId: 2,
          className: 'III Year CSE Cyber Security - Class 2',
          facultyName: 'Dr. Shankar',
          status: 'AVAILABLE',
          canMark: true,
          alreadyMarked: false,
          roster: [
            StudentRosterItem(
              studentId: 101,
              rollNumber: '721023149001',
              fullName: 'Aarav Kumar',
              attendanceStatus: 'PRESENT',
            ),
            StudentRosterItem(
              studentId: 102,
              rollNumber: '721023149002',
              fullName: 'Deepika Sharma',
              attendanceStatus: 'PRESENT',
            ),
            StudentRosterItem(
              studentId: 103,
              rollNumber: '721023149003',
              fullName: 'Karthik Raja',
              attendanceStatus: 'PRESENT',
            ),
          ],
        );
  }

  @override
  Future<Map<String, dynamic>> submitAttendanceWindow({
    required int timetableEntryId,
    required String date,
    required List<Map<String, dynamic>> records,
  }) async {
    submitCalled = true;
    lastSubmittedRecords = records;
    if (shouldFailSubmit) {
      throw ApiException(400, submitErrorMessage ?? 'Submission failed');
    }
    return {
      'message': 'Attendance submitted successfully.',
      'session_id': 99,
      'records_count': records.length,
    };
  }

  // Unused interface methods
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Faculty Attendance Window UI Tests', () {
    testWidgets('Renders Today tab with completed period AVAILABLE and active/future LOCKED',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockService = MockFacultyServiceForAttendanceWindow();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<FacultyService>.value(
            value: mockService,
            child: const FacultyAttendanceScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & Notice
      expect(find.text("Today's Attendance Window"), findsOneWidget);
      expect(find.text("TODAY"), findsOneWidget);
      expect(find.text("YESTERDAY"), findsOneWidget);

      // Verify Completed Period (P2) is AVAILABLE with MARK ATTENDANCE button
      expect(find.text('P2'), findsOneWidget);
      expect(find.text('MARK ATTENDANCE'), findsOneWidget);

      // Verify Future Periods (P6 and P7) are LOCKED with lockReason
      expect(find.text('P6'), findsOneWidget);
      expect(
          find.text('Attendance opens at 2:30 PM'),
          findsOneWidget);

      // Verify Future Period (P7) is LOCKED with lockReason
      expect(find.text('P7'), findsOneWidget);
      expect(
          find.text('Attendance opens at 3:20 PM'),
          findsOneWidget);
    });

    testWidgets('Switches to Yesterday tab and renders yesterday scheduled periods',
        (tester) async {
      final mockService = MockFacultyServiceForAttendanceWindow();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<FacultyService>.value(
            value: mockService,
            child: const FacultyAttendanceScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap YESTERDAY tab
      await tester.tap(find.text('YESTERDAY'));
      await tester.pumpAndSettle();

      expect(find.text("Yesterday's Attendance Window"), findsOneWidget);

      // P1 is AVAILABLE with MARK ATTENDANCE
      expect(find.text('P1'), findsOneWidget);
      expect(find.text('MARK ATTENDANCE'), findsOneWidget);

      // P3 is ALREADY_MARKED with ATTENDANCE RECORDED
      expect(find.text('P3'), findsOneWidget);
      expect(find.text('ATTENDANCE RECORDED'), findsOneWidget);
    });

    testWidgets('Renders empty state when no periods scheduled', (tester) async {
      final mockService = MockFacultyServiceForAttendanceWindow();
      mockService.mockPeriodsResponse = AvailablePeriodsResponse(
        todayDate: '2026-09-27',
        todayDay: 'Sunday',
        yesterdayDate: '2026-09-26',
        yesterdayDay: 'Saturday',
        currentTime: '10:00',
        todayPeriods: [],
        yesterdayPeriods: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<FacultyService>.value(
            value: mockService,
            child: const FacultyAttendanceScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No scheduled classes.'), findsOneWidget);
      expect(
          find.text('There are no timetable slots scheduled for Sunday.'),
          findsOneWidget);
    });

    testWidgets('Attendance Entry Screen renders student roster with Present/Absent/OD toggles',
        (tester) async {
      final mockService = MockFacultyServiceForAttendanceWindow();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<FacultyService>.value(
            value: mockService,
            child: const FacultyAttendanceEntryScreen(
              timetableEntryId: 160,
              date: '2026-09-29',
              dayOfWeek: 'Tuesday',
              periodName: 'Period 2',
              periodTime: '10:00 - 10:50',
              subjectCode: 'AIML',
              subjectName: 'Artificial Intelligence & Machine Learning',
              className: 'III Year CSE Cyber Security - Class 2',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header info
      expect(find.text('Period 2'), findsOneWidget);
      expect(find.text('10:00 - 10:50'), findsOneWidget);
      expect(find.text('Aarav Kumar'), findsOneWidget);
      expect(find.text('Deepika Sharma'), findsOneWidget);
      expect(find.text('Karthik Raja'), findsOneWidget);

      // Stat counters
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('3'), findsNWidgets(2)); // Total=3, Present=3 initially

      // Quick action buttons
      expect(find.text('All Present'), findsOneWidget);
      expect(find.text('All Absent'), findsOneWidget);

      // Tap All Absent
      await tester.tap(find.text('All Absent'));
      await tester.pumpAndSettle();

      // Submit attendance
      await tester.tap(find.text('Submit Attendance'));
      await tester.pumpAndSettle();

      expect(mockService.submitCalled, isTrue);
      expect(mockService.lastSubmittedRecords?.length, 3);
      for (final r in mockService.lastSubmittedRecords!) {
        expect(r['status'], 'ABSENT');
      }
    });

    testWidgets('Attendance Entry Screen shows error snackbar when server rejects submission',
        (tester) async {
      final mockService = MockFacultyServiceForAttendanceWindow();
      mockService.shouldFailSubmit = true;
      mockService.submitErrorMessage =
          "Attendance isn't open yet. This period starts at 2:30 PM.";

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<FacultyService>.value(
            value: mockService,
            child: const FacultyAttendanceEntryScreen(
              timetableEntryId: 164,
              date: '2026-09-29',
              dayOfWeek: 'Tuesday',
              periodName: 'Period 6',
              periodTime: '14:30 - 15:20',
              subjectCode: 'LP',
              subjectName: 'Language Processing',
              className: 'III Year CSE Cyber Security - Class 2',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit Attendance'));
      await tester.pumpAndSettle();

      expect(
        find.text("Attendance isn't open yet. This period starts at 2:30 PM."),
        findsOneWidget,
      );
    });
  });
}
