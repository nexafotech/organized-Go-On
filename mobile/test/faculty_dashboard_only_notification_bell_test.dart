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
import 'package:attendance_marker_mobile/widgets/widgets.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_dashboard_screen.dart';
import 'package:attendance_marker_mobile/student/screens/student_dashboard_screen.dart';

class MockAuth extends ChangeNotifier implements AuthService {
  final UserModel _facultyAdvisor = UserModel(
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

  final UserModel _studentUser = UserModel(
    id: 12,
    username: '721025149001',
    fullName: 'Abinaya B',
    email: 'abinaya@go-on.edu',
    role: 'STUDENT',
    isActive: true,
  );

  bool _isStudent = false;
  void setRole({required bool isStudent}) {
    _isStudent = isStudent;
  }

  @override UserModel? get currentUser => _isStudent ? _studentUser : _facultyAdvisor;
  @override bool get isAuthenticated => true;
  @override bool get isLoading => false;
  @override String? get errorMessage => null;
  @override Future<void> logout() async {}
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFacultyService extends ChangeNotifier implements FacultyService {
  List<FacultyScheduleItem> _schedule = [];
  List<FacultyScheduleItem> _classAdvisorSchedule = [];

  MockFacultyService() {
    _schedule = [
      FacultyScheduleItem(
        id: 1,
        periodId: 1,
        periodNumber: 1,
        periodName: 'Period 1',
        dayOfWeek: 'Monday',
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
  int _unreadCount = 170;
  @override int get unreadCount => _unreadCount;
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Faculty Dashboard-Only Notification Bell Verification', () {
    testWidgets('1. Dashboard displays notification bell with exact unread badge', (tester) async {
      final mockAuth = MockAuth()..setRole(isStudent: false);
      final mockFaculty = MockFacultyService();
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

      // On Dashboard (index 0): NotificationBellWidget is present in dashboard header
      expect(find.byType(NotificationBellWidget), findsOneWidget);
      expect(find.text('170'), findsOneWidget);
      expect(find.text('Welcome Back!'), findsOneWidget);
    });

    testWidgets('2. Navigating to Attendance tab removes notification bell from header', (tester) async {
      final mockAuth = MockAuth()..setRole(isStudent: false);
      final mockFaculty = MockFacultyService();
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

      // Tap Attendance tab in bottom navigation
      final attendanceTab = find.text('Attendance');
      expect(attendanceTab, findsOneWidget);
      await tester.tap(attendanceTab);
      await tester.pumpAndSettle();

      // NotificationBellWidget must be completely absent from screen/header
      expect(find.byType(NotificationBellWidget), findsNothing);
      expect(find.text('170'), findsNothing);

      // Remaining header controls must be present
      expect(find.byIcon(Icons.assessment_rounded), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
      expect(find.byType(GoOnLogoBadge), findsOneWidget);
    });

    testWidgets('3. Navigating to Adviser tab removes notification bell from header', (tester) async {
      final mockAuth = MockAuth()..setRole(isStudent: false);
      final mockFaculty = MockFacultyService();
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

      // Tap Advisor tab in bottom navigation
      final advisorTab = find.text('Advisor');
      expect(advisorTab, findsOneWidget);
      await tester.tap(advisorTab);
      await tester.pumpAndSettle();

      // NotificationBellWidget must be completely absent from screen/header
      expect(find.byType(NotificationBellWidget), findsNothing);
      expect(find.text('170'), findsNothing);

      // Remaining header controls must be present
      expect(find.text('Class Advisor'), findsOneWidget);
      expect(find.byIcon(Icons.assessment_rounded), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
      expect(find.byType(GoOnLogoBadge), findsOneWidget);
    });

    testWidgets('4. Navigating to Timetable tab removes notification bell from header', (tester) async {
      final mockAuth = MockAuth()..setRole(isStudent: false);
      final mockFaculty = MockFacultyService();
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

      // Tap Timetable tab in bottom navigation
      final timetableTab = find.text('Timetable');
      expect(timetableTab, findsOneWidget);
      await tester.tap(timetableTab);
      await tester.pumpAndSettle();

      // NotificationBellWidget must be completely absent
      expect(find.byType(NotificationBellWidget), findsNothing);
      expect(find.text('170'), findsNothing);

      // Timetable toggle menu icon and other controls must be present
      expect(find.byType(TimetableToggleMenuIcon), findsOneWidget);
      expect(find.byIcon(Icons.assessment_rounded), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
    });

    testWidgets('5. Dynamic round-trip navigation updates bell without requiring restart', (tester) async {
      final mockAuth = MockAuth()..setRole(isStudent: false);
      final mockFaculty = MockFacultyService();
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
      // Initially on Dashboard -> bell present
      expect(find.byType(NotificationBellWidget), findsOneWidget);

      // Navigate to Attendance -> bell removed
      await tester.tap(find.text('Attendance'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationBellWidget), findsNothing);

      // Navigate to Advisor -> bell still removed
      await tester.tap(find.text('Advisor'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationBellWidget), findsNothing);

      // Navigate back to Dashboard -> bell reappears seamlessly
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationBellWidget), findsOneWidget);
      expect(find.text('170'), findsOneWidget);
    });

    testWidgets('6. Student portal notification bell remains unaffected', (tester) async {
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
        subjects: [],
        timetable: [],
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Student portal bell remains intact
      expect(find.byType(NotificationBellWidget), findsOneWidget);
    });

    // Multi-viewport verification across all 5 standard viewports
    final requiredViewports = <String, Size>{
      'Compact Mobile (360x800)': const Size(360, 800),
      'Galaxy S24 (390x844)': const Size(390, 844),
      'Tablet (768x1024)': const Size(768, 1024),
      'Laptop (1366x768)': const Size(1366, 768),
      'Desktop (1680x900)': const Size(1680, 900),
    };

    for (final entry in requiredViewports.entries) {
      testWidgets('7. Viewport ${entry.key}: Class Advisor header layout clean with 0 overflows', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockAuth = MockAuth()..setRole(isStudent: false);
        final mockFaculty = MockFacultyService();
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

        // Switch to Advisor tab
        await tester.tap(find.text('Advisor'));
        await tester.pumpAndSettle();

        // Confirm 0 notification bell
        expect(find.byType(NotificationBellWidget), findsNothing);

        // Header controls must be visible without overflow
        expect(find.text('Class Advisor'), findsOneWidget);
        expect(find.byIcon(Icons.assessment_rounded), findsOneWidget);
      });
    }
  });
}
