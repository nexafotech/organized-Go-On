import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/models/user_model.dart';
import 'package:attendance_marker_mobile/models/student_model.dart';
import 'package:attendance_marker_mobile/services/auth_service.dart';
import 'package:attendance_marker_mobile/services/student_service.dart';
import 'package:attendance_marker_mobile/student/screens/student_profile_screen.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_profile_screen.dart';
import 'package:attendance_marker_mobile/auth/widgets/change_password_dialog.dart';

class MockAuthServiceForProfile extends ChangeNotifier implements AuthService {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool logoutCalled = false;
  bool changePasswordCalled = false;
  String? lastCurrentPassword;
  String? lastNewPassword;

  MockAuthServiceForProfile({UserModel? user}) : _currentUser = user;

  @override
  UserModel? get currentUser => _currentUser;
  @override
  bool get isLoading => _isLoading;
  @override
  String? get errorMessage => _errorMessage;
  @override
  bool get sessionExpired => false;
  @override
  bool get isAuthenticated => _currentUser != null;

  @override
  void clearErrorMessage() {}
  @override
  void clearSessionExpired() {}
  @override
  Future<UserModel?> loginStudent(String identifier, String password) async => _currentUser;
  @override
  Future<UserModel?> loginFaculty(String usernameOrEmail, String password) async => _currentUser;
  @override
  Future<UserModel?> restoreSession() async => _currentUser;

  @override
  Future<bool> changePassword({required String currentPassword, required String newPassword}) async {
    changePasswordCalled = true;
    lastCurrentPassword = currentPassword;
    lastNewPassword = newPassword;
    return true;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
    _currentUser = null;
    notifyListeners();
  }

  @override
  Future<Map<String, dynamic>> validateIdentifier(String identifier, {String role = 'FACULTY'}) async =>
      {'valid': true, 'role': role, 'message': null, 'is_network_error': false};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockStudentServiceForProfile extends ChangeNotifier implements StudentService {
  StudentSummaryModel? _summary;
  List<SubjectAttendanceModel> _subjects = [];
  List<TimetableItemModel> _timetable = [];
  List<DateWiseEntryModel> _dateWise = [];
  bool _isLoading = false;
  String? _errorMessage;

  MockStudentServiceForProfile({StudentSummaryModel? summary}) : _summary = summary;

  @override
  StudentSummaryModel? get summary => _summary;
  @override
  List<SubjectAttendanceModel> get subjects => _subjects;
  @override
  List<TimetableItemModel> get timetable => _timetable;
  @override
  List<DateWiseEntryModel> get dateWise => _dateWise;
  @override
  bool get isLoading => _isLoading;
  @override
  String? get errorMessage => _errorMessage;

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

  bool updateProfileDetailsCalled = false;
  String? updatedFullName;
  String? updatedEmail;
  String? updatedPhone;
  String? updatedAvatarId;

  @override
  Future<bool> updateProfileDetails({
    String? fullName,
    String? email,
    String? phone,
    String? avatarId,
  }) async {
    updateProfileDetailsCalled = true;
    updatedFullName = fullName;
    updatedEmail = email;
    updatedPhone = phone;
    updatedAvatarId = avatarId;
    if (_summary != null) {
      _summary = _summary!.copyWith(
        fullName: fullName ?? _summary!.fullName,
        email: email ?? _summary!.email,
        phone: phone ?? _summary!.phone,
        avatarId: avatarId ?? _summary!.avatarId,
      );
      notifyListeners();
    }
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Student Profile Tests', () {
    testWidgets('Renders all student profile information correctly', (tester) async {
      final summary = StudentSummaryModel(
        studentId: 10,
        fullName: 'Jane Doe',
        registerNumber: '23CY050',
        email: 'jane@college.edu',
        className: 'II Year CSE - Section B',
        semester: 'Semester 4',
        department: 'Cyber Security',
        isActive: true,
        total: 20,
        present: 18,
        absent: 2,
        od: 0,
        percentage: 90.0,
        calculationMode: 'RECORD_BASED',
        attendanceStatus: 'OK',
        minimumRequired: 75.0,
        belowMinimum: false,
      );

      final mockAuth = MockAuthServiceForProfile();
      final mockStudent = MockStudentServiceForProfile(summary: summary);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
            ChangeNotifierProvider<StudentService>.value(value: mockStudent),
          ],
          child: const MaterialApp(
            home: Scaffold(body: StudentProfileScreen()),
          ),
        ),
      );

      expect(find.text('Jane Doe'), findsNWidgets(2)); // Header + Academic tile
      expect(find.text('Reg No: 23CY050'), findsOneWidget);
      expect(find.text('23CY050'), findsOneWidget);
      expect(find.text('jane@college.edu'), findsOneWidget);
      expect(find.text('II Year CSE - Section B'), findsOneWidget);
      expect(find.text('Cyber Security'), findsOneWidget);
      expect(find.text('Semester 4'), findsOneWidget);
      expect(find.text('Active Student'), findsOneWidget);
      expect(find.text('Edit Profile Details'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('Tapping Edit Profile Details button opens EditProfileSheet with prefilled details and allows editing', (tester) async {
      final summary = StudentSummaryModel(
        studentId: 10,
        fullName: 'Jane Doe',
        registerNumber: '23CY050',
        email: 'jane@college.edu',
        phone: '9876543210',
        className: 'II Year CSE - Section B',
        semester: 'Semester 4',
        department: 'Cyber Security',
        isActive: true,
        total: 20,
        present: 18,
        absent: 2,
        od: 0,
        percentage: 90.0,
        calculationMode: 'RECORD_BASED',
        attendanceStatus: 'OK',
        minimumRequired: 75.0,
        belowMinimum: false,
      );

      final mockAuth = MockAuthServiceForProfile();
      final mockStudent = MockStudentServiceForProfile(summary: summary);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
            ChangeNotifierProvider<StudentService>.value(value: mockStudent),
          ],
          child: const MaterialApp(
            home: Scaffold(body: StudentProfileScreen()),
          ),
        ),
      );

      // Verify button exists and tap it
      final editBtn = find.text('Edit Profile Details');
      expect(editBtn, findsOneWidget);

      await tester.ensureVisible(editBtn);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Check sheet opened
      expect(find.text('Personal Details'), findsOneWidget);
      expect(find.text('Institutional Records (Locked)'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Verify locked administrative fields
      expect(find.text('Admin Only'), findsOneWidget);

      // Update Full Name
      final nameField = find.widgetWithText(TextFormField, 'Jane Doe');
      expect(nameField, findsOneWidget);
      await tester.enterText(nameField, 'Jane Smith');

      // Tap Save Changes
      final saveBtn = find.text('Save Changes');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(mockStudent.updateProfileDetailsCalled, isTrue);
      expect(mockStudent.updatedFullName, 'Jane Smith');
    });

    testWidgets('Opens confirmation dialog when Sign Out button is tapped', (tester) async {
      final summary = StudentSummaryModel(
        studentId: 10,
        fullName: 'Jane Doe',
        registerNumber: '23CY050',
        isActive: true,
        total: 0,
        present: 0,
        absent: 0,
        od: 0,
        percentage: 0.0,
        calculationMode: 'RECORD_BASED',
        attendanceStatus: 'OK',
        minimumRequired: 75.0,
        belowMinimum: false,
      );

      final mockAuth = MockAuthServiceForProfile();
      final mockStudent = MockStudentServiceForProfile(summary: summary);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
            ChangeNotifierProvider<StudentService>.value(value: mockStudent),
          ],
          child: const MaterialApp(
            home: Scaffold(body: StudentProfileScreen()),
          ),
        ),
      );

      // Ensure Sign Out button is visible and tap it
      await tester.ensureVisible(find.text('Sign Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Sign Out'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel closes dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Sign Out'), findsNothing);
      expect(mockAuth.logoutCalled, false);
    });
  });

  group('Faculty Profile Tests', () {
    testWidgets('Renders all faculty profile details correctly', (tester) async {
      final user = UserModel(
        id: 5,
        username: 'FAC_CS_101',
        email: 'faculty.cs@college.edu',
        role: 'FACULTY',
        isActive: true,
        fullName: 'Dr. Alan Turing',
      );

      final mockAuth = MockAuthServiceForProfile(user: user);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: mockAuth,
          child: const MaterialApp(
            home: Scaffold(body: FacultyProfileScreen()),
          ),
        ),
      );

      expect(find.text('Dr. Alan Turing'), findsNWidgets(2)); // Header + Details tile
      expect(find.text('Identifier: FAC_CS_101'), findsOneWidget);
      expect(find.text('FAC_CS_101'), findsOneWidget);
      expect(find.text('faculty.cs@college.edu'), findsOneWidget);
      expect(find.text('FACULTY'), findsNWidgets(2));
      expect(find.text('Active Faculty Member'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });
  });

  group('Change Password Dialog Tests', () {
    testWidgets('Validates required fields, min length, same password, and mismatch', (tester) async {
      final mockAuth = MockAuthServiceForProfile();

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: mockAuth,
          child: const MaterialApp(
            home: Scaffold(body: ChangePasswordDialog()),
          ),
        ),
      );

      // 1. Empty submit
      await tester.tap(find.text('Update Password'));
      await tester.pump();

      expect(find.text('Enter current password'), findsOneWidget);
      expect(find.text('Enter new password'), findsOneWidget);
      expect(find.text('Confirm your new password'), findsOneWidget);

      // 2. Short new password (< 8 chars)
      await tester.enterText(find.byType(TextFormField).at(0), 'oldpass123');
      await tester.enterText(find.byType(TextFormField).at(1), '1234567');
      await tester.enterText(find.byType(TextFormField).at(2), '1234567');
      await tester.tap(find.text('Update Password'));
      await tester.pump();

      expect(find.text('Password must be at least 8 characters'), findsOneWidget);

      // 3. New password same as current password
      await tester.enterText(find.byType(TextFormField).at(0), 'secret123');
      await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
      await tester.enterText(find.byType(TextFormField).at(2), 'secret123');
      await tester.tap(find.text('Update Password'));
      await tester.pump();

      expect(find.text('New password cannot be same as current password'), findsOneWidget);

      // 4. Password mismatch
      await tester.enterText(find.byType(TextFormField).at(0), 'secret123');
      await tester.enterText(find.byType(TextFormField).at(1), 'newsecret123');
      await tester.enterText(find.byType(TextFormField).at(2), 'mismatch456');
      await tester.tap(find.text('Update Password'));
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);

      // 5. Valid submit
      await tester.enterText(find.byType(TextFormField).at(0), 'secret123');
      await tester.enterText(find.byType(TextFormField).at(1), 'newsecret123');
      await tester.enterText(find.byType(TextFormField).at(2), 'newsecret123');
      await tester.tap(find.text('Update Password'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(mockAuth.changePasswordCalled, true);
      expect(mockAuth.lastCurrentPassword, 'secret123');
      expect(mockAuth.lastNewPassword, 'newsecret123');
    });

    testWidgets('Renders mandatory mode correctly without close button', (tester) async {
      final mockAuth = MockAuthServiceForProfile();

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: mockAuth,
          child: const MaterialApp(
            home: Scaffold(body: ChangePasswordDialog(isMandatory: true)),
          ),
        ),
      );

      expect(find.text('Mandatory Password Update'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('Password visibility toggles for all 3 fields', (tester) async {
      final mockAuth = MockAuthServiceForProfile();

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: mockAuth,
          child: const MaterialApp(
            home: Scaffold(body: ChangePasswordDialog()),
          ),
        ),
      );

      final visibilityButtons = find.byIcon(Icons.visibility);
      expect(visibilityButtons, findsNWidgets(3));

      // Tap first visibility button
      await tester.tap(visibilityButtons.first);
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsNWidgets(2));
    });
  });
}
