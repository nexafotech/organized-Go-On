import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/widgets/widgets.dart';

void main() {
  Widget wrapWithTheme(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );
  }

  group('Phase 2 Shared Components Tests', () {
    testWidgets('AppHeader and AppScaffold render title, subtitle and role chip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AppScaffold(
            header: const AppHeader(
              title: 'Dashboard',
              subtitle: 'Welcome back',
              roleChip: 'STUDENT',
            ),
            body: const Text('Scaffold Content'),
          ),
        ),
      );

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('STUDENT'), findsOneWidget);
      expect(find.text('Scaffold Content'), findsOneWidget);
    });

    testWidgets('HeroCard renders title, subtitle, and responds to taps', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        wrapWithTheme(
          HeroCard(
            greeting: 'Good morning',
            title: 'Dr. Shankar',
            subtitle: 'Associate Professor',
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Good morning'), findsOneWidget);
      expect(find.text('Dr. Shankar'), findsOneWidget);
      expect(find.text('Associate Professor'), findsOneWidget);

      await tester.tap(find.text('Dr. Shankar'));
      expect(tapped, isTrue);
    });

    testWidgets('GlassCard, SectionHeader, and StatCard render accurately', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          Column(
            children: [
              SectionHeader(
                title: 'Overview',
                subtitle: 'Key statistics',
                action: const Text('Action'),
              ),
              const StatCard(
                label: 'Present Days',
                value: '68',
                subtitle: 'Out of 72 working days',
                icon: Icons.check_circle_outline_rounded,
              ),
              const GlassCard(
                child: Text('Card Content'),
              ),
            ],
          ),
        ),
      );

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Key statistics'), findsOneWidget);
      expect(find.text('Action'), findsOneWidget);
      expect(find.text('PRESENT DAYS'), findsOneWidget);
      expect(find.text('68'), findsOneWidget);
      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('AttendanceGauge renders percentage and status text', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const AttendanceGauge(
            percentage: 88.5,
            animate: false,
          ),
        ),
      );

      expect(find.text('88.5%'), findsOneWidget);
      expect(find.text('ATTENDANCE'), findsOneWidget);
      expect(find.text('On track'), findsOneWidget);
    });

    testWidgets('AttendanceStatusChip renders codes, labels, and icons correctly', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          Column(
            children: const [
              AttendanceStatusChip(status: 'PRESENT', showLabel: true),
              AttendanceStatusChip(status: 'ABSENT', showLabel: false),
              AttendanceStatusChip(status: 'OD', odReason: 'Symposium', showLabel: true),
              AttendanceStatusChip(status: 'LUNCH', showLabel: true),
              AttendanceStatusChip(status: 'BREAK', showLabel: true),
            ],
          ),
        ),
      );

      expect(find.text('Present'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('OD (Symposium)'), findsOneWidget);
      expect(find.text('LUNCH'), findsOneWidget);
      expect(find.text('SHORT BREAK'), findsOneWidget);
    });

    testWidgets('PeriodCard renders period info and distinct lunch/break states', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          Column(
            children: const [
              PeriodCard(
                periodNumber: 'P1',
                time: '09:10 - 10:00',
                subject: 'Network Security',
                faculty: 'Dr. Shankar',
                state: PeriodCardState.current,
              ),
              PeriodCard(
                periodNumber: 'L',
                time: '12:50 - 13:40',
                subject: 'Lunch',
                state: PeriodCardState.lunch,
              ),
            ],
          ),
        ),
      );

      expect(find.text('P1'), findsOneWidget);
      expect(find.text('Network Security'), findsOneWidget);
      expect(find.text('Dr. Shankar'), findsOneWidget);
      expect(find.text('NOW'), findsOneWidget);
      expect(find.text('LUNCH BREAK (Strictly Excluded)'), findsOneWidget);
    });

    testWidgets('StudentRow and AttendanceRow render and handle marking interactions', (tester) async {
      String selectedStatus = 'PRESENT';

      await tester.pumpWidget(
        wrapWithTheme(
          StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  const StudentRow(
                    rollNumber: '721025149001',
                    fullName: 'Aravind Kumar',
                  ),
                  AttendanceRow(
                    rollNumber: '721025149002',
                    fullName: 'Abishek A',
                    currentStatus: selectedStatus,
                    onStatusChanged: (newStatus) {
                      setState(() => selectedStatus = newStatus);
                    },
                  ),
                ],
              );
            },
          ),
        ),
      );

      expect(find.text('Aravind Kumar'), findsOneWidget);
      expect(find.text('721025149001'), findsOneWidget);
      expect(find.text('Abishek A'), findsOneWidget);
      expect(find.text('721025149002'), findsOneWidget);

      // Tap Absent 'A' button on AttendanceRow
      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();
      expect(selectedStatus, equals('ABSENT'));
    });

    testWidgets('ReportMatrix primitives render header, data cells, and lunch separator', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          MatrixRowContainer(
            fixedIdentityCell: const SizedBox(
              width: 100,
              child: Text('Student 1'),
            ),
            periodCells: const [
              MatrixHeaderCell(text: 'P1'),
              MatrixDataCell(status: 'P'),
              MatrixLunchBand(),
              MatrixDataCell(status: 'A'),
            ],
          ),
        ),
      );

      expect(find.text('Student 1'), findsOneWidget);
      expect(find.text('P1'), findsOneWidget);
      expect(find.text('P'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
    });

    testWidgets('SearchField and AppFilterChip handle text entry and selection', (tester) async {
      String query = '';
      bool filterSelected = false;

      await tester.pumpWidget(
        wrapWithTheme(
          StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  SearchField(
                    hintText: 'Search roster...',
                    onChanged: (val) => query = val,
                  ),
                  AppFilterChip(
                    label: 'Absentees',
                    isSelected: filterSelected,
                    onSelected: (val) {
                      setState(() => filterSelected = val);
                    },
                  ),
                ],
              );
            },
          ),
        ),
      );

      expect(find.text('Search roster...'), findsOneWidget);
      expect(find.text('Absentees'), findsOneWidget);

      // Enter search query
      await tester.enterText(find.byType(TextField), 'John');
      expect(query, equals('John'));

      // Tap filter chip
      await tester.tap(find.text('Absentees'));
      await tester.pumpAndSettle();
      expect(filterSelected, isTrue);
    });

    testWidgets('PrimaryButton and SecondaryButton render and trigger callbacks', (tester) async {
      bool primaryPressed = false;
      bool secondaryPressed = false;

      await tester.pumpWidget(
        wrapWithTheme(
          Column(
            children: [
              PrimaryButton(
                text: 'Save Attendance',
                icon: Icons.check_rounded,
                onPressed: () => primaryPressed = true,
              ),
              SecondaryButton(
                text: 'Cancel',
                onPressed: () => secondaryPressed = true,
              ),
            ],
          ),
        ),
      );

      expect(find.text('Save Attendance'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Save Attendance'));
      expect(primaryPressed, isTrue);

      await tester.tap(find.text('Cancel'));
      expect(secondaryPressed, isTrue);
    });

    testWidgets('FloatingNavigation renders 4 tabs and handles tab switching', (tester) async {
      int activeTab = 0;

      await tester.pumpWidget(
        wrapWithTheme(
          StatefulBuilder(
            builder: (context, setState) {
              return FloatingNavigation(
                currentIndex: activeTab,
                onTap: (idx) => setState(() => activeTab = idx),
                items: const [
                  FloatingNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
                  FloatingNavItem(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today_rounded, label: 'Attendance'),
                  FloatingNavItem(icon: Icons.schedule_outlined, activeIcon: Icons.schedule_rounded, label: 'Timetable'),
                  FloatingNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
                ],
              );
            },
          ),
        ),
      );

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Timetable'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();
      expect(activeTab, equals(2));
    });

    testWidgets('StateViews (Loading, Empty, Error, Success) render appropriately', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        wrapWithTheme(
          SingleChildScrollView(
            child: Column(
              children: [
                const LoadingSkeleton.card(height: 60),
                const EmptyState(
                  title: 'No Sessions',
                  message: 'No active sessions found for today.',
                ),
                ErrorState(
                  title: 'Connection Lost',
                  message: 'Failed to contact backend service.',
                  onRetry: () => retried = true,
                ),
                const SuccessState(
                  title: 'Attendance Saved',
                  message: 'Roster saved with 64 records.',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('No Sessions'), findsOneWidget);
      expect(find.text('No active sessions found for today.'), findsOneWidget);
      expect(find.text('Connection Lost'), findsOneWidget);
      expect(find.text('Failed to contact backend service.'), findsOneWidget);
      expect(find.text('Attendance Saved'), findsOneWidget);
      expect(find.text('Roster saved with 64 records.'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });
  });
}
