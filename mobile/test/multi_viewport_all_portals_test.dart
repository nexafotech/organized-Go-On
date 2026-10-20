import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/models/user_model.dart';
import 'package:attendance_marker_mobile/models/student_model.dart';
import 'package:attendance_marker_mobile/models/faculty_model.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/services/auth_service.dart';
import 'package:attendance_marker_mobile/services/student_service.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';
import 'package:attendance_marker_mobile/services/notification_service.dart';
import 'package:attendance_marker_mobile/student/screens/student_dashboard_screen.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_dashboard_screen.dart';

class MockAuth extends ChangeNotifier implements AuthService {
  final UserModel _studentUser = UserModel(
    id: 12,
    username: '721025149001',
    fullName: 'Abinaya B',
    email: 'abinaya@go-on.edu',
    role: 'STUDENT',
    isActive: true,
  );

  final UserModel _facultyUser = UserModel(
    id: 5,
    username: 'fac02',
    fullName: 'Showmiya S',
    email: 'showmiya@go-on.edu',
    role: 'FACULTY',
    isActive: true,
    department: 'CSE Cyber Security',
    employeeId: 'FAC02',
    isClassAdvisor: true,
    advisedClassName: 'III Year CSE Cyber Security - Class 2',
  );

  bool _isStudent = true;
  void setRole({required bool isStudent}) {
    _isStudent = isStudent;
  }

  @override UserModel? get currentUser => _isStudent ? _studentUser : _facultyUser;
  @override bool get isAuthenticated => true;
  @override bool get isLoading => false;
  @override String? get errorMessage => null;
  @override Future<void> logout() async {}
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFacultyAdvisor extends ChangeNotifier implements FacultyService {
  List<FacultyScheduleItem> _schedule = [];
  List<FacultyScheduleItem> _classAdvisorSchedule = [];

  MockFacultyAdvisor() {
    _schedule = [
      for (final day in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'])
        FacultyScheduleItem(
          id: 1,
          periodId: 1,
          periodNumber: 1,
          periodName: 'Period 1',
          dayOfWeek: day,
          startTime: '09:10',
          endTime: '10:00',
          assignmentId: 1,
          subjectCode: 'CS3401',
          subjectName: 'Algorithms',
          className: 'III Year CSE Cyber Security - Class 2',
        ),
    ];
    _classAdvisorSchedule = _schedule;
  }

  @override List<FacultyScheduleItem> get schedule => _schedule;
  @override List<FacultyScheduleItem> get classAdvisorSchedule => _classAdvisorSchedule;
  @override String? get classAdvisorClassName => 'III Year CSE Cyber Security - Class 2';
  @override bool get isLoading => false;
  @override String? get errorMessage => null;
  @override bool get isClassAdvisor => true;
  @override AdvisedClassInfo? get advisedClass => AdvisedClassInfo(id: 2, name: 'III Year CSE Cyber Security - Class 2');
  @override ActiveClassSlot? get activeSlot => null;
  @override bool get hasActiveSlot => false;
  @override int? get activeSessionId => null;
  @override String? get activeSessionStatus => null;
  @override Future<void> loadDashboardData() async {}
  @override Future<void> fetchSchedule() async {}
  @override Future<void> fetchClassAdvisorTimetable() async {}
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockNotificationService extends ChangeNotifier implements NotificationService {
  @override int get unreadCount => 3;
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final requiredViewports = <String, Size>{
    'Compact Mobile (360x800)': const Size(360, 800),
    'Galaxy S24 (390x844)': const Size(390, 844),
    'Tablet (768x1024)': const Size(768, 1024),
    'Laptop (1366x768)': const Size(1366, 768),
    'Desktop (1680x900)': const Size(1680, 900),
  };

  group('Student Portal Viewport Responsiveness', () {
    for (final entry in requiredViewports.entries) {
      testWidgets('Student Portal renders without height collapse on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockAuth = MockAuth()..setRole(isStudent: true);
        final studentService = StudentService();
        studentService.setMockData(
          summary: StudentSummaryModel(
            studentId: 1,
            registerNumber: '721025149001',
            fullName: 'Abinaya B',
            className: 'III Year CSE Cyber Security - Class 2',
            isActive: true,
            total: 120,
            present: 106,
            absent: 14,
            od: 0,
            percentage: 88.5,
            calculationMode: 'PERIOD',
            attendanceStatus: 'OK',
            minimumRequired: 75.0,
            belowMinimum: false,
          ),
          subjects: [
            SubjectAttendanceModel(
              subjectId: 1,
              subjectCode: 'CS3401',
              subjectName: 'Algorithms',
              total: 20,
              present: 18,
              absent: 2,
              od: 0,
              percentage: 90.0,
            ),
          ],
          timetable: [
            for (final day in ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'])
              TimetableItemModel(
                dayOfWeek: day,
                periodNumber: 1,
                periodName: 'Period 1',
                startTime: '09:10 AM',
                endTime: '10:00 AM',
                subjectCode: 'CS3401',
                subjectName: 'Algorithms',
              ),
          ],
        );

        final mockNotif = MockNotificationService();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthService>.value(value: mockAuth),
              ChangeNotifierProvider<StudentService>.value(value: studentService),
              ChangeNotifierProvider<NotificationService>.value(value: mockNotif),
            ],
            child: const MaterialApp(
              home: StudentDashboardScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify body IndexedStack is rendered with full non-zero height
        final indexedStackFinder = find.byType(IndexedStack);
        expect(indexedStackFinder, findsWidgets);
        final rect = tester.getRect(indexedStackFinder.first);
        expect(rect.height, greaterThan(300.0), reason: 'Student body must have non-zero height on ${entry.key}');
        expect(rect.width, greaterThan(300.0), reason: 'Student body must have non-zero width on ${entry.key}');

        // Verify student information is visible
        expect(find.text('Abinaya B'), findsOneWidget);
        expect(find.text('III Year CSE Cyber Security - Class 2'), findsOneWidget);

        // Tap Timetable in bottom navigation
        final timetableTabFinder = find.text('Timetable');
        expect(timetableTabFinder, findsOneWidget);
        await tester.tap(timetableTabFinder);
        await tester.pumpAndSettle();

        // Verify timetable tab rendered
        expect(find.text('Algorithms'), findsWidgets);
      });
    }
  });

  group('Faculty Portal Viewport Responsiveness', () {
    for (final entry in requiredViewports.entries) {
      testWidgets('Faculty Portal renders without height collapse on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockAuth = MockAuth()..setRole(isStudent: false);
        final mockFaculty = MockFacultyAdvisor();
        final mockNotif = MockNotificationService();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthService>.value(value: mockAuth),
              ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
              ChangeNotifierProvider<NotificationService>.value(value: mockNotif),
            ],
            child: const MaterialApp(
              home: FacultyDashboardScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify body IndexedStack has full non-zero height
        final indexedStackFinder = find.byType(IndexedStack);
        expect(indexedStackFinder, findsWidgets);
        final rect = tester.getRect(indexedStackFinder.first);
        expect(rect.height, greaterThan(300.0), reason: 'Faculty body must have non-zero height on ${entry.key}');
        expect(rect.width, greaterThan(300.0), reason: 'Faculty body must have non-zero width on ${entry.key}');

        // Tap Timetable tab
        final timetableTab = find.text('Timetable');
        expect(timetableTab, findsOneWidget);
        await tester.tap(timetableTab);
        await tester.pumpAndSettle();

        expect(find.text('Faculty Timetable'), findsOneWidget);
        expect(find.text('Algorithms'), findsOneWidget);
      });
    }
  });
}
