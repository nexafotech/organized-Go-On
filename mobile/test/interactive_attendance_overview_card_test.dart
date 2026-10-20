import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/models/student_model.dart';
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

  group('InteractiveAttendanceOverviewCard Center Percentage Tests', () {
    testWidgets('Renders actual total day present percentage in center puck instead of literal %', (tester) async {
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
        InteractiveAttendanceOverviewCard(summary: summary),
      ));
      await tester.pumpAndSettle();

      // Verify 90% is displayed in center puck
      expect(find.text('90%'), findsOneWidget);
      expect(find.text('ATTENDANCE'), findsOneWidget);
      expect(find.text('90.0%'), findsOneWidget); // Legend pill
      expect(find.text('Present (18 / 20)'), findsOneWidget);
    });

    testWidgets('Renders decimal percentage when present percentage has fractional value', (tester) async {
      final summary = StudentSummaryModel(
        studentId: 10,
        fullName: 'Jane Doe',
        registerNumber: '23CY050',
        isActive: true,
        total: 8,
        present: 7, // 7 / 8 = 87.5%
        absent: 1,
        od: 0,
        percentage: 87.5,
        calculationMode: 'RECORD_BASED',
        attendanceStatus: 'OK',
        minimumRequired: 75.0,
        belowMinimum: false,
      );

      await tester.pumpWidget(wrapWidget(
        InteractiveAttendanceOverviewCard(summary: summary),
      ));
      await tester.pumpAndSettle();

      // Verify decimal percentage 87.5% is displayed in center puck and in legend
      expect(find.text('87.5%'), findsNWidgets(2));
      expect(find.text('ATTENDANCE'), findsOneWidget);
      expect(find.text('Present (7 / 8)'), findsOneWidget);
    });

    testWidgets('Overall attendance graph never exceeds 100% when OD is counted as present', (tester) async {
      // Exactly reproducing the scenario from user screenshot:
      // Total: 13, Present: 10 (which includes 1 OD), purePresent: 9, Absent: 3, OD: 1, Percentage: 76.9%
      final summary = StudentSummaryModel(
        studentId: 101,
        fullName: 'Test Student',
        registerNumber: '23CS101',
        isActive: true,
        total: 13,
        present: 10,
        purePresent: 9,
        absent: 3,
        od: 1,
        percentage: 76.9,
        calculationMode: 'RECORD_BASED',
        attendanceStatus: 'OK',
        minimumRequired: 75.0,
        belowMinimum: false,
      );

      await tester.pumpWidget(wrapWidget(
        InteractiveAttendanceOverviewCard(summary: summary),
      ));
      await tester.pumpAndSettle();

      // Center puck displays overall attendance percentage (76.9% ATTENDANCE)
      expect(find.text('76.9%'), findsOneWidget);
      expect(find.text('ATTENDANCE'), findsOneWidget);

      // Mutually exclusive legend pills:
      // Pure Present: 9 / 13 = 69.2%
      // Absent: 3 / 13 = 23.1%
      // On-Duty: 1 / 13 = 7.7%
      expect(find.text('Present (9 / 13)'), findsOneWidget);
      expect(find.text('69.2%'), findsOneWidget);

      expect(find.text('Absent (3 / 13)'), findsOneWidget);
      expect(find.text('23.1%'), findsOneWidget);

      expect(find.text('On-Duty (1 / 13)'), findsOneWidget);
      expect(find.text('7.7%'), findsOneWidget);

      // Verify mathematical integrity:
      // Breakdown: 69.2% + 23.1% + 7.7% = 100.0% (NEVER 107.7%)
      // Counts: 9 + 3 + 1 = 13 == Total
      expect(find.text('Present (10 / 13)'), findsNothing);
    });

    testWidgets('Automatic fallback purePresentCount prevents double count even when purePresent is null', (tester) async {
      final summary = StudentSummaryModel.fromJson({
        'student_id': 102,
        'full_name': 'Fallback Student',
        'register_number': '23CS102',
        'is_active': true,
        'total': 13,
        'present': 10, // includes 1 OD
        'absent': 3,
        'od': 1,
        'percentage': 76.9,
        'calculation_mode': 'RECORD_BASED',
        'attendance_status': 'OK',
        'minimum_required': 75.0,
      });

      expect(summary.purePresentCount, equals(9));

      await tester.pumpWidget(wrapWidget(
        InteractiveAttendanceOverviewCard(summary: summary),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Present (9 / 13)'), findsOneWidget);
      expect(find.text('69.2%'), findsOneWidget);
      expect(find.text('Present (10 / 13)'), findsNothing);
    });
  });
}
