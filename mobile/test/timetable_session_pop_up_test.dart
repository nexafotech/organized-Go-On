import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/models/faculty_model.dart';
import 'package:attendance_marker_mobile/models/student_model.dart';
import 'package:attendance_marker_mobile/widgets/timetable/timetable_session_pop_up.dart';
import 'package:attendance_marker_mobile/widgets/timetable/weekly_matrix_timetable_view.dart';

void main() {
  group('TimetableSessionPopUp - Unit & Formatting Tests', () {
    test('formatTimeTo12h formats 24h and 12h times consistently', () {
      expect(TimetableSessionPopUp.formatTimeTo12h('09:10'), '09:10 AM');
      expect(TimetableSessionPopUp.formatTimeTo12h('09:10:00'), '09:10 AM');
      expect(TimetableSessionPopUp.formatTimeTo12h('9:10'), '09:10 AM');
      expect(TimetableSessionPopUp.formatTimeTo12h('10:00'), '10:00 AM');
      expect(TimetableSessionPopUp.formatTimeTo12h('12:00'), '12:00 PM');
      expect(TimetableSessionPopUp.formatTimeTo12h('12:50'), '12:50 PM');
      expect(TimetableSessionPopUp.formatTimeTo12h('13:40'), '01:40 PM');
      expect(TimetableSessionPopUp.formatTimeTo12h('16:20'), '04:20 PM');
      expect(TimetableSessionPopUp.formatTimeTo12h('00:00'), '12:00 AM');
      // Already 12h AM/PM
      expect(TimetableSessionPopUp.formatTimeTo12h('09:10 AM'), '09:10 AM');
      expect(TimetableSessionPopUp.formatTimeTo12h('9:10 AM'), '09:10 AM');
      expect(TimetableSessionPopUp.formatTimeTo12h('1:40 PM'), '01:40 PM');
      // Empty or null
      expect(TimetableSessionPopUp.formatTimeTo12h(null), '');
      expect(TimetableSessionPopUp.formatTimeTo12h(''), '');
    });

    test('formatPeriodTiming formats range or fallback', () {
      expect(
        TimetableSessionPopUp.formatPeriodTiming('09:10', '10:00'),
        '09:10 AM – 10:00 AM',
      );
      expect(
        TimetableSessionPopUp.formatPeriodTiming('09:10 AM', '10:00 AM'),
        '09:10 AM – 10:00 AM',
      );
      expect(
        TimetableSessionPopUp.formatPeriodTiming('13:40', '14:35'),
        '01:40 PM – 02:35 PM',
      );
      expect(
        TimetableSessionPopUp.formatPeriodTiming(null, null),
        'Time unavailable',
      );
      expect(
        TimetableSessionPopUp.formatPeriodTiming('', ''),
        'Time unavailable',
      );
      expect(
        TimetableSessionPopUp.formatPeriodTiming('09:10', null),
        '09:10 AM',
      );
      expect(
        TimetableSessionPopUp.formatPeriodTiming(null, '10:00'),
        '10:00 AM',
      );
    });

    test('formatFacultyName handles missing assignments safely', () {
      expect(TimetableSessionPopUp.formatFacultyName('Santhiya'), 'Santhiya');
      expect(TimetableSessionPopUp.formatFacultyName(' Dr. Ramesh '), 'Dr. Ramesh');
      expect(TimetableSessionPopUp.formatFacultyName(null), 'Faculty not assigned');
      expect(TimetableSessionPopUp.formatFacultyName(''), 'Faculty not assigned');
      expect(TimetableSessionPopUp.formatFacultyName('   '), 'Faculty not assigned');
      expect(TimetableSessionPopUp.formatFacultyName('null'), 'Faculty not assigned');
      expect(TimetableSessionPopUp.formatFacultyName('NULL'), 'Faculty not assigned');
    });
  });

  group('TimetableSessionPopUp - UI & Exclusions Verification', () {
    testWidgets('Pop-up displays ONLY faculty details and period timing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  TimetableSessionPopUp.show(
                    ctx,
                    facultyName: 'Santhiya',
                    startTime: '09:10',
                    endTime: '10:00',
                  );
                },
                child: const Text('Open PopUp'),
              ),
            ),
          ),
        ),
      );

      // Open Pop-up
      await tester.tap(find.text('Open PopUp'));
      await tester.pumpAndSettle();

      // 1. MUST BE DISPLAYED: Faculty & Time
      expect(find.text('FACULTY'), findsOneWidget);
      expect(find.text('Santhiya'), findsOneWidget);
      expect(find.text('TIME'), findsOneWidget);
      expect(find.text('09:10 AM – 10:00 AM'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.byKey(const Key('timetable_popup_close_icon')), findsOneWidget);

      // 2. MUST BE REMOVED: Subject name, Subject code, Venue, Period Type, Attendance Report button
      expect(find.text('Foundations of Data Science'), findsNothing);
      expect(find.text('FDS'), findsNothing);
      expect(find.text('VENUE'), findsNothing);
      expect(find.text('Lecture Hall'), findsNothing);
      expect(find.text('TIME SLOT'), findsNothing);
      expect(find.text('TYPE'), findsNothing);
      expect(find.text('CORE THEORY'), findsNothing);
      expect(find.text('Laboratory'), findsNothing);
      expect(find.text('Attendance Report'), findsNothing);
      expect(find.byIcon(Icons.analytics_outlined), findsNothing);

      // 3. Test Close action
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Verified Pop-up is dismissed
      expect(find.text('Santhiya'), findsNothing);
    });

    testWidgets('Pop-up displays fallback text when faculty and time are missing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  TimetableSessionPopUp.show(
                    ctx,
                    facultyName: null,
                    startTime: null,
                    endTime: null,
                  );
                },
                child: const Text('Open Empty PopUp'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Empty PopUp'));
      await tester.pumpAndSettle();

      expect(find.text('Faculty not assigned'), findsOneWidget);
      expect(find.text('Time unavailable'), findsOneWidget);

      // Close using X icon
      await tester.tap(find.byKey(const Key('timetable_popup_close_icon')));
      await tester.pumpAndSettle();

      expect(find.text('Faculty not assigned'), findsNothing);
    });

    testWidgets('Pop-up works seamlessly from TimetableItemModel and FacultyScheduleItem', (tester) async {
      final studentItem = TimetableItemModel(
        dayOfWeek: 'MONDAY',
        periodNumber: 1,
        startTime: '09:10',
        endTime: '10:00',
        facultyName: 'Dr. Showmiya',
        subjectName: 'Operating Systems',
        subjectCode: 'OS',
        roomNo: 'Lab 2',
      );

      final facultyItem = FacultyScheduleItem(
        id: 101,
        dayOfWeek: 'MONDAY',
        periodId: 1,
        periodNumber: 1,
        periodName: 'P1',
        startTime: '11:50',
        endTime: '12:45',
        assignmentId: 202,
        subjectCode: 'CS801',
        subjectName: 'Cyber Security',
        className: 'II Year CSE',
        facultyName: 'Lakshmi Narayanan',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () => TimetableSessionPopUp.showFromItem(ctx, studentItem),
                    child: const Text('Student Item'),
                  ),
                  ElevatedButton(
                    onPressed: () => TimetableSessionPopUp.showFromFacultySchedule(ctx, facultyItem),
                    child: const Text('Faculty Item'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Test Student Item
      await tester.tap(find.text('Student Item'));
      await tester.pumpAndSettle();
      expect(find.text('Dr. Showmiya'), findsOneWidget);
      expect(find.text('09:10 AM – 10:00 AM'), findsOneWidget);
      expect(find.text('Operating Systems'), findsNothing);
      expect(find.text('Lab 2'), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Test Faculty Item
      await tester.tap(find.text('Faculty Item'));
      await tester.pumpAndSettle();
      expect(find.text('Lakshmi Narayanan'), findsOneWidget);
      expect(find.text('11:50 AM – 12:45 PM'), findsOneWidget);
      expect(find.text('Cyber Security'), findsNothing);
      expect(find.text('II Year CSE'), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('WeeklyMatrixTimetableView taps trigger simplified pop-up', (tester) async {
      final items = [
        TimetableItemModel(
          dayOfWeek: 'MONDAY',
          periodNumber: 1,
          periodName: 'P1',
          startTime: '08:45 AM',
          endTime: '09:40 AM',
          subjectCode: 'FDS',
          subjectName: 'Foundations of Data Science',
          facultyName: 'Santhiya',
        ),
      ];

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: WeeklyMatrixTimetableView(
              items: items,
              simulatedTime: DateTime(2026, 10, 19, 10, 0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap FDS card in Weekly Matrix
      expect(find.text('FDS'), findsOneWidget);
      await tester.tap(find.text('FDS'));
      await tester.pumpAndSettle();

      // Verify Simplified Pop-up opens
      expect(find.text('FACULTY'), findsOneWidget);
      expect(find.text('Santhiya'), findsOneWidget);
      expect(find.text('TIME'), findsOneWidget);
      expect(find.text('08:45 AM – 09:40 AM'), findsOneWidget);
      expect(find.text('Foundations of Data Science'), findsNothing);
      expect(find.text('Attendance Report'), findsNothing);

      // Dismiss pop-up
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Santhiya'), findsNothing);
    });
  });
}
