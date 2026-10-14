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
  });
}
