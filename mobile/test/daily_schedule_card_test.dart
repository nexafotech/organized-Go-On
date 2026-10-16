import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/models/student_model.dart';
import 'package:attendance_marker_mobile/widgets/attendance/daily_schedule_card.dart';

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

  group('DailyScheduleCard Widget Tests', () {
    testWidgets('Renders YOUR DAY card with all reference design elements', (WidgetTester tester) async {
      final mockEntry = DateWiseEntryModel(
        date: '2026-10-14',
        periods: [
          PeriodEntryModel(periodNumber: 1, status: 'ABSENT', subjectCode: '19IT501'),
          PeriodEntryModel(periodNumber: 2, status: 'ABSENT', subjectCode: '19IT502'),
          PeriodEntryModel(periodNumber: 3, status: 'ABSENT', subjectCode: '19IT503'),
          PeriodEntryModel(periodNumber: 4, status: 'ABSENT', subjectCode: '19IT504'),
          PeriodEntryModel(periodNumber: 5, status: 'ABSENT', subjectCode: '19IT505'),
          PeriodEntryModel(periodNumber: 6, status: 'ABSENT', subjectCode: '19IT506'),
          PeriodEntryModel(periodNumber: 7, status: 'ABSENT', subjectCode: '19IT507'),
        ],
        dailyResult: 'ABSENT',
      );

      await tester.pumpWidget(wrapWidget(
        DailyScheduleCard(
          entry: mockEntry,
          dateLabel: 'Wed, 14 Oct',
        ),
      ));
      await tester.pumpAndSettle();

      // Verify date and headline
      expect(find.text('Wed, 14 Oct'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('You missed 7 classes today.'),
        ),
        findsOneWidget,
      );
      expect(find.text('Schedule will update as classes proceed.'), findsOneWidget);

      // Verify YOUR DAY track header and period circles
      expect(find.text('YOUR DAY'), findsOneWidget);
      expect(find.text('08:45 AM'), findsWidgets);
      expect(find.text('04:20 PM'), findsOneWidget);
      expect(find.text('Absent'), findsWidgets);
      expect(find.text('No record'), findsWidgets);

      // Verify period numbers in circle track
      for (int i = 1; i <= 7; i++) {
        expect(find.text('$i'), findsWidgets);
      }

      // Verify featured card for period 1
      expect(find.text('19IT501'), findsOneWidget);
      expect(find.text('Design and Analysis of Algorithms'), findsOneWidget);

      // Verify 2-column other periods
      expect(find.text('19IT502'), findsOneWidget);
      expect(find.text('19IT503'), findsOneWidget);
      expect(find.text('19IT504'), findsOneWidget);

      // Verify overall today target bar
      expect(find.text('Overall today'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('target 75%'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Tapping period in grid updates the featured card', (WidgetTester tester) async {
      final mockEntry = DateWiseEntryModel(
        date: '2026-10-14',
        periods: [
          PeriodEntryModel(periodNumber: 1, status: 'ABSENT', subjectCode: '19IT501'),
          PeriodEntryModel(periodNumber: 2, status: 'PRESENT', subjectCode: '19IT502'),
          PeriodEntryModel(periodNumber: 3, status: 'ABSENT', subjectCode: '19IT503'),
          PeriodEntryModel(periodNumber: 4, status: 'ABSENT', subjectCode: '19IT504'),
          PeriodEntryModel(periodNumber: 5, status: 'ABSENT', subjectCode: '19IT505'),
          PeriodEntryModel(periodNumber: 6, status: 'ABSENT', subjectCode: '19IT506'),
          PeriodEntryModel(periodNumber: 7, status: 'ABSENT', subjectCode: '19IT507'),
        ],
        dailyResult: 'PARTIAL',
      );

      await tester.pumpWidget(wrapWidget(
        DailyScheduleCard(
          entry: mockEntry,
          dateLabel: 'Wed, 14 Oct',
        ),
      ));
      await tester.pumpAndSettle();

      // Tap on period 2 in the grid
      await tester.tap(find.text('19IT502'));
      await tester.pumpAndSettle();

      // Now period 2 should be featured
      expect(find.text('Period 2 • 09:40 AM'), findsOneWidget);
      expect(find.text('Present'), findsWidgets);
    });

    testWidgets('Resolves Monday true curriculum names and displays suitable colors with full legend', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Mock entry for Mon, 12 Oct with only Period 2 (Absent DMC) and Period 3 (Present FDS LAB) marked
      final mondayEntry = DateWiseEntryModel(
        date: '2026-10-12',
        periods: [
          PeriodEntryModel(periodNumber: 2, status: 'ABSENT', subjectCode: 'DMC', subjectName: 'Discrete Mathematics for Computing'),
          PeriodEntryModel(periodNumber: 3, status: 'PRESENT', subjectCode: 'FDS LAB', subjectName: 'Foundations of Data Science Laboratory'),
        ],
        dailyResult: 'PARTIAL',
      );

      await tester.pumpWidget(wrapWidget(
        DailyScheduleCard(
          entry: mondayEntry,
          dateLabel: 'Mon, 12 Oct 2026',
        ),
      ));
      await tester.pumpAndSettle();

      // 1. Verify headline
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('You missed 1 class today.'),
        ),
        findsOneWidget,
      );

      // 2. Verify all true subject codes for Monday exist (no 19IT placeholder codes)
      expect(find.text('FDS'), findsOneWidget); // Period 1
      expect(find.text('DMC'), findsWidgets); // Period 2
      expect(find.text('FDS LAB'), findsWidgets); // Period 3 & 4
      expect(find.text('DPCO'), findsOneWidget); // Period 5
      expect(find.text('OOPS'), findsOneWidget); // Period 6
      expect(find.text('DS'), findsOneWidget); // Period 7

      // Verify no fake IT codes
      expect(find.text('19IT501'), findsNothing);
      expect(find.text('19IT504'), findsNothing);
      expect(find.text('19IT505'), findsNothing);
      expect(find.text('19IT506'), findsNothing);
      expect(find.text('19IT507'), findsNothing);
      expect(find.text('Cloud Computing & DevOps'), findsNothing);

      // 3. Verify legend contains Present, Absent, and No record
      expect(find.text('Present'), findsWidgets);
      expect(find.text('Absent'), findsWidgets);
      expect(find.text('No record'), findsWidgets);

      // 4. Tap on Period 6 (OOPS) to make it featured
      await tester.tap(find.text('OOPS'));
      await tester.pumpAndSettle();

      expect(find.text('Object Oriented Programming Systems'), findsOneWidget);

      // 5. Tap on Period 3 (FDS LAB - Present)
      await tester.tap(find.text('FDS LAB').first);
      await tester.pumpAndSettle();

      expect(find.text('Foundations of Data Science Laboratory'), findsWidgets);
    });

    testWidgets('Unrecorded day renders canonical No Record pending state without fake absent records', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWidget(
        DailyScheduleCard(
          entry: null,
          dateLabel: 'Today • Thu, 15 Oct 2026',
          selectedDate: DateTime(2026, 10, 15),
        ),
      ));
      await tester.pumpAndSettle();

      // Verify headline does not say "You missed 7 classes"
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('No attendance recorded today.'),
        ),
        findsOneWidget,
      );
      expect(find.text('Schedule will update as classes proceed.'), findsOneWidget);

      // Verify bottom bar shows Pending target 75%
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Pending') && w.text.toPlainText().contains('target 75%'),
        ),
        findsOneWidget,
      );

      // Verify featured card and grid items are No record (Pending)
      expect(find.text('No record'), findsWidgets);
    });
  });
}
