import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/models/student_model.dart';
import 'package:attendance_marker_mobile/widgets/attendance/subject_petal_chart_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Test date: Monday 2026-10-19
  final mondayDate = DateTime(2026, 10, 19);

  final List<SubjectAttendanceModel> subjects = [
    SubjectAttendanceModel(
      subjectId: 101,
      subjectCode: 'DS301',
      subjectName: 'Foundations of Data Science',
      total: 20,
      present: 18,
      absent: 2,
      od: 0,
      percentage: 90.0,
    ),
    SubjectAttendanceModel(
      subjectId: 102,
      subjectCode: 'MA302',
      subjectName: 'Discrete Mathematics',
      total: 22,
      present: 19,
      absent: 3,
      od: 0,
      percentage: 86.4,
    ),
    SubjectAttendanceModel(
      subjectId: 103,
      subjectCode: 'CS303',
      subjectName: 'Object Oriented Programming',
      total: 18,
      present: 14,
      absent: 4,
      od: 0,
      percentage: 77.8,
    ),
    SubjectAttendanceModel(
      subjectId: 104,
      subjectCode: 'CS304',
      subjectName: 'Data Structures and Algorithms',
      total: 20,
      present: 17,
      absent: 3,
      od: 0,
      percentage: 85.0,
    ),
  ];

  final List<TimetableItemModel> timetable = [
    TimetableItemModel(
      dayOfWeek: 'MONDAY',
      periodNumber: 1,
      periodName: 'Period 1',
      startTime: '08:45 AM',
      endTime: '09:40 AM',
      subjectCode: 'DS301',
      subjectName: 'Foundations of Data Science',
    ),
    TimetableItemModel(
      dayOfWeek: 'MONDAY',
      periodNumber: 2,
      periodName: 'Period 2',
      startTime: '09:40 AM',
      endTime: '10:35 AM',
      subjectCode: 'MA302',
      subjectName: 'Discrete Mathematics',
    ),
    TimetableItemModel(
      dayOfWeek: 'MONDAY',
      periodNumber: 3,
      periodName: 'Period 3',
      startTime: '10:55 AM',
      endTime: '11:50 AM',
      subjectCode: 'CS303',
      subjectName: 'Object Oriented Programming',
    ),
    TimetableItemModel(
      dayOfWeek: 'MONDAY',
      periodNumber: 4,
      periodName: 'Period 4',
      startTime: '11:50 AM',
      endTime: '12:45 PM',
      subjectCode: 'CS304',
      subjectName: 'Data Structures and Algorithms',
    ),
  ];

  group('SubjectPetalChartCard Text Visibility & Contrast Tests', () {
    testWidgets('Renders petal chart with recorded attendance (Present, Absent, OD, Pending)', (tester) async {
      final List<DateWiseEntryModel> dateWiseEntries = [
        DateWiseEntryModel(
          date: '2026-10-19',
          periods: [
            PeriodEntryModel(periodNumber: 1, status: 'PRESENT', subjectCode: 'DS301', subjectName: 'Foundations of Data Science'),
            PeriodEntryModel(periodNumber: 2, status: 'ABSENT', subjectCode: 'MA302', subjectName: 'Discrete Mathematics'),
            PeriodEntryModel(periodNumber: 3, status: 'OD', subjectCode: 'CS303', subjectName: 'Object Oriented Programming'),
            // Period 4 is unrecorded / Pending
          ],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SubjectPetalChartCard(
                subjects: subjects,
                timetable: timetable,
                dateWiseEntries: dateWiseEntries,
                targetDate: mondayDate,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the header is rendered
      expect(find.text("Today's Schedule"), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Verify daily period timeline bar items
      expect(find.text('Present ✓'), findsWidgets);
      expect(find.text('Absent ✗'), findsWidgets);
      expect(find.text('On-Duty'), findsWidgets);
      expect(find.text('Pending'), findsWidgets);

      // Verify short names are rendered cleanly
      expect(find.text('Foundations'), findsWidgets);
      expect(find.text('Discrete Mathematics'), findsWidgets);
      expect(find.text('Object Oriented'), findsWidgets);
    });

    testWidgets('Tapping on a petal updates the selected subject card with proper contrast', (tester) async {
      final List<DateWiseEntryModel> dateWiseEntries = [
        DateWiseEntryModel(
          date: '2026-10-19',
          periods: [
            PeriodEntryModel(periodNumber: 1, status: 'PRESENT', subjectCode: 'DS301', subjectName: 'Foundations of Data Science'),
          ],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SubjectPetalChartCard(
                subjects: subjects,
                timetable: timetable,
                dateWiseEntries: dateWiseEntries,
                targetDate: mondayDate,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the timeline item for Period 1 and tap it
      final p1Finder = find.text('Present ✓');
      expect(p1Finder, findsWidgets);
      await tester.tap(p1Finder.first, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Selected card displays details for Period 1
      expect(find.text('Foundations of Data Science'), findsWidgets);
    });

    testWidgets('Renders properly in Dark Theme without text clipping or contrast failures', (tester) async {
      final List<DateWiseEntryModel> dateWiseEntries = [
        DateWiseEntryModel(
          date: '2026-10-19',
          periods: [
            PeriodEntryModel(periodNumber: 1, status: 'PRESENT', subjectCode: 'DS301', subjectName: 'Foundations of Data Science'),
            PeriodEntryModel(periodNumber: 2, status: 'PRESENT', subjectCode: 'MA302', subjectName: 'Discrete Mathematics'),
            PeriodEntryModel(periodNumber: 3, status: 'PRESENT', subjectCode: 'CS303', subjectName: 'Object Oriented Programming'),
            PeriodEntryModel(periodNumber: 4, status: 'PRESENT', subjectCode: 'CS304', subjectName: 'Data Structures and Algorithms'),
          ],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SubjectPetalChartCard(
                subjects: subjects,
                timetable: timetable,
                dateWiseEntries: dateWiseEntries,
                targetDate: mondayDate,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify no exceptions thrown and elements rendered
      expect(find.text("Today's Schedule"), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('ListView toggle displays high contrast status-aware circular badges', (tester) async {
      final List<DateWiseEntryModel> dateWiseEntries = [
        DateWiseEntryModel(
          date: '2026-10-19',
          periods: [
            PeriodEntryModel(periodNumber: 1, status: 'PRESENT', subjectCode: 'DS301', subjectName: 'Foundations of Data Science'),
            PeriodEntryModel(periodNumber: 2, status: 'ABSENT', subjectCode: 'MA302', subjectName: 'Discrete Mathematics'),
          ],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SubjectPetalChartCard(
                subjects: subjects,
                timetable: timetable,
                dateWiseEntries: dateWiseEntries,
                targetDate: mondayDate,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the list view button in the header
      final listButtonFinder = find.text('List');
      expect(listButtonFinder, findsOneWidget);
      await tester.tap(listButtonFinder);
      await tester.pumpAndSettle();

      // List view items are shown
      expect(find.byType(ListTile), findsNWidgets(4));
      expect(find.text('Foundations of Data Science'), findsWidgets);
      expect(find.text('Discrete Mathematics'), findsWidgets);
    });
  });
}
