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
import 'package:attendance_marker_mobile/core/theme/theme_service.dart';
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

// Student service mock helper
StudentService createMockStudentService() {
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
  return studentService;
}

class MockNotificationService extends ChangeNotifier implements NotificationService {
  @override int get unreadCount => 5;
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Theme Toggle Visibility — Profile Only Rule Verification', () {
    testWidgets('1. Faculty Dashboard does NOT display theme toggle icon', (tester) async {
      final mockAuth = MockAuth()..setRole(isStudent: false);
      final mockFaculty = MockFacultyService();
      final mockNotif = MockNotificationService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
            ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
            ChangeNotifierProvider<NotificationService>.value(value: mockNotif),
            ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService(initialThemeMode: ThemeMode.light)),
          ],
          child: const MaterialApp(
            home: FacultyDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Theme toggle icons should NOT be in the dashboard
      expect(find.byIcon(Icons.light_mode_rounded), findsNothing);
      expect(find.byIcon(Icons.dark_mode_rounded), findsNothing);
    });

    testWidgets('2. Faculty Attendance header does NOT display theme toggle icon', (tester) async {
      final mockAuth = MockAuth()..setRole(isStudent: false);
      final mockFaculty = MockFacultyService();
      final mockNotif = MockNotificationService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
            ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
            ChangeNotifierProvider<NotificationService>.value(value: mockNotif),
            ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService(initialThemeMode: ThemeMode.light)),
          ],
          child: const MaterialApp(
            home: FacultyDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Attendance'));
      await tester.pumpAndSettle();

      // Attendance AppBar: no theme icon
      expect(find.text('Attendance'), findsWidgets);
      expect(find.byTooltip('Switch to Dark Theme'), findsNothing);
      expect(find.byTooltip('Switch to Light Theme'), findsNothing);
    });

    testWidgets('3. Faculty Class Advisor header does NOT display theme toggle icon', (tester) async {
      final mockAuth = MockAuth()..setRole(isStudent: false);
      final mockFaculty = MockFacultyService();
      final mockNotif = MockNotificationService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
            ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
            ChangeNotifierProvider<NotificationService>.value(value: mockNotif),
            ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService(initialThemeMode: ThemeMode.light)),
          ],
          child: const MaterialApp(
            home: FacultyDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Advisor'));
      await tester.pumpAndSettle();

      expect(find.text('Class Advisor'), findsOneWidget);
      expect(find.byTooltip('Switch to Dark Theme'), findsNothing);
      expect(find.byTooltip('Switch to Light Theme'), findsNothing);
    });

    testWidgets('4. Faculty Timetable header does NOT display theme toggle icon', (tester) async {
      final mockAuth = MockAuth()..setRole(isStudent: false);
      final mockFaculty = MockFacultyService();
      final mockNotif = MockNotificationService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
            ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
            ChangeNotifierProvider<NotificationService>.value(value: mockNotif),
            ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService(initialThemeMode: ThemeMode.light)),
          ],
          child: const MaterialApp(
            home: FacultyDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Switch to Dark Theme'), findsNothing);
      expect(find.byTooltip('Switch to Light Theme'), findsNothing);
    });

    testWidgets('5. Faculty Profile page DOES display theme toggle in header and theme card in body', (tester) async {
      final mockAuth = MockAuth()..setRole(isStudent: false);
      final mockFaculty = MockFacultyService();
      final mockNotif = MockNotificationService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
            ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
            ChangeNotifierProvider<NotificationService>.value(value: mockNotif),
            ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService(initialThemeMode: ThemeMode.light)),
          ],
          child: const MaterialApp(
            home: FacultyDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      // In Faculty Profile header, theme toggle tooltip IS present
      expect(find.byTooltip('Switch to Dark Theme'), findsOneWidget);

      // In Faculty Profile body, "Appearance & Theme" and options are present
      expect(find.text('Appearance & Theme'), findsOneWidget);
      expect(find.text('Warm Light'), findsOneWidget);
      expect(find.text('Obsidian Dark'), findsOneWidget);
    });

    testWidgets('6. Faculty Drawer does NOT contain theme toggle item', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockAuth = MockAuth()..setRole(isStudent: false);
      final mockFaculty = MockFacultyService();
      final mockNotif = MockNotificationService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
            ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
            ChangeNotifierProvider<NotificationService>.value(value: mockNotif),
            ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService(initialThemeMode: ThemeMode.light)),
          ],
          child: const MaterialApp(
            home: FacultyDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer on the root Scaffold which has the drawer
      final rootScaffold = find.byWidgetPredicate((w) => w is Scaffold && w.drawer != null);
      expect(rootScaffold, findsOneWidget);
      tester.state<ScaffoldState>(rootScaffold).openDrawer();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Confirm drawer opened by checking top navigation item
      expect(find.text('Faculty Profile'), findsOneWidget);
      // Theme toggle drawer item must NOT be present anywhere in drawer
      expect(find.text('Switch to Light Theme'), findsNothing);
      expect(find.text('Switch to Dark Theme'), findsNothing);
    });

    testWidgets('7. Student Drawer does NOT contain theme toggle item', (tester) async {
      final mockAuth = MockAuth()..setRole(isStudent: true);
      final mockStudent = createMockStudentService();
      final mockNotif = MockNotificationService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
            ChangeNotifierProvider<StudentService>.value(value: mockStudent),
            ChangeNotifierProvider<NotificationService>.value(value: mockNotif),
            ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService(initialThemeMode: ThemeMode.light)),
          ],
          child: const MaterialApp(
            home: StudentDashboardScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Open student drawer directly on the root Scaffold with drawer
      final studentRootScaffold = find.byWidgetPredicate((w) => w is Scaffold && w.drawer != null);
      expect(studentRootScaffold, findsOneWidget);
      tester.state<ScaffoldState>(studentRootScaffold).openDrawer();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Confirm drawer opened by checking top navigation item
      expect(find.text('Student Profile'), findsOneWidget);
      expect(find.text('Switch to Light Theme'), findsNothing);
      expect(find.text('Switch to Dark Theme'), findsNothing);
    });

    const viewports = <String, Size>{
      'Compact Mobile': Size(360, 800),
      'Galaxy S24': Size(390, 844),
      'Tablet': Size(768, 1024),
      'Laptop': Size(1366, 768),
      'Desktop': Size(1680, 900),
    };

    for (final entry in viewports.entries) {
      testWidgets('8. Viewport ${entry.key} (${entry.value.width.toInt()}x${entry.value.height.toInt()}): Header layout clean with 0 overflows', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final mockAuth = MockAuth()..setRole(isStudent: false);
        final mockFaculty = MockFacultyService();
        final mockNotif = MockNotificationService();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthService>.value(value: mockAuth),
              ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
              ChangeNotifierProvider<NotificationService>.value(value: mockNotif),
              ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService(initialThemeMode: ThemeMode.light)),
            ],
            child: const MaterialApp(
              home: FacultyDashboardScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Attendance tab
        await tester.tap(find.text('Attendance'));
        await tester.pumpAndSettle();

        // Switch to Profile tab
        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  });
}
