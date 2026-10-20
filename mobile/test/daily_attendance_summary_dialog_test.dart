import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/widgets/attendance/daily_attendance_summary_metrics.dart';

void main() {
  final sampleSummary = ClassDailySummaryResponse(
    classId: 1,
    className: 'CSE - A',
    date: '2026-10-19',
    totalStudents: 55,
    fullDayPresentCount: 48,
    halfDayPresentCount: 3,
    fullDayAbsentCount: 2,
    odCount: 1,
    partialCount: 1,
    notEnteredCount: 0,
    lunchInterval: '12:50 PM - 01:40 PM (Not Counted)',
    students: [],
  );

  Widget buildTestableWidget({
    required Widget child,
    double width = 320,
    double height = 640,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, height)),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('DailyAttendanceSummaryMetrics Layout Tests', () {
    testWidgets('renders all 6 metrics on mobile without text collision or overflow', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          width: 300,
          child: DailyAttendanceSummaryMetrics(summary: sampleSummary),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all 6 labels are rendered
      expect(find.text('Full Day Present'), findsOneWidget);
      expect(find.text('Half-Day Present'), findsOneWidget);
      expect(find.text('Full Day Absent'), findsOneWidget);
      expect(find.text('On Duty (OD)'), findsOneWidget);
      expect(find.text('Partial / Mixed'), findsOneWidget);
      expect(find.text('Not Entered'), findsOneWidget);

      // Verify counts
      expect(find.text('48'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2)); // odCount=1, partialCount=1
      expect(find.text('0'), findsOneWidget);

      // Verify layout has 3 rows (2 items per row)
      final rows = find.descendant(
        of: find.byType(DailyAttendanceSummaryMetrics),
        matching: find.byType(Row),
      );
      expect(rows, findsNWidgets(3));

      // No overflow errors recorded
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders 3 columns (2 rows) on tablet/wide viewport (>= 460px)', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          width: 500,
          child: DailyAttendanceSummaryMetrics(summary: sampleSummary),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Full Day Present'), findsOneWidget);
      expect(find.text('Not Entered'), findsOneWidget);

      // Verify layout has 2 rows (3 items per row)
      final rows = find.descendant(
        of: find.byType(DailyAttendanceSummaryMetrics),
        matching: find.byType(Row),
      );
      expect(rows, findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders correctly in dark mode', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          width: 320,
          themeMode: ThemeMode.dark,
          child: DailyAttendanceSummaryMetrics(summary: sampleSummary),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Full Day Present'), findsOneWidget);
      expect(find.text('48'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('DailyAttendanceLunchBreakCard Tests', () {
    testWidgets('renders SizedBox.shrink without visible break text', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          width: 320,
          child: const DailyAttendanceLunchBreakCard(
            lunchInterval: '12:50 PM - 01:40 PM (Not Counted)',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Lunch Break'),
        findsNothing,
      );
    });
  });

  group('Full Dialog Integration Test', () {
    testWidgets('opens and displays dialog cleanly with no layout overflows on small screen', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: ctx,
                      builder: (dialogCtx) {
                        final colors = dialogCtx.colors;
                        final typography = dialogCtx.typography;
                        return AlertDialog(
                          backgroundColor: colors.surface,
                          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
                          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          title: Row(
                            children: [
                              Icon(Icons.verified_rounded, color: colors.present, size: 26),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Attendance Saved — Daily Summary',
                                  style: typography.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          content: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.sizeOf(dialogCtx).height * 0.75,
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Class: ${sampleSummary.className} | Date: ${sampleSummary.date}',
                                    style: typography.caption.copyWith(color: colors.textMuted),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: colors.surfaceMuted,
                                      borderRadius: AppRadius.mediumBorder,
                                      border: Border.all(color: colors.glassBorder),
                                    ),
                                    child: DailyAttendanceSummaryMetrics(summary: sampleSummary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          actions: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.primary,
                                  foregroundColor: colors.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                                ),
                                onPressed: () => Navigator.pop(dialogCtx),
                                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog is visible
      expect(find.text('Attendance Saved — Daily Summary'), findsOneWidget);
      expect(find.text('Class: CSE - A | Date: 2026-10-19'), findsOneWidget);
      expect(find.text('Full Day Present'), findsOneWidget);
      expect(find.textContaining('Lunch Break'), findsNothing);
      expect(find.text('OK'), findsOneWidget);

      // Verify no overflow error
      expect(tester.takeException(), isNull);

      // Tap OK to close
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Dialog closed
      expect(find.text('Attendance Saved — Daily Summary'), findsNothing);
    });
  });
}
