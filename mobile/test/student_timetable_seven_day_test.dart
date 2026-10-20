import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/models/student_model.dart';
import 'package:attendance_marker_mobile/services/student_service.dart';
import 'package:attendance_marker_mobile/student/screens/student_timetable_screen.dart';

class MockStudentServiceForSevenDayTimetable extends ChangeNotifier implements StudentService {
  final List<TimetableItemModel> _timetable;

  MockStudentServiceForSevenDayTimetable(this._timetable);

  @override
  StudentSummaryModel? get summary => StudentSummaryModel(
        studentId: 201,
        fullName: 'Jane Doe',
        registerNumber: 'CS2024099',
        className: 'II Year CSE Cyber Security · Class 1',
        isActive: true,
        total: 100,
        present: 92,
        absent: 8,
        od: 0,
        percentage: 92.0,
        calculationMode: 'RECORD_BASED',
        attendanceStatus: 'OK',
        minimumRequired: 75.0,
        belowMinimum: false,
      );

  @override
  List<TimetableItemModel> get timetable => _timetable;

  @override
  List<SubjectAttendanceModel> get subjects => [];

  @override
  List<DateWiseEntryModel> get dateWise => [];

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> fetchStudentSummary() async {}
  @override
  Future<void> fetchSubjects() async {}
  @override
  Future<void> fetchTimetable() async {}
  @override
  Future<void> fetchAttendanceReport() async {}
  @override
  Future<void> fetchAttendanceReportFiltered({int? subjectId, String? startDate, String? endDate}) async {}
  @override
  Future<void> loadDashboardData() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final standardMonToSatSchedule = [
    TimetableItemModel(
      dayOfWeek: 'MONDAY',
      periodNumber: 1,
      periodName: 'Period 1',
      startTime: '08:45 AM',
      endTime: '09:40 AM',
      subjectCode: 'OOP',
      subjectName: 'Object Oriented Programming',
      facultyName: 'Dr. John',
      roomNo: 'Hall 302',
    ),
    TimetableItemModel(
      dayOfWeek: 'MONDAY',
      periodNumber: 2,
      periodName: 'Period 2',
      startTime: '09:40 AM',
      endTime: '10:35 AM',
      subjectCode: 'DMC',
      subjectName: 'Discrete Mathematics',
      facultyName: 'Dr. Princy',
      roomNo: 'Hall 301',
    ),
  ];

  final scheduleWithSundayClasses = [
    ...standardMonToSatSchedule,
    TimetableItemModel(
      dayOfWeek: 'SUNDAY',
      periodNumber: 1,
      periodName: 'Period 1',
      startTime: '08:45 AM',
      endTime: '09:40 AM',
      subjectCode: 'SEMINAR',
      subjectName: 'Cyber Security Special Seminar',
      facultyName: 'Prof. Alan Turing',
      roomNo: 'Auditorium 1',
    ),
  ];

  group('go-On 7-Day Student Timetable & Sunday Support Tests', () {
    testWidgets('Renders all 7 days (Mon through Sun) simultaneously in weekday strip', (WidgetTester tester) async {
      final service = MockStudentServiceForSevenDayTimetable(standardMonToSatSchedule);

      await tester.pumpWidget(
        ChangeNotifierProvider<StudentService>.value(
          value: service,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: StudentTimetableScreen(simulatedTime: null),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all 7 weekday pills exist
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
    });

    testWidgets('Tapping Sunday displays truthful "No classes scheduled for Sunday" message when empty', (WidgetTester tester) async {
      // Wednesday Oct 14, 2026
      final simulatedDate = DateTime(2026, 10, 14, 10, 0);
      final service = MockStudentServiceForSevenDayTimetable(standardMonToSatSchedule);

      await tester.pumpWidget(
        ChangeNotifierProvider<StudentService>.value(
          value: service,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: StudentTimetableScreen(simulatedTime: simulatedDate),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sunday
      await tester.tap(find.text('Sun'));
      await tester.pumpAndSettle();

      // Check empty state
      expect(find.text('No classes scheduled for Sunday'), findsOneWidget);
      expect(find.text('Weekend break · No academic periods configured for Sunday.'), findsOneWidget);
      expect(find.byIcon(Icons.weekend_rounded), findsOneWidget);
    });

    testWidgets('Sunday displays scheduled class periods when Sunday classes exist in timetable', (WidgetTester tester) async {
      // Sunday Oct 18, 2026
      final sunday = DateTime(2026, 10, 18, 9, 0);
      final service = MockStudentServiceForSevenDayTimetable(scheduleWithSundayClasses);

      await tester.pumpWidget(
        ChangeNotifierProvider<StudentService>.value(
          value: service,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: StudentTimetableScreen(simulatedTime: sunday),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sunday is selected automatically because today is Sunday
      expect(find.text('Cyber Security Special Seminar'), findsOneWidget);
      expect(find.text('Prof. Alan Turing · Auditorium 1'), findsOneWidget);
      expect(find.text('NOW · PERIOD 1'), findsOneWidget);
    });

    testWidgets('When today is Sunday, Sunday is initial selected day with today dot highlight', (WidgetTester tester) async {
      // Sunday Oct 18, 2026
      final sunday = DateTime(2026, 10, 18, 11, 0);
      final service = MockStudentServiceForSevenDayTimetable(standardMonToSatSchedule);

      await tester.pumpWidget(
        ChangeNotifierProvider<StudentService>.value(
          value: service,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: StudentTimetableScreen(simulatedTime: sunday),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sunday empty state rendered by default since today is Sunday
      expect(find.text('No classes scheduled for Sunday'), findsOneWidget);
      expect(find.text('Weekend break · No academic periods configured for Sunday.'), findsOneWidget);
    });

    testWidgets('Responsive Layout on Samsung Galaxy S24 (393x851) with 0 RenderFlex overflow', (WidgetTester tester) async {
      final service = MockStudentServiceForSevenDayTimetable(scheduleWithSundayClasses);

      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75; // S24 density -> ~393 x 851 dp
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider<StudentService>.value(
          value: service,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: StudentTimetableScreen(simulatedTime: DateTime(2026, 10, 14, 10, 0)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure all 7 days render without overflow
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Responsive Layout on compact 360dp width in Obsidian Dark Theme with 0 overflow', (WidgetTester tester) async {
      final service = MockStudentServiceForSevenDayTimetable(scheduleWithSundayClasses);

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0; // 360 x 800 dp
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider<StudentService>.value(
          value: service,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: StudentTimetableScreen(simulatedTime: DateTime(2026, 10, 18, 10, 0)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Weekly Matrix View includes all 7 days including Sunday', (WidgetTester tester) async {
      final service = MockStudentServiceForSevenDayTimetable(standardMonToSatSchedule);

      await tester.pumpWidget(
        ChangeNotifierProvider<StudentService>.value(
          value: service,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: StudentTimetableScreen(simulatedTime: DateTime(2026, 10, 14, 10, 0)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Toggle to Weekly Matrix View
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle();

      // Verify all 7 day headers appear in the matrix
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
    });
  });
}
