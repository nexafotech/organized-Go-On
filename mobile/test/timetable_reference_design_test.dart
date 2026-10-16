import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/models/student_model.dart';
import 'package:attendance_marker_mobile/services/student_service.dart';
import 'package:attendance_marker_mobile/student/screens/student_timetable_screen.dart';

class MockStudentServiceForRefDesign extends ChangeNotifier implements StudentService {
  final List<TimetableItemModel> _timetable;

  MockStudentServiceForRefDesign(this._timetable);

  @override
  StudentSummaryModel? get summary => StudentSummaryModel(
        studentId: 101,
        fullName: 'Alex Student',
        registerNumber: 'CS2021001',
        className: 'II Year CSE Cyber Security · Class 1',
        isActive: true,
        total: 100,
        present: 85,
        absent: 15,
        od: 0,
        percentage: 85.0,
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
  group('Timetable Reference Design Tests (Image 2)', () {
    testWidgets('Renders exact reference design elements from Image 2', (WidgetTester tester) async {
      // 7 Periods matching the exact schedule in Image 2
      final schedule = [
        TimetableItemModel(
          dayOfWeek: 'WEDNESDAY',
          periodNumber: 1,
          periodName: 'Period 1',
          startTime: '08:45 AM',
          endTime: '09:40 AM',
          subjectCode: 'OOP',
          subjectName: 'Object Oriented Programming Systems',
          facultyName: 'Dr. John',
          roomNo: 'Hall 302',
        ),
        TimetableItemModel(
          dayOfWeek: 'WEDNESDAY',
          periodNumber: 2,
          periodName: 'Period 2',
          startTime: '09:40 AM',
          endTime: '10:35 AM',
          subjectCode: 'DMC',
          subjectName: 'Discrete Mathematics for Computing',
          facultyName: 'Princy',
          roomNo: 'Hall 301',
        ),
        TimetableItemModel(
          dayOfWeek: 'WEDNESDAY',
          periodNumber: 3,
          periodName: 'Period 3',
          startTime: '10:55 AM',
          endTime: '11:50 AM',
          subjectCode: 'DPCO',
          subjectName: 'Digital Principles & Computer Organization',
          facultyName: 'Lakshmi Narayanan',
          roomNo: 'Hall 301',
        ),
        TimetableItemModel(
          dayOfWeek: 'WEDNESDAY',
          periodNumber: 4,
          periodName: 'Period 4',
          startTime: '11:50 AM',
          endTime: '12:45 PM',
          subjectCode: 'DS',
          subjectName: 'Data Structures',
          facultyName: 'Showmiya',
          roomNo: 'Hall 301',
        ),
        TimetableItemModel(
          dayOfWeek: 'WEDNESDAY',
          periodNumber: 5,
          periodName: 'Period 5',
          startTime: '01:45 PM',
          endTime: '02:40 PM',
          subjectCode: 'ACE-I',
          subjectName: 'Aptitude & Communication Enhancement I',
          facultyName: 'Gowri Manohari',
          roomNo: 'Hall 301',
        ),
        TimetableItemModel(
          dayOfWeek: 'WEDNESDAY',
          periodNumber: 6,
          periodName: 'Period 6',
          startTime: '02:40 PM',
          endTime: '03:30 PM',
          subjectCode: 'ACE-I',
          subjectName: 'Aptitude & Communication Enhancement I',
          facultyName: 'Gowri Manohari',
          roomNo: 'Hall 301',
        ),
        TimetableItemModel(
          dayOfWeek: 'WEDNESDAY',
          periodNumber: 7,
          periodName: 'Period 7',
          startTime: '03:30 PM',
          endTime: '04:20 PM',
          subjectCode: 'ACE-I',
          subjectName: 'Aptitude & Communication Enhancement I',
          facultyName: 'Gowri Manohari',
          roomNo: 'Hall 301',
        ),
      ];

      final mockService = MockStudentServiceForRefDesign(schedule);

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider<StudentService>.value(
          value: mockService,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(body: StudentTimetableScreen(simulatedTime: DateTime(2026, 10, 14, 10, 15))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Clean Header
      expect(find.text('Class Schedule'), findsOneWidget);
      expect(find.text('II Year CSE Cyber Security · Class 1'), findsOneWidget);

      // 2. Select Wednesday
      await tester.tap(find.text('Wed'));
      await tester.pumpAndSettle();

      // 3. Verify Left Timeline Times
      expect(find.text('08:45'), findsOneWidget);
      expect(find.text('09:40'), findsOneWidget);
      expect(find.text('10:55'), findsOneWidget);
      expect(find.text('11:50'), findsOneWidget);
      expect(find.text('01:45'), findsOneWidget);
      expect(find.text('02:40'), findsOneWidget);
      expect(find.text('03:30'), findsOneWidget);

      // 4. Verify Active Hero Card (Period 2)
      expect(find.text('NOW · PERIOD 2'), findsOneWidget);
      expect(find.text('until 10:35'), findsOneWidget);
      expect(find.text('Discrete Mathematics for Computing'), findsOneWidget);
      expect(find.text('Princy · Hall 301'), findsOneWidget);

      // 5. Verify Completed Card Checkmark
      expect(find.text('Object Oriented Programming Systems'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsWidgets);

      // 6. Verify Break Dividers
      expect(find.text('Tea break · 10:35'), findsOneWidget);
      expect(find.text('Lunch · 12:45'), findsOneWidget);

      // 7. Verify Upcoming Cards
      expect(find.text('Digital Principles & Computer Organization'), findsOneWidget);
      expect(find.text('Data Structures'), findsOneWidget);
    });

    testWidgets('Renders exact Weekly Matrix reference design elements from Image 1', (WidgetTester tester) async {
      final schedule = [
        TimetableItemModel(
          dayOfWeek: 'WEDNESDAY',
          periodNumber: 1,
          periodName: 'Period 1',
          startTime: '08:45 AM',
          endTime: '09:40 AM',
          subjectCode: 'OOPS',
          subjectName: 'Object Oriented Programming Systems',
          facultyName: 'Dr. John',
          roomNo: 'Hall 302',
        ),
        TimetableItemModel(
          dayOfWeek: 'WEDNESDAY',
          periodNumber: 2,
          periodName: 'Period 2',
          startTime: '09:40 AM',
          endTime: '10:35 AM',
          subjectCode: 'DMC',
          subjectName: 'Discrete Mathematics for Computing',
          facultyName: 'Princy',
          roomNo: 'Hall 301',
        ),
        TimetableItemModel(
          dayOfWeek: 'WEDNESDAY',
          periodNumber: 3,
          periodName: 'Period 3',
          startTime: '10:55 AM',
          endTime: '11:50 AM',
          subjectCode: 'DPCO',
          subjectName: 'Digital Principles & Computer Organization',
          facultyName: 'Lakshmi Narayanan',
          roomNo: 'Hall 301',
        ),
        TimetableItemModel(
          dayOfWeek: 'WEDNESDAY',
          periodNumber: 4,
          periodName: 'Period 4',
          startTime: '11:50 AM',
          endTime: '12:45 PM',
          subjectCode: 'DS',
          subjectName: 'Data Structures',
          facultyName: 'Showmiya',
          roomNo: 'Hall 301',
        ),
        TimetableItemModel(
          dayOfWeek: 'WEDNESDAY',
          periodNumber: 5,
          periodName: 'Period 5',
          startTime: '01:45 PM',
          endTime: '02:40 PM',
          subjectCode: 'ACE',
          subjectName: 'Aptitude & Communication Enhancement I',
          span: 3,
          facultyName: 'Gowri Manohari',
          roomNo: 'Hall 301',
        ),
      ];

      final mockService = MockStudentServiceForRefDesign(schedule);

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider<StudentService>.value(
          value: mockService,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(body: StudentTimetableScreen(simulatedTime: DateTime(2026, 10, 14, 10, 15))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Toggle to Weekly Matrix mode
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle();

      // 1. Verify Clean Header
      expect(find.text('Class Schedule'), findsOneWidget);
      expect(find.text('II Year CSE Cyber Security · Class 1'), findsOneWidget);

      // 2. Verify 6 Day Headers
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);

      // 3. Verify Period Labels and Times in Left Rail
      expect(find.text('P1'), findsOneWidget);
      expect(find.text('P2'), findsOneWidget);
      expect(find.text('P3'), findsOneWidget);
      expect(find.text('P4'), findsOneWidget);
      expect(find.text('P5'), findsOneWidget);
      expect(find.text('P6'), findsOneWidget);
      expect(find.text('P7'), findsOneWidget);
      expect(find.text('08:45'), findsOneWidget);
      expect(find.text('09:40'), findsOneWidget);
      expect(find.text('10:55'), findsOneWidget);
      expect(find.text('11:50'), findsOneWidget);
      expect(find.text('01:45'), findsOneWidget);
      expect(find.text('02:40'), findsOneWidget);
      expect(find.text('03:30'), findsOneWidget);

      // 4. Verify Break Dividers (Image 1)
      expect(find.text('Tea break'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);

      // 5. Verify Pastel Cards Codes (Image 1)
      expect(find.text('OOPS'), findsOneWidget);
      expect(find.text('DMC'), findsOneWidget);
      expect(find.text('DPCO'), findsOneWidget);
      expect(find.text('DS'), findsOneWidget);
      expect(find.text('ACE'), findsOneWidget);

      // 6. Tap Card -> Opens Details Modal
      await tester.tap(find.text('DMC'));
      await tester.pumpAndSettle();
      expect(find.text('Discrete Mathematics for Computing'), findsOneWidget);
    });
  });
}
