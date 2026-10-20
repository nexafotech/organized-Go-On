import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/models/student_model.dart';
import 'package:attendance_marker_mobile/services/student_service.dart';
import 'package:attendance_marker_mobile/student/screens/student_attendance_report_screen.dart';
import 'package:attendance_marker_mobile/widgets/attendance/attendance_summary_card.dart';
import 'package:attendance_marker_mobile/widgets/attendance/subject_detail_sheet.dart';

class MockStudentService extends StudentService {
  @override
  Future<void> fetchStudentSummary() async {}

  @override
  Future<void> fetchSubjects() async {}

  @override
  Future<void> fetchAttendanceReport() async {}

  @override
  Future<void> fetchTimetable() async {}
}

void main() {
  group('Student Overall Attendance UI Tests', () {
    testWidgets('AttendanceSummaryCard suppresses OK badge when title is OVERALL ATTENDANCE', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AttendanceSummaryCard(
              title: 'OVERALL ATTENDANCE',
              subtitle: 'Min Requirement: 75%',
              percentage: 85.0,
              total: 20,
              present: 17,
              absent: 3,
              od: 0,
              status: 'OK',
            ),
          ),
        ),
      );

      // Verify that Min Requirement is displayed
      expect(find.text('Min Requirement: 75%'), findsOneWidget);
      expect(find.text('OVERALL ATTENDANCE'), findsOneWidget);
      expect(find.text('85.0%'), findsOneWidget);

      // Verify that 'OK' badge is NOT rendered
      expect(find.text('OK'), findsNothing);
    });

    testWidgets('AttendanceSummaryCard renders warning badge if status is WARNING', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AttendanceSummaryCard(
              title: 'OVERALL ATTENDANCE',
              subtitle: 'Min Requirement: 75%',
              percentage: 65.0,
              total: 20,
              present: 13,
              absent: 7,
              od: 0,
              status: 'WARNING',
            ),
          ),
        ),
      );

      expect(find.text('WARNING'), findsOneWidget);
    });

    testWidgets('StudentAttendanceReportScreen overall attendance mode verifies period card UI', (tester) async {
      final mockService = MockStudentService();
      mockService.setMockData(
        summary: StudentSummaryModel(
          studentId: 1,
          fullName: 'Student User',
          registerNumber: 'REG123',
          isActive: true,
          total: 10,
          present: 9,
          absent: 1,
          od: 0,
          percentage: 90.0,
          attendanceStatus: 'OK',
          calculationMode: 'PERIOD',
          minimumRequired: 75.0,
          belowMinimum: false,
        ),
        subjects: [
          SubjectAttendanceModel(
            subjectId: 1,
            subjectCode: '23CS301',
            subjectName: 'Data Structures',
            total: 10,
            present: 9,
            absent: 1,
            od: 0,
            percentage: 90.0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<StudentService>.value(
            value: mockService,
            child: const Scaffold(
              body: StudentAttendanceReportScreen(showAppBar: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Overall Attendance mode
      final overallModeButton = find.text('Overall Attendance');
      expect(overallModeButton, findsOneWidget);
      await tester.tap(overallModeButton);
      await tester.pumpAndSettle();

      // 1. Check OK badge is NOT rendered on the Overall Attendance card
      expect(find.text('OK'), findsNothing);
      expect(find.text('Min Requirement: 75%'), findsOneWidget);

      // 2. Check period card contents: subject name, code, percentage
      expect(find.text('Data Structures'), findsOneWidget);
      expect(find.text('Code: 23CS301'), findsOneWidget);
      expect(find.text('90.0%'), findsNWidgets(2)); // Once in summary card, once in period card pill

      // 3. Check "Completed ✓" badge is NOT rendered
      expect(find.text('Completed ✓'), findsNothing);
      expect(find.textContaining('Completed'), findsNothing);

      // 4. Check "75% Min Target" is NOT rendered
      expect(find.text('75% Min Target'), findsNothing);

      // 5. Check milestone 0% and 100% are rendered
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      // 6. Tap on the subject card - verify NO pop-up or SubjectDetailSheet opens
      final subjectCard = find.text('Data Structures');
      await tester.tap(subjectCard);
      await tester.pumpAndSettle();

      expect(find.byType(SubjectDetailSheet), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
    });
  });
}
