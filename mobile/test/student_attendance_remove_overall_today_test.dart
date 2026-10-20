import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/models/student_model.dart';
import 'package:attendance_marker_mobile/widgets/attendance/daily_schedule_card.dart';

void main() {
  Widget buildWrapper({
    required Widget child,
    ThemeMode themeMode = ThemeMode.light,
    Size size = const Size(360, 800),
  }) {
    return MaterialApp(
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  group('Student Attendance Report - Remove Overall Today Verification', () {
    final mockEntry = DateWiseEntryModel(
      date: '2026-10-19',
      periods: [
        PeriodEntryModel(periodNumber: 1, status: 'PRESENT', subjectCode: 'FDS', subjectName: 'Foundations of Data Science'),
        PeriodEntryModel(periodNumber: 2, status: 'ABSENT', subjectCode: 'DMC', subjectName: 'Discrete Mathematics for Computing'),
        PeriodEntryModel(periodNumber: 3, status: 'NO_RECORD', subjectCode: 'FDS LAB', subjectName: 'Foundations of Data Science Laboratory'),
        PeriodEntryModel(periodNumber: 4, status: 'NO_RECORD', subjectCode: 'FDS LAB', subjectName: 'Foundations of Data Science Laboratory'),
        PeriodEntryModel(periodNumber: 5, status: 'NO_RECORD', subjectCode: 'DPCO', subjectName: 'Digital Principles & Computer Organization'),
        PeriodEntryModel(periodNumber: 6, status: 'NO_RECORD', subjectCode: 'OOPS', subjectName: 'Object Oriented Programming Systems'),
        PeriodEntryModel(periodNumber: 7, status: 'ABSENT', subjectCode: 'DS', subjectName: 'Data Structures'),
      ],
      dailyResult: 'PARTIAL',
    );

    testWidgets('DailyScheduleCard does NOT render Overall today or target 75% in Light Theme', (tester) async {
      await tester.pumpWidget(
        buildWrapper(
          themeMode: ThemeMode.light,
          child: DailyScheduleCard(
            entry: mockEntry,
            dateLabel: 'Mon, 19 Oct',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify "Overall today" is NOT rendered
      expect(find.text('Overall today'), findsNothing);

      // 2. Verify "target 75%" is NOT rendered
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('target 75%'),
        ),
        findsNothing,
      );

      // 3. Verify all period cards and statuses are PRESERVED
      expect(find.text('FDS'), findsOneWidget);
      expect(find.text('DMC'), findsWidgets);
      expect(find.text('FDS LAB'), findsWidgets);
      expect(find.text('DPCO'), findsOneWidget);
      expect(find.text('OOPS'), findsOneWidget);
      expect(find.text('DS'), findsOneWidget);

      expect(find.text('Present'), findsWidgets);
      expect(find.text('Absent'), findsWidgets);
      expect(find.text('No record'), findsWidgets);

      // 4. No overflow exceptions
      expect(tester.takeException(), isNull);
    });

    testWidgets('DailyScheduleCard does NOT render Overall today or target 75% in Dark Theme', (tester) async {
      await tester.pumpWidget(
        buildWrapper(
          themeMode: ThemeMode.dark,
          child: DailyScheduleCard(
            entry: mockEntry,
            dateLabel: 'Mon, 19 Oct',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "Overall today" is NOT rendered
      expect(find.text('Overall today'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('target 75%'),
        ),
        findsNothing,
      );

      // Verify periods remain present
      expect(find.text('FDS'), findsOneWidget);
      expect(find.text('DMC'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Reclaims vertical space cleanly without extra margins or blank space', (tester) async {
      await tester.pumpWidget(
        buildWrapper(
          child: Column(
            children: [
              DailyScheduleCard(
                entry: mockEntry,
                dateLabel: 'Mon, 19 Oct',
              ),
              const Text('NEXT_SECTION_MARKER'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NEXT_SECTION_MARKER'), findsOneWidget);
      expect(find.text('Overall today'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
