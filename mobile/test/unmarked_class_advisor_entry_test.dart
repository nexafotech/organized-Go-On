import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_class_advisor_entry_screen.dart';

class MockFacultyServiceForAdvisorUnmarked extends ChangeNotifier
    implements FacultyService {
  ClassAdvisorAttendanceRosterResponse? mockAdvisorRoster;
  bool submitCalled = false;
  List<Map<String, dynamic>>? lastSubmittedRecords;

  @override
  Future<ClassAdvisorAttendanceRosterResponse> fetchClassAdvisorRoster(
      int timetableEntryId, String date) async {
    return mockAdvisorRoster ??
        ClassAdvisorAttendanceRosterResponse(
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
          subjectFacultyName: 'Dr. Subject Faculty',
          status: 'AVAILABLE',
          canMark: true,
          alreadyMarked: false,
          lastUpdatedAt: null,
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
          ],
        );
  }

  @override
  Future<ClassAdvisorAttendanceSubmitResponse> submitClassAdvisorAttendance({
    required int timetableEntryId,
    required String date,
    required List<Map<String, dynamic>> records,
    String? expectedLastUpdated,
  }) async {
    submitCalled = true;
    lastSubmittedRecords = records;
    return ClassAdvisorAttendanceSubmitResponse(
      message: 'Attendance saved successfully.',
      sessionId: 102,
      date: date,
      periodNumber: 1,
      recordsCount: records.length,
      status: 'COMPLETED',
      dailySummary: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget createAdvisorScreen(FacultyService service) {
  return MaterialApp(
    home: ChangeNotifierProvider<FacultyService>.value(
      value: service,
      child: const FacultyClassAdvisorEntryScreen(
        timetableEntryId: 100,
        date: '2026-10-05',
        dayOfWeek: 'Monday',
        periodName: 'Period 1',
        periodNumber: 1,
        periodTime: '09:00 - 09:50',
        subjectCode: 'CS101',
        subjectName: 'Computer Science',
        className: 'III Year CSE - Class 1',
        subjectFacultyName: 'Dr. Subject Faculty',
      ),
    ),
  );
}

void main() {
  group('Class Advisor Unmarked Attendance Entry Tests', () {
    testWidgets('Advisor screen starts with all students UNMARKED and counter bar shows UNMARKED=2, P=0, A=0, OD=0', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForAdvisorUnmarked();
      await tester.pumpWidget(createAdvisorScreen(service));
      await tester.pumpAndSettle();

      expect(find.text('TOTAL'), findsOneWidget);
      expect(find.text('PRESENT'), findsOneWidget);
      expect(find.text('ABSENT'), findsOneWidget);
      expect(find.text('OD'), findsNWidgets(3)); // 1 counter chip + 2 row buttons
      expect(find.text('UNMARKED'), findsOneWidget);

      expect(find.text('2'), findsNWidgets(2)); // TOTAL=2, UNMARKED=2
      expect(find.text('0'), findsNWidgets(3)); // PRESENT=0, ABSENT=0, OD=0
    });

    testWidgets('Advisor screen blocks submission when students are UNMARKED', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForAdvisorUnmarked();
      await tester.pumpWidget(createAdvisorScreen(service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SAVE ATTENDANCE AS CLASS ADVISOR'));
      await tester.pumpAndSettle();

      expect(service.submitCalled, isFalse);
      expect(
        find.text('Cannot submit: 2 students remain unmarked. Please mark all students before saving.'),
        findsOneWidget,
      );
    });

    testWidgets('Advisor screen marks All Present and submits successfully', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockFacultyServiceForAdvisorUnmarked();
      await tester.pumpWidget(createAdvisorScreen(service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('All Present'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SAVE ATTENDANCE AS CLASS ADVISOR'));
      await tester.pumpAndSettle();

      expect(service.submitCalled, isTrue);
      expect(service.lastSubmittedRecords?.length, 2);
      for (final r in service.lastSubmittedRecords!) {
        expect(r['status'], 'PRESENT');
      }
    });
  });
}
