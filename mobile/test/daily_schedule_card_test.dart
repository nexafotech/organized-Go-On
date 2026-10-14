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
  });
}
