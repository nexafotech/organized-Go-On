import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_attendance_entry_screen.dart';

class MockFacultyServiceForUnmarked extends ChangeNotifier
    implements FacultyService {
  FacultyAttendanceRosterResponse? mockRosterResponse;
  bool submitCalled = false;
  List<Map<String, dynamic>>? lastSubmittedRecords;

  @override
  Future<FacultyAttendanceRosterResponse> fetchAttendanceRoster(
      int timetableEntryId, String date) async {
    return mockRosterResponse ??
        FacultyAttendanceRosterResponse(
          timetableEntryId: timetableEntryId,
          date: date,
          dayOfWeek: 'Monday',
          periodId: 1,
          periodNumber: 1,
          periodName: 'Period 1',
          startTime: '09:00',
          endTime: '09:50',
          subjectCode: 'CS101',
          subjectName: 'Computer Science',
          classId: 1,
          className: 'III Year CSE - Class 1',
          facultyName: 'Dr. Test',
          status: 'AVAILABLE',
          canMark: true,
          alreadyMarked: false,
          roster: [
            StudentRosterItem(
              studentId: 1,
              rollNumber: '721025149001',
              fullName: 'Aarav Kumar',
              attendanceStatus: 'UNMARKED',
            ),
            StudentRosterItem(
              studentId: 2,
              rollNumber: '721025149002',
              fullName: 'Abishek A',
              attendanceStatus: 'UNMARKED',
            ),
            StudentRosterItem(
              studentId: 3,
              rollNumber: '721025149003',
              fullName: 'Deepika Sharma',
              attendanceStatus: 'UNMARKED',
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
    return {
      'message': 'Attendance submitted successfully.',
      'session_id': 101,
      'records_count': records.length,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget createEntryScreen(FacultyService service) {
  return MaterialApp(
    home: ChangeNotifierProvider<FacultyService>.value(
      value: service,
      child: const FacultyAttendanceEntryScreen(
        timetableEntryId: 100,
        date: '2026-10-05',
        dayOfWeek: 'Monday',
        periodName: 'Period 1',
        periodTime: '09:00 - 09:50',
        subjectCode: 'CS101',
        subjectName: 'Computer Science',
        className: 'III Year CSE - Class 1',
      ),
    ),
  );
}

void main() {
  group('Unmarked Attendance Entry Tests', () {
    testWidgets('1-5. New session starts with all students UNMARKED and counters correct (Total=3, P=0, A=0, OD=0, Unmarked=3)', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForUnmarked();
      await tester.pumpWidget(createEntryScreen(service));
      await tester.pumpAndSettle();

      // Verify header
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Absent'), findsOneWidget);
      expect(find.text('Unmarked'), findsOneWidget);
      expect(find.text('OD'), findsNWidgets(4)); // 1 counter + 3 row buttons

      // Verify counter numbers
      expect(find.text('3'), findsNWidgets(2)); // Total=3, Unmarked=3
      expect(find.text('0'), findsNWidgets(3)); // Present=0, Absent=0, OD=0

      // All 3 students rendered
      expect(find.text('Aarav Kumar'), findsOneWidget);
      expect(find.text('Abishek A'), findsOneWidget);
      expect(find.text('Deepika Sharma'), findsOneWidget);
    });

    testWidgets('6-10. Selecting Present, Absent, OD updates counters and student status dynamically', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForUnmarked();
      await tester.pumpWidget(createEntryScreen(service));
      await tester.pumpAndSettle();

      final pButtons = find.widgetWithText(InkWell, 'P');
      final aButtons = find.widgetWithText(InkWell, 'A');
      final odButtons = find.widgetWithText(InkWell, 'OD');

      // 6. Mark first student Present
      expect(pButtons, findsNWidgets(3));
      await tester.tap(pButtons.first);
      await tester.pumpAndSettle();

      // Present=1, Absent=0, OD=0, Unmarked=2
      expect(find.text('1'), findsOneWidget); // Present=1
      expect(find.text('2'), findsOneWidget); // Unmarked=2

      // 7. Mark second student Absent
      await tester.tap(aButtons.at(1));
      await tester.pumpAndSettle();

      // Present=1, Absent=1, OD=0, Unmarked=1
      expect(find.text('1'), findsNWidgets(3)); // Present=1, Absent=1, Unmarked=1

      // 8. Mark third student OD (opens dialog)
      await tester.tap(odButtons.at(2));
      await tester.pumpAndSettle();

      expect(find.text('Mark OD: Deepika Sharma'), findsOneWidget);
      await tester.tap(find.text('Confirm OD'));
      await tester.pumpAndSettle();

      // Present=1, Absent=1, OD=1, Unmarked=0
      expect(find.text('0'), findsOneWidget); // Unmarked=0
      expect(find.text('1'), findsNWidgets(3)); // Present=1, Absent=1, OD=1

      // 9. Change student 1 from Present to Absent
      await tester.tap(aButtons.first);
      await tester.pumpAndSettle();

      // Present=0, Absent=2, OD=1, Unmarked=0
      expect(find.text('2'), findsOneWidget); // Absent=2
      expect(find.text('1'), findsOneWidget); // OD=1

      // 10. Change student 1 from Absent to OD
      await tester.tap(odButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Mark OD: Aarav Kumar'), findsOneWidget);
      await tester.tap(find.text('Confirm OD'));
      await tester.pumpAndSettle();

      // Present=0, Absent=1, OD=2, Unmarked=0
      expect(find.text('2'), findsOneWidget); // OD=2
    });

    testWidgets('11. All Present bulk action explicitly marks all students Present', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForUnmarked();
      await tester.pumpWidget(createEntryScreen(service));
      await tester.pumpAndSettle();

      // Tap All Present
      await tester.tap(find.text('All Present'));
      await tester.pumpAndSettle();

      // Present=3, Absent=0, OD=0, Unmarked=0, Total=3
      expect(find.text('3'), findsNWidgets(2)); // Total=3, Present=3
      expect(find.text('0'), findsNWidgets(3)); // Absent=0, OD=0, Unmarked=0
    });

    testWidgets('12. All Absent bulk action explicitly marks all students Absent', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForUnmarked();
      await tester.pumpWidget(createEntryScreen(service));
      await tester.pumpAndSettle();

      // Tap All Absent
      await tester.tap(find.text('All Absent'));
      await tester.pumpAndSettle();

      // Present=0, Absent=3, OD=0, Unmarked=0, Total=3
      expect(find.text('3'), findsNWidgets(2)); // Total=3, Absent=3
      expect(find.text('0'), findsNWidgets(3)); // Present=0, OD=0, Unmarked=0
    });

    testWidgets('13. Search/filter preserves selected attendance status', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForUnmarked();
      await tester.pumpWidget(createEntryScreen(service));
      await tester.pumpAndSettle();

      // Search for 'Abishek'
      await tester.enterText(find.byType(TextField), 'Abishek');
      await tester.pumpAndSettle();

      expect(find.text('Abishek A'), findsOneWidget);
      expect(find.text('Aarav Kumar'), findsNothing);

      // Mark Abishek Present
      await tester.tap(find.text('P'));
      await tester.pumpAndSettle();

      // Clear search
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      expect(find.text('Aarav Kumar'), findsOneWidget);
      expect(find.text('Abishek A'), findsOneWidget);

      // Present count should still be 1
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // Unmarked=2
    });

    testWidgets('14. Case B: Existing saved attendance statuses are restored correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForUnmarked();
      service.mockRosterResponse = FacultyAttendanceRosterResponse(
        timetableEntryId: 100,
        date: '2026-10-05',
        dayOfWeek: 'Monday',
        periodId: 1,
        periodNumber: 1,
        periodName: 'Period 1',
        startTime: '09:00',
        endTime: '09:50',
        subjectCode: 'CS101',
        subjectName: 'Computer Science',
        classId: 1,
        className: 'III Year CSE - Class 1',
        facultyName: 'Dr. Test',
        status: 'ALREADY_MARKED',
        canMark: true,
        alreadyMarked: true,
        roster: [
          StudentRosterItem(
            studentId: 1,
            rollNumber: '721025149001',
            fullName: 'Aarav Kumar',
            attendanceStatus: 'PRESENT',
          ),
          StudentRosterItem(
            studentId: 2,
            rollNumber: '721025149002',
            fullName: 'Abishek A',
            attendanceStatus: 'ABSENT',
          ),
          StudentRosterItem(
            studentId: 3,
            rollNumber: '721025149003',
            fullName: 'Deepika Sharma',
            attendanceStatus: 'OD',
            odReason: 'Symposium',
          ),
        ],
      );

      await tester.pumpWidget(createEntryScreen(service));
      await tester.pumpAndSettle();

      // Saved statuses preserved: Present=1, Absent=1, OD=1, Unmarked=0
      expect(find.text('1'), findsNWidgets(3)); // Present=1, Absent=1, OD=1
      expect(find.text('0'), findsOneWidget); // Unmarked=0
      expect(find.text('OD: Symposium'), findsOneWidget);
    });

    testWidgets('15. Submission blocked with warning when unmarked students exist', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForUnmarked();
      await tester.pumpWidget(createEntryScreen(service));
      await tester.pumpAndSettle();

      // Tap Submit Attendance while all 3 are UNMARKED
      await tester.tap(find.text('Submit Attendance'));
      await tester.pumpAndSettle();

      // Service submit was NOT called
      expect(service.submitCalled, isFalse);

      // Warning snackbar shown
      expect(
        find.text('Cannot submit: 3 students remain unmarked. Please mark all students as Present, Absent, or OD.'),
        findsOneWidget,
      );
    });

    testWidgets('16. Submission succeeds when all students are marked and records contain no UNMARKED status', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForUnmarked();
      await tester.pumpWidget(createEntryScreen(service));
      await tester.pumpAndSettle();

      // Explicitly mark All Present
      await tester.tap(find.text('All Present'));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Submit Attendance'));
      await tester.pumpAndSettle();

      expect(service.submitCalled, isTrue);
      expect(service.lastSubmittedRecords?.length, 3);
      for (final rec in service.lastSubmittedRecords!) {
        expect(rec['status'], 'PRESENT');
        expect(rec['status'], isNot('UNMARKED'));
      }
    });
  });
}
