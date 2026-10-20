import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/models/user_model.dart';
import 'package:attendance_marker_mobile/models/faculty_model.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/services/auth_service.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_dashboard_screen.dart';

class MockAuthForNav extends ChangeNotifier implements AuthService {
  final UserModel _user;
  MockAuthForNav({required bool isAdvisor})
      : _user = UserModel(
          id: 5,
          username: 'faculty01',
          fullName: 'Prof. Santhiya',
          email: 'santhiya@go-on.edu',
          role: 'FACULTY',
          isActive: true,
          isClassAdvisor: isAdvisor,
        );

  @override
  UserModel? get currentUser => _user;
  @override
  bool get isAuthenticated => true;
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  Future<void> logout() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFacultyForNav extends ChangeNotifier implements FacultyService {
  final bool _isAdvisor;
  MockFacultyForNav({required bool isAdvisor}) : _isAdvisor = isAdvisor;

  @override
  bool get isClassAdvisor => _isAdvisor;
  @override
  List<FacultyScheduleItem> get schedule => [];
  @override
  List<FacultyScheduleItem> get classAdvisorSchedule => [];
  @override
  String? get classAdvisorClassName => 'II Year CSE Cyber Security - Class 1';
  @override
  AdvisedClassInfo? get advisedClass => _isAdvisor
      ? AdvisedClassInfo(id: 2, name: 'II Year CSE Cyber Security - Class 1')
      : null;
  @override
  ActiveClassSlot? get activeSlot => null;
  @override
  int? get activeSessionId => null;
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  Future<void> loadDashboardData() async {}
  @override
  Future<void> fetchSchedule() async {}
  @override
  Future<void> fetchClassAdvisorTimetable() async {}
  @override
  Future<ClassAdvisorAvailablePeriodsResponse> fetchClassAdvisorAvailablePeriods() async {
    return ClassAdvisorAvailablePeriodsResponse(
      isClassAdvisor: _isAdvisor,
      advisedClass: _isAdvisor ? AdvisedClassInfo(id: 2, name: 'II Year CSE Cyber Security - Class 1') : null,
      todayPeriods: [],
      yesterdayPeriods: [],
      todayDate: '2026-10-19',
      todayDay: 'Monday',
      yesterdayDate: '2026-10-18',
      yesterdayDay: 'Sunday',
      currentTime: '10:00 AM',
      lunchBreak: LunchBreakInfo(),
    );
  }
  @override
  Future<ClassAdvisorPeriodsForDateResponse> fetchClassAdvisorPeriodsForDate(String date) async {
    return ClassAdvisorPeriodsForDateResponse(
      isClassAdvisor: _isAdvisor,
      advisedClass: _isAdvisor ? AdvisedClassInfo(id: 2, name: 'II Year CSE Cyber Security - Class 1') : null,
      date: date,
      dayOfWeek: 'Monday',
      isToday: true,
      periods: [],
      lunchBreak: LunchBreakInfo(),
    );
  }
  @override
  Future<AvailablePeriodsResponse> fetchAvailableAttendancePeriods() async {
    return AvailablePeriodsResponse(
      todayPeriods: [],
      yesterdayPeriods: [],
      todayDate: '2026-10-19',
      todayDay: 'Monday',
      yesterdayDate: '2026-10-18',
      yesterdayDay: 'Sunday',
      currentTime: '10:00 AM',
    );
  }
  @override
  Future<FacultyPeriodsForDateResponse> fetchPeriodsForDate(String date) async {
    return FacultyPeriodsForDateResponse(
      date: date,
      dayOfWeek: 'Monday',
      isToday: true,
      periods: [],
    );
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Faculty & Class Adviser Bottom Navigation Bar Tests', () {
    testWidgets('Renders 4 items for non-advisor faculty inside floating pill', (tester) async {
      final mockAuth = MockAuthForNav(isAdvisor: false);
      final mockFaculty = MockFacultyForNav(isAdvisor: false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
            ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
          ],
          child: const MaterialApp(
            home: FacultyDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the 4 destinations exist
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Timetable'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Advisor'), findsNothing);

      // Verify floating pill container
      final paddingFinder = find.byWidgetPredicate((widget) {
        return widget is Padding &&
            widget.padding == const EdgeInsets.fromLTRB(16, 0, 16, 12);
      });
      expect(paddingFinder, findsWidgets);

      // Verify ClipRRect with radius 32
      final clipRRectFinder = find.byWidgetPredicate((widget) {
        return widget is ClipRRect &&
            widget.borderRadius == BorderRadius.circular(32);
      });
      expect(clipRRectFinder, findsOneWidget);
    });

    testWidgets('Renders all 5 items for Class Advisor inside floating pill and switches tabs', (tester) async {
      final mockAuth = MockAuthForNav(isAdvisor: true);
      final mockFaculty = MockFacultyForNav(isAdvisor: true);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
            ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
          ],
          child: const MaterialApp(
            home: FacultyDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // All 5 destinations exist for Class Advisor
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Advisor'), findsOneWidget);
      expect(find.text('Timetable'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Tap Advisor tab
      await tester.tap(find.text('Advisor'));
      await tester.pumpAndSettle();
      expect(find.text('Class Advisor'), findsOneWidget);

      // Tap Timetable tab
      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();
      expect(find.text('Faculty Timetable'), findsOneWidget);

      // Tap Profile tab
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Faculty Profile'), findsOneWidget);

      // Tap back to Dashboard tab
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
    });

    testWidgets('Samsung Galaxy S24 (393 x 851 dp) Dark Theme renders cleanly without overflow', (tester) async {
      tester.view.physicalSize = const Size(393 * 2.625, 851 * 2.625);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockAuth = MockAuthForNav(isAdvisor: true);
      final mockFaculty = MockFacultyForNav(isAdvisor: true);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
            ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const FacultyDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify no exceptions and all 5 labels fit cleanly
      expect(tester.takeException(), isNull);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Advisor'), findsOneWidget);
      expect(find.text('Timetable'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });
  });
}
