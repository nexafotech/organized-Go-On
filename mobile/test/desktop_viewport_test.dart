import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/models/user_model.dart';
import 'package:attendance_marker_mobile/models/faculty_model.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/services/auth_service.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_dashboard_screen.dart';

class MockAuth extends ChangeNotifier implements AuthService {
  final UserModel _user = UserModel(
    id: 10,
    username: 'fac_cs01',
    fullName: 'Dr. Alan Turing',
    email: 'turing@go-on.edu',
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

class MockFaculty extends ChangeNotifier implements FacultyService {
  @override
  List<FacultyScheduleItem> get schedule => [];
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
  testWidgets('FacultyDashboardScreen renders on 1024x489 viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 489));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final mockFaculty = MockFaculty();
    final mockAuth = MockAuth();

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
    expect(find.text('Dr. Alan Turing'), findsOneWidget);

    final indexedStackFinder = find.byType(IndexedStack);
    print('IndexedStack rect: ${tester.getRect(indexedStackFinder)}');
    print('Welcome rect: ${tester.getRect(find.text('Welcome Back!'))}');
  });
}
