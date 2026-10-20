import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/models/user_model.dart';
import 'package:attendance_marker_mobile/models/faculty_model.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/services/auth_service.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_dashboard_screen.dart';

class RealDataMockAuth extends ChangeNotifier implements AuthService {
  final UserModel _user = UserModel(
    id: 4,
    username: 'fac01',
    fullName: 'Mathu T',
    email: 'mathu@go-on.edu',
    role: 'FACULTY',
    isActive: true,
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

class RealDataMockFaculty extends ChangeNotifier implements FacultyService {
  final List<FacultyScheduleItem> _schedule = [
    FacultyScheduleItem(
      id: 257,
      dayOfWeek: 'Thursday',
      periodId: 1,
      periodNumber: 1,
      periodName: 'Period 1',
      startTime: '09:10',
      endTime: '10:00',
      assignmentId: 27,
      subjectCode: 'CC',
      subjectName: 'Cloud Computing',
      className: 'III Year CSE Cyber Security - Class 2',
      facultyName: 'Mathu T',
    ),
  ];

  @override
  List<FacultyScheduleItem> get schedule => _schedule;
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  bool get isClassAdvisor => false;
  @override
  AdvisedClassInfo? get advisedClass => null;
  @override
  ActiveClassSlot? get activeSlot => null;
  @override
  bool get hasActiveSlot => false;
  @override
  int? get activeSessionId => null;
  @override
  String? get activeSessionStatus => null;
  @override
  Future<void> loadDashboardData() async {}
  @override
  Future<void> fetchSchedule() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('FacultyDashboardScreen renders with real faculty data on 1024x489 viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 489));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final mockFaculty = RealDataMockFaculty();
    final mockAuth = RealDataMockAuth();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FacultyService>.value(value: mockFaculty),
          ChangeNotifierProvider<AuthService>.value(value: mockAuth),
        ],
        child: const MaterialApp(
          home: FacultyDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Faculty Dashboard'), findsOneWidget);
    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.text('Mathu T'), findsOneWidget);
    expect(find.text('Current Scheduled Slot'), findsOneWidget);
    expect(find.text('NO ACTIVE CLASS'), findsOneWidget);
    expect(find.text('Attendance Reports & Matrix'), findsOneWidget);
    expect(find.text('Mark Attendance'), findsOneWidget);
    expect(find.text('No teaching sessions scheduled for today.'), findsOneWidget);
  });
}
