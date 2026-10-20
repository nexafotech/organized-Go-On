import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/models/user_model.dart';
import 'package:attendance_marker_mobile/models/faculty_model.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/services/auth_service.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';
import 'package:attendance_marker_mobile/services/notification_service.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_dashboard_screen.dart';
import 'package:attendance_marker_mobile/widgets/widgets.dart';

class SpecMockAuth extends ChangeNotifier implements AuthService {
  UserModel? _user;
  SpecMockAuth({UserModel? user}) {
    _user = user ?? UserModel(
      id: 4,
      username: 'fac01',
      fullName: 'Mathu Metlda',
      email: 'mathu@go-on.edu',
      role: 'FACULTY',
      isActive: true,
      department: 'CSE Cyber Security',
      employeeId: 'FAC01',
      isClassAdvisor: false,
    );
  }

  @override UserModel? get currentUser => _user;
  @override bool get isAuthenticated => true;
  @override bool get isLoading => false;
  @override String? get errorMessage => null;
  @override Future<void> logout() async {}
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SpecMockFaculty extends ChangeNotifier implements FacultyService {
  List<FacultyScheduleItem> _schedule = [];
  ActiveClassSlot? _activeSlot;
  bool _hasActiveSlot = false;
  int? _activeSessionId;
  String? _activeSessionStatus;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAdvisor = false;
  AdvisedClassInfo? _advisedClass;

  SpecMockFaculty({
    List<FacultyScheduleItem>? schedule,
    ActiveClassSlot? activeSlot,
    int? activeSessionId,
    bool isAdvisor = false,
    AdvisedClassInfo? advisedClass,
  }) {
    _schedule = schedule ?? [];
    _activeSlot = activeSlot;
    _hasActiveSlot = activeSlot != null;
    _activeSessionId = activeSessionId;
    _isAdvisor = isAdvisor;
    _advisedClass = advisedClass;
  }

  @override List<FacultyScheduleItem> get schedule => _schedule;
  @override List<FacultyScheduleItem> get classAdvisorSchedule => [];
  @override String? get classAdvisorClassName => _advisedClass?.name;
  @override ActiveClassSlot? get activeSlot => _activeSlot;
  @override bool get hasActiveSlot => _hasActiveSlot;
  @override int? get activeSessionId => _activeSessionId;
  @override String? get activeSessionStatus => _activeSessionStatus;
  @override bool get isLoading => _isLoading;
  @override String? get errorMessage => _errorMessage;
  @override bool get isClassAdvisor => _isAdvisor;
  @override AdvisedClassInfo? get advisedClass => _advisedClass;

  @override Future<void> loadDashboardData() async { notifyListeners(); }
  @override Future<void> fetchSchedule() async { notifyListeners(); }
  @override Future<void> fetchClassAdvisorTimetable() async { notifyListeners(); }
  @override Future<void> checkActiveClassSlot() async { notifyListeners(); }
  @override Future<void> checkActiveSession() async { notifyListeners(); }
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SpecMockNotification extends ChangeNotifier implements NotificationService {
  int _unreadCount = 0;
  SpecMockNotification({int unreadCount = 0}) {
    _unreadCount = unreadCount;
  }
  @override int get unreadCount => _unreadCount;
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Faculty / Class Advisor Dashboard UI Alignment Spec Tests', () {
    testWidgets('Regular Faculty Dashboard renders Student Portal header style with real data', (tester) async {
      final mockAuth = SpecMockAuth();
      final mockFaculty = SpecMockFaculty();
      final mockNotif = SpecMockNotification(unreadCount: 3);

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

      // Top row & Branding
      expect(find.byType(GoOnLogo), findsOneWidget);
      expect(find.text('FACULTY'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // Unread notification badge
      expect(find.byType(UserAvatarWidget), findsOneWidget);

      // Welcome section & real faculty data
      expect(find.text('Welcome Back!'), findsOneWidget);
      expect(find.text('Mathu Metlda'), findsOneWidget);
      expect(find.text('Faculty ID: FAC01'), findsOneWidget);
      expect(find.text('CSE Cyber Security'), findsOneWidget);

      // Tier 1: Current Scheduled Slot (No active class)
      expect(find.text('Current Scheduled Slot'), findsOneWidget);
      expect(find.text('NO ACTIVE CLASS'), findsOneWidget);

      // Tier 3: Today schedule
      expect(find.text('No teaching sessions scheduled for today.'), findsOneWidget);

      // Tier 4: Quick Actions
      expect(find.text('Mark Attendance'), findsOneWidget);
      expect(find.text('Attendance Reports & Matrix'), findsOneWidget);

      // Tier 5: Class Advisor should NOT be visible for regular faculty
      expect(find.text('MANAGE CLASS ATTENDANCE'), findsNothing);
    });

    testWidgets('Class Advisor Dashboard displays Advisor badge, assigned class, and Tier 5 action', (tester) async {
      final advisorUser = UserModel(
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

      final mockAuth = SpecMockAuth(user: advisorUser);
      final mockFaculty = SpecMockFaculty(
        isAdvisor: true,
        advisedClass: AdvisedClassInfo(id: 2, name: 'III Year CSE Cyber Security - Class 2'),
      );
      final mockNotif = SpecMockNotification(unreadCount: 0);

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

      // Top Row Role Badge shows CLASS ADVISOR
      expect(find.text('CLASS ADVISOR'), findsAtLeastNWidgets(1));
      expect(find.text('Showmiya S'), findsOneWidget);
      expect(find.text('Faculty ID: FAC02'), findsOneWidget);
      expect(find.text('Advisor: III Year CSE Cyber Security - Class 2'), findsOneWidget);

      // Tier 5: Class Advisor Summary card IS visible
      expect(find.text('MANAGE CLASS ATTENDANCE'), findsOneWidget);
      expect(find.text('You have authoritative management privileges for all periods (P1–P7) of your advised class across all subjects.'), findsOneWidget);
    });

    testWidgets('Tapping Go-On logo opens Faculty Navigation Drawer with complete menu items', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockAuth = SpecMockAuth();
      final mockFaculty = SpecMockFaculty();
      final mockNotif = SpecMockNotification(unreadCount: 0);

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

      // Tap Go-On logo
      await tester.tap(find.byType(GoOnLogo).first);
      await tester.pumpAndSettle();

      // Drawer Header
      expect(find.text('FACULTY PORTAL'), findsOneWidget);
      expect(find.text('Mathu Metlda'), findsWidgets);
      expect(find.text('FAC01'), findsWidgets);

      // Drawer Navigation Items
      expect(find.text('MAIN NAVIGATION'), findsOneWidget);
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Attendance'), findsWidgets);
      expect(find.text('Faculty Timetable'), findsWidgets);
      expect(find.text('Faculty Profile'), findsWidgets);
      expect(find.text('Notifications'), findsWidgets);

      // Faculty Services
      expect(find.text('FACULTY SERVICES'), findsOneWidget);
      expect(find.text('Attendance Reports & Matrix'), findsWidgets);
      expect(find.text('Change Password'), findsWidgets);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('Active class slot renders ACTIVE NOW badge and Start Attendance Session button', (tester) async {
      final mockAuth = SpecMockAuth();
      final mockFaculty = SpecMockFaculty(
        activeSlot: ActiveClassSlot(
          timetableEntryId: 101,
          assignmentId: 27,
          dayOfWeek: 'Wednesday',
          date: '2026-10-18',
          periodNumber: 1,
          periodName: 'Period 1',
          startTime: '09:10',
          endTime: '10:00',
          subjectCode: 'CC',
          subjectName: 'Cloud Computing',
          classId: 5,
          className: 'III Year CSE Cyber Security - Class 2',
          subjectId: 12,
        ),
      );
      final mockNotif = SpecMockNotification(unreadCount: 0);

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

      expect(find.text('ACTIVE NOW'), findsOneWidget);
      expect(find.text('Cloud Computing (CC)'), findsOneWidget);
      expect(find.text('START ATTENDANCE SESSION'), findsOneWidget);
    });

    testWidgets('Mandatory password update banner appears when flag is true', (tester) async {
      final forcedUser = UserModel(
        id: 4,
        username: 'fac01',
        fullName: 'Mathu Metlda',
        email: 'mathu@go-on.edu',
        role: 'FACULTY',
        isActive: true,
        forcePasswordChange: true,
      );

      final mockAuth = SpecMockAuth(user: forcedUser);
      final mockFaculty = SpecMockFaculty();
      final mockNotif = SpecMockNotification();

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

      expect(find.text('Mandatory Password Update'), findsAtLeastNWidgets(1));
      expect(find.text('Administration has requested you set a new password.'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Update'), findsOneWidget);
    });
  });
}
