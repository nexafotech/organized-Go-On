import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/widgets/attendance/attendance_legend.dart';

void main() {
  Widget buildTestWidget({
    required Widget child,
    ThemeMode themeMode = ThemeMode.light,
    double width = 360,
  }) {
    return MaterialApp(
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 700)),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('Student Attendance Status Legend Simplification Tests', () {
    testWidgets('Student legend renders only P, A, and OD in Light Theme', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          themeMode: ThemeMode.light,
          child: const AttendanceLegend(isStudent: true),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Heading is present and NOT truncated
      expect(find.text('ATTENDANCE STATUS LEGEND'), findsOneWidget);

      // 2. Allowed three statuses are present
      expect(find.text('P'), findsOneWidget);
      expect(find.text('Present'), findsOneWidget);

      expect(find.text('A'), findsOneWidget);
      expect(find.text('Absent'), findsOneWidget);

      expect(find.text('OD'), findsOneWidget);
      expect(find.text('On Duty'), findsOneWidget);

      // 3. Removed items are NOT present
      expect(find.text('HD-P'), findsNothing);
      expect(find.text('Half Day Present'), findsNothing);

      expect(find.text('HD-A'), findsNothing);
      expect(find.text('Half Day Absent'), findsNothing);

      expect(find.text('L'), findsNothing);
      expect(find.text('Lunch Break'), findsNothing);

      expect(find.text('-'), findsNothing);
      expect(find.text('Not Entered'), findsNothing);

      expect(find.text('Academic Policy'), findsNothing);
      expect(find.textContaining('Policy: On Duty (OD)'), findsNothing);

      // 4. No overflow exceptions
      expect(tester.takeException(), isNull);
    });

    testWidgets('Student legend renders only P, A, and OD in Dark Theme', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          themeMode: ThemeMode.dark,
          child: const AttendanceLegend(isStudent: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ATTENDANCE STATUS LEGEND'), findsOneWidget);
      expect(find.text('P'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('OD'), findsOneWidget);

      expect(find.text('Academic Policy'), findsNothing);
      expect(find.text('Half Day Present'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Responsive wrapping on narrow 320px phone viewport with zero overflow', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          width: 320,
          child: const AttendanceLegend(isStudent: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ATTENDANCE STATUS LEGEND'), findsOneWidget);
      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Absent'), findsOneWidget);
      expect(find.text('On Duty'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Default / Faculty legend retains all statuses and policy info', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const AttendanceLegend(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ATTENDANCE STATUS LEGEND'), findsOneWidget);
      expect(find.text('Academic Policy'), findsOneWidget);
      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Absent'), findsOneWidget);
      expect(find.text('On Duty'), findsOneWidget);
      expect(find.text('Half Day Present'), findsOneWidget);
      expect(find.text('Half Day Absent'), findsOneWidget);
      expect(find.text('Lunch Break'), findsNothing);
      expect(find.text('Not Entered'), findsOneWidget);
      expect(find.textContaining('Policy: On Duty (OD)'), findsOneWidget);
    });
  });
}
