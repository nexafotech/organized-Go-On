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

class MockAuthAdvisor extends ChangeNotifier implements AuthService {
  final UserModel _user = UserModel(
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

  @override UserModel? get currentUser => _user;
  @override bool get isAuthenticated => true;
  @override bool get isLoading => false;
  @override String? get errorMessage => null;
  @override Future<void> logout() async {}
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFacultyAdvisor extends ChangeNotifier implements FacultyService {
  List<FacultyScheduleItem> _schedule = [];
  List<FacultyScheduleItem> _classAdvisorSchedule = [];

  MockFacultyAdvisor({
    List<FacultyScheduleItem>? schedule,
    List<FacultyScheduleItem>? classAdvisorSchedule,
  }) {
    _schedule = schedule ?? [
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
    _classAdvisorSchedule = classAdvisorSchedule ?? _schedule;
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
  @override Future<void> checkActiveClassSlot() async {}
  @override Future<void> checkActiveSession() async {}
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockNotificationService extends ChangeNotifier implements NotificationService {
  @override int get unreadCount => 5;
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final viewports = <String, Size>{
    'Desktop (1680x900)': const Size(1680, 900),
    'Laptop (1366x768)': const Size(1366, 768),
    'Tablet (768x1024)': const Size(768, 1024),
    'Mobile (390x844)': const Size(390, 844),
    'Mobile Small (360x800)': const Size(360, 800),
    'Large Desktop (1920x1080)': const Size(1920, 1080),
  };

  for (final entry in viewports.entries) {
    testWidgets('Faculty Timetable renders properly on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockFaculty = MockFacultyAdvisor();
      final mockAuth = MockAuthAdvisor();
      final mockNotif = MockNotificationService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
            ChangeNotifierProvider<NotificationService>.value(value: mockNotif),
          ],
          child: const MaterialApp(
            home: FacultyDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Timetable in bottom nav
      final timetableTabFinder = find.text('Timetable');
      expect(timetableTabFinder, findsOneWidget);
      await tester.tap(timetableTabFinder);
      await tester.pumpAndSettle();

      // Verify AppBar Title
      expect(find.text('Faculty Timetable'), findsOneWidget);

      // Verify Timetable content is visible and non-zero height
      final listViewFinder = find.byType(ListView);
      expect(listViewFinder, findsWidgets);

      final rect = tester.getRect(listViewFinder.first);
      expect(rect.height, greaterThan(200.0), reason: 'ListView must have non-zero height on ${entry.key}');
      expect(rect.width, greaterThan(200.0), reason: 'ListView must have non-zero width on ${entry.key}');

      // Verify schedule details are rendered
      expect(find.text('Algorithms'), findsOneWidget);
      expect(find.textContaining('CS3401'), findsOneWidget);
    });
  }
}
