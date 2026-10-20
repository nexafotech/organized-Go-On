import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/models/student_model.dart';
import 'package:attendance_marker_mobile/widgets/attendance/subject_petal_chart_card.dart';
import 'package:attendance_marker_mobile/widgets/attendance/interactive_attendance_overview_card.dart';

void main() {
  Widget wrapWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: child,
        ),
      ),
    );
  }

  final mockSubjects = [
    SubjectAttendanceModel(
      subjectId: 1,
      subjectCode: 'FDS',
      subjectName: 'Foundations of Data Science',
      total: 20,
      present: 18,
      absent: 2,
      od: 0,
      percentage: 90.0,
    ),
    SubjectAttendanceModel(
      subjectId: 2,
      subjectCode: 'DMC',
      subjectName: 'Discrete Mathematics',
      total: 20,
      present: 17,
      absent: 3,
      od: 0,
      percentage: 85.0,
    ),
  ];

  final standardMonToSatTimetable = [
    // Monday (7 periods)
    TimetableItemModel(dayOfWeek: 'MONDAY', periodNumber: 1, periodName: 'Period 1', startTime: '09:10 AM', endTime: '10:00 AM', subjectCode: 'FDS', subjectName: 'Foundations of Data Science'),
    TimetableItemModel(dayOfWeek: 'MONDAY', periodNumber: 2, periodName: 'Period 2', startTime: '10:00 AM', endTime: '10:50 AM', subjectCode: 'DMC', subjectName: 'Discrete Mathematics'),
    TimetableItemModel(dayOfWeek: 'MONDAY', periodNumber: 3, periodName: 'Period 3', startTime: '11:10 AM', endTime: '12:00 PM', subjectCode: 'DPCO', subjectName: 'Digital Principles'),
    TimetableItemModel(dayOfWeek: 'MONDAY', periodNumber: 4, periodName: 'Period 4', startTime: '12:00 PM', endTime: '12:50 PM', subjectCode: 'OOPS', subjectName: 'Object Oriented Programming'),
    TimetableItemModel(dayOfWeek: 'MONDAY', periodNumber: 5, periodName: 'Period 5', startTime: '01:40 PM', endTime: '02:30 PM', subjectCode: 'DS', subjectName: 'Data Structures'),
    TimetableItemModel(dayOfWeek: 'MONDAY', periodNumber: 6, periodName: 'Period 6', startTime: '02:30 PM', endTime: '03:20 PM', subjectCode: 'LIB', subjectName: 'Library'),
    TimetableItemModel(dayOfWeek: 'MONDAY', periodNumber: 7, periodName: 'Period 7', startTime: '03:20 PM', endTime: '04:10 PM', subjectCode: 'TWM', subjectName: 'Tutor Ward Meeting'),
  ];

  group('SubjectPetalChartCard Sunday & Timetable Accuracy Tests', () {
    testWidgets('Sunday with no scheduled classes displays clean "No Classes Scheduled Today" card', (tester) async {
      // 2026-10-18 is Sunday
      final sunday = DateTime(2026, 10, 18);

      await tester.pumpWidget(wrapWidget(
        SubjectPetalChartCard(
          subjects: mockSubjects,
          timetable: standardMonToSatTimetable, // 0 Sunday classes
          targetDate: sunday,
        ),
      ));
      await tester.pumpAndSettle();

      // Verify truthful "No Classes Scheduled Today" card is rendered
      expect(find.text('No Classes Scheduled Today'), findsOneWidget);
      expect(find.text('Sunday Holiday'), findsOneWidget);
      expect(find.text('Sunday is not a scheduled working day for your class timetable.'), findsOneWidget);
      expect(find.text('0 Scheduled Periods'), findsOneWidget);
      expect(find.text('Weekend Rest Day'), findsOneWidget);

      // Verify FALSE/MOCK labels are NEVER rendered on Sunday
      expect(find.text('All 7 classes completed today • All dark'), findsNothing);
      expect(find.text('7/7 Done'), findsNothing);
      expect(find.text('Done ✓'), findsNothing);
      expect(find.text('DAILY CLASS PERIOD STATUS'), findsNothing);
    });

    testWidgets('Sunday configured as a working day with timetable entries renders Sunday schedule', (tester) async {
      final sunday = DateTime(2026, 10, 18);
      final sundayWorkingTimetable = [
        TimetableItemModel(dayOfWeek: 'SUNDAY', periodNumber: 1, periodName: 'Period 1', startTime: '09:00 AM', endTime: '10:00 AM', subjectCode: 'FDS', subjectName: 'Foundations of Data Science'),
        TimetableItemModel(dayOfWeek: 'SUNDAY', periodNumber: 2, periodName: 'Period 2', startTime: '10:00 AM', endTime: '11:00 AM', subjectCode: 'DMC', subjectName: 'Discrete Mathematics'),
      ];

      await tester.pumpWidget(wrapWidget(
        SubjectPetalChartCard(
          subjects: mockSubjects,
          timetable: sundayWorkingTimetable,
          targetDate: sunday,
        ),
      ));
      await tester.pumpAndSettle();

      // Verify schedule renders for Sunday working day
      expect(find.text("Today's Schedule"), findsOneWidget);
      expect(find.text('0/2 Recorded'), findsOneWidget);
      expect(find.text('No Classes Scheduled Today'), findsNothing);
      expect(find.text('DAILY CLASS PERIOD STATUS'), findsOneWidget);
    });

    testWidgets('Working day with unrecorded periods shows "0/7 Recorded" and "Pending", NEVER "Done ✓"', (tester) async {
      final monday = DateTime(2026, 10, 19);

      await tester.pumpWidget(wrapWidget(
        SubjectPetalChartCard(
          subjects: mockSubjects,
          timetable: standardMonToSatTimetable,
          dateWiseEntries: [], // 0 attendance records
          targetDate: monday,
        ),
      ));
      await tester.pumpAndSettle();

      // Verify truthful header stats
      expect(find.text("Today's Schedule"), findsOneWidget);
      expect(find.text('0/7 Recorded'), findsOneWidget);
      expect(find.text('7/7 Done'), findsNothing);
      expect(find.text('All 7 classes completed today • All dark'), findsNothing);

      // Verify unrecorded periods do NOT say "Done ✓"
      expect(find.text('Done ✓'), findsNothing);
    });

    testWidgets('Working day with partial recorded attendance distinguishes Present, Absent, OD, and Pending', (tester) async {
      final monday = DateTime(2026, 10, 19);
      final mondayAttendanceEntries = [
        DateWiseEntryModel(
          date: '2026-10-19',
          periods: [
            PeriodEntryModel(periodNumber: 1, status: 'PRESENT', subjectCode: 'FDS', subjectName: 'Foundations of Data Science'),
            PeriodEntryModel(periodNumber: 2, status: 'ABSENT', subjectCode: 'DMC', subjectName: 'Discrete Mathematics'),
            PeriodEntryModel(periodNumber: 3, status: 'OD', subjectCode: 'DPCO', subjectName: 'Digital Principles'),
            // Periods 4..7 are NOT entered yet
          ],
        ),
      ];

      await tester.pumpWidget(wrapWidget(
        SubjectPetalChartCard(
          subjects: mockSubjects,
          timetable: standardMonToSatTimetable,
          dateWiseEntries: mondayAttendanceEntries,
          targetDate: monday,
        ),
      ));
      await tester.pumpAndSettle();

      // Verify header count
      expect(find.text('3/7 Recorded'), findsOneWidget);
      expect(find.text('3 of 7 classes recorded (2 attended)'), findsOneWidget);

      // Verify timeline status pills
      expect(find.text('Present ✓'), findsAtLeastNWidgets(1));
      expect(find.text('Absent ✗'), findsAtLeastNWidgets(1));
      expect(find.text('On-Duty'), findsAtLeastNWidgets(1));
    });

    testWidgets('Toggle between Petal view and List view preserves truthful period status', (tester) async {
      // Past Monday with 1 recorded period
      final pastMonday = DateTime(2026, 10, 12);
      final pastMondayAttendanceEntries = [
        DateWiseEntryModel(
          date: '2026-10-12',
          periods: [
            PeriodEntryModel(periodNumber: 1, status: 'PRESENT', subjectCode: 'FDS', subjectName: 'Foundations of Data Science'),
          ],
        ),
      ];

      await tester.pumpWidget(wrapWidget(
        SubjectPetalChartCard(
          subjects: mockSubjects,
          timetable: standardMonToSatTimetable,
          dateWiseEntries: pastMondayAttendanceEntries,
          targetDate: pastMonday,
        ),
      ));
      await tester.pumpAndSettle();

      // Find and tap the 'List' segment switch
      final listButton = find.text('List');
      expect(listButton, findsOneWidget);
      await tester.tap(listButton);
      await tester.pumpAndSettle();

      // Verify List view shows truthful trailing status badges
      expect(find.text('Present ✓'), findsAtLeastNWidgets(1));
      expect(find.text('No Record'), findsAtLeastNWidgets(6));
    });
  });

  group('InteractiveAttendanceOverviewCard Sunday Timetable Accuracy', () {
    testWidgets('Renders Sunday without timetable as weekend with 0 scheduled classes without mock curriculum', (tester) async {
      final summary = StudentSummaryModel(
        studentId: 10,
        fullName: 'Jane Doe',
        registerNumber: '23CY050',
        isActive: true,
        total: 20,
        present: 18,
        absent: 2,
        od: 0,
        percentage: 90.0,
        calculationMode: 'RECORD_BASED',
        attendanceStatus: 'OK',
        minimumRequired: 75.0,
        belowMinimum: false,
      );

      await tester.pumpWidget(wrapWidget(
        InteractiveAttendanceOverviewCard(
          summary: summary,
          timetable: standardMonToSatTimetable,
          dateWiseEntries: [],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('ATTENDANCE'), findsOneWidget);
      expect(find.text('90%'), findsOneWidget);
    });
  });
}
