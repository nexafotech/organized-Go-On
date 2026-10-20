import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/faculty/widgets/faculty_calendar_theme.dart';

void main() {
  group('Faculty & Staff Calendar Neutral Gray Highlight Tests', () {
    testWidgets('Light Theme: selected date is neutral gray #E6E0D9 and in-range is lighter gray #EFE9E2', (tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: Text('Calendar Test'));
            },
          ),
        ),
      );

      final themedWidget = buildFacultyDatePickerTheme(
        capturedContext,
        const SizedBox(),
      ) as Theme;

      final themeData = themedWidget.data;
      final datePickerTheme = themeData.datePickerTheme;

      // Verify selected day background is neutral gray #E6E0D9
      final selectedDayBg = datePickerTheme.dayBackgroundColor?.resolve({WidgetState.selected});
      expect(selectedDayBg, equals(const Color(0xFFE6E0D9)));

      // Verify unselected day background is null (transparent)
      final unselectedDayBg = datePickerTheme.dayBackgroundColor?.resolve({});
      expect(unselectedDayBg, isNull);

      // Verify selected day text is readable dark espresso #22150F
      final selectedDayFg = datePickerTheme.dayForegroundColor?.resolve({WidgetState.selected});
      expect(selectedDayFg, equals(const Color(0xFF22150F)));

      // Verify in-range background is a lighter neutral gray
      expect(datePickerTheme.rangeSelectionBackgroundColor, equals(const Color(0xFFEFE9E2)));

      // Verify today border is distinct outline
      expect(datePickerTheme.todayBorder?.color, equals(const Color(0xFF75665A)));

      // Verify header colors match theme
      expect(datePickerTheme.rangePickerHeaderForegroundColor, equals(const Color(0xFF22150F)));
      expect(datePickerTheme.rangePickerHeaderBackgroundColor, equals(const Color(0xFFF6F1EA)));
    });

    testWidgets('Dark Theme: selected date is accessible slate gray #4A4856 and in-range is #594A4856', (tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: Text('Dark Calendar Test'));
            },
          ),
        ),
      );

      final themedWidget = buildFacultyDatePickerTheme(
        capturedContext,
        const SizedBox(),
      ) as Theme;

      final themeData = themedWidget.data;
      final datePickerTheme = themeData.datePickerTheme;

      // Verify selected day background in dark mode is slate gray #4A4856
      final selectedDayBg = datePickerTheme.dayBackgroundColor?.resolve({WidgetState.selected});
      expect(selectedDayBg, equals(const Color(0xFF4A4856)));

      // Verify selected day text is luminous pearl cream #F7F5EE
      final selectedDayFg = datePickerTheme.dayForegroundColor?.resolve({WidgetState.selected});
      expect(selectedDayFg, equals(const Color(0xFFF7F5EE)));

      // Verify in-range background in dark mode
      expect(datePickerTheme.rangeSelectionBackgroundColor, equals(const Color(0x594A4856)));

      // Verify today border in dark mode
      expect(datePickerTheme.todayBorder?.color, equals(const Color(0xFFC5BDD3)));

      // Verify header colors
      expect(datePickerTheme.rangePickerHeaderForegroundColor, equals(const Color(0xFFF7F5EE)));
      expect(datePickerTheme.rangePickerHeaderBackgroundColor, equals(const Color(0xFF0D0C13)));
    });

    testWidgets('showDateRangePicker renders cleanly with neutral gray theme and allows range selection', (tester) async {
      DateTimeRange? pickedRange;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    pickedRange = await showDateRangePicker(
                      context: context,
                      initialDateRange: DateTimeRange(
                        start: DateTime(2026, 10, 14),
                        end: DateTime(2026, 10, 20),
                      ),
                      firstDate: DateTime(2020, 1, 1),
                      lastDate: DateTime(2035, 12, 31),
                      builder: (ctx, child) => buildFacultyDatePickerTheme(ctx, child!),
                    );
                  },
                  child: const Text('Open Range Picker'),
                );
              },
            ),
          ),
        ),
      );

      // Open the range picker
      await tester.tap(find.text('Open Range Picker'));
      await tester.pumpAndSettle();

      // Range picker should be visible
      expect(find.text('Select range'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Tap Save button to confirm range selection
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(pickedRange, isNotNull);
      expect(pickedRange!.start, equals(DateTime(2026, 10, 14)));
      expect(pickedRange!.end, equals(DateTime(2026, 10, 20)));
    });

    testWidgets('showDatePicker renders single date picker with neutral gray theme and allows selection', (tester) async {
      DateTime? pickedDate;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime(2026, 10, 14),
                      firstDate: DateTime(2020, 1, 1),
                      lastDate: DateTime(2035, 12, 31),
                      builder: (ctx, child) => buildFacultyDatePickerTheme(ctx, child!),
                    );
                  },
                  child: const Text('Open Date Picker'),
                );
              },
            ),
          ),
        ),
      );

      // Open the single date picker
      await tester.tap(find.text('Open Date Picker'));
      await tester.pumpAndSettle();

      // Tap OK button to confirm selection
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(pickedDate, isNotNull);
      expect(pickedDate, equals(DateTime(2026, 10, 14)));
    });
  });
}
