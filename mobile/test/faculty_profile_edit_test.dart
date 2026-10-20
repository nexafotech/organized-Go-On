import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/core/theme/theme_service.dart';
import 'package:attendance_marker_mobile/models/user_model.dart';
import 'package:attendance_marker_mobile/services/auth_service.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_profile_screen.dart';
import 'package:attendance_marker_mobile/faculty/widgets/faculty_edit_profile_sheet.dart';

class MockAuthForFacultyProfile extends ChangeNotifier implements AuthService {
  UserModel _user;
  bool _isLoading = false;
  String? _errorMessage;

  MockAuthForFacultyProfile({required UserModel user}) : _user = user;

  @override
  UserModel? get currentUser => _user;
  @override
  bool get isAuthenticated => true;
  @override
  bool get isLoading => _isLoading;
  @override
  String? get errorMessage => _errorMessage;

  bool updateFacultyProfileCalled = false;
  String? lastUpdatedName;
  String? lastUpdatedEmail;
  String? lastUpdatedPhone;
  String? lastUpdatedAvatarId;

  @override
  Future<bool> updateFacultyProfile({
    String? fullName,
    String? email,
    String? phone,
    String? avatarId,
  }) async {
    updateFacultyProfileCalled = true;
    lastUpdatedName = fullName;
    lastUpdatedEmail = email;
    lastUpdatedPhone = phone;
    lastUpdatedAvatarId = avatarId;

    _user = _user.copyWith(
      fullName: fullName ?? _user.fullName,
      email: email ?? _user.email,
      phone: phone ?? _user.phone,
      avatarId: avatarId ?? _user.avatarId,
    );
    notifyListeners();
    return true;
  }

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget createTestApp({
  required MockAuthForFacultyProfile authService,
  ThemeMode mode = ThemeMode.light,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthService>.value(value: authService),
      ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: const Scaffold(
        body: FacultyProfileScreen(),
      ),
    ),
  );
}

void main() {
  final sampleFaculty = UserModel(
    id: 101,
    username: 'FAC_CS_402',
    employeeId: 'EMP-CS-402',
    fullName: 'Prof. Rajesh Kumar',
    email: 'rajesh.kumar@go-on.edu',
    phone: '+91 98765 43210',
    role: 'FACULTY',
    department: 'Computer Science and Engineering',
    isActive: true,
    isClassAdvisor: true,
    advisedClassId: 2,
    advisedClassName: 'CSE-3A',
    avatarId: 'academic_male_prof',
  );

  group('go-On Faculty Profile Screen & Edit Profile Tests', () {
    testWidgets('1. Verifies Edit Profile action buttons and tiles on Samsung Galaxy S24', (tester) async {
      // Samsung Galaxy S24 standard viewport: 412 x 915 logical pixels
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(() => tester.view.resetPhysicalSize());

      final auth = MockAuthForFacultyProfile(user: sampleFaculty);
      await tester.pumpWidget(createTestApp(authService: auth));
      await tester.pumpAndSettle();

      // Verify Hero card header elements
      expect(find.text('Prof. Rajesh Kumar'), findsNWidgets(2));
      expect(find.text('Identifier: FAC_CS_402'), findsOneWidget);
      expect(find.text('Active Faculty Member'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget); // Pill button in hero card

      // Verify Account Details elements
      expect(find.text('Account Details'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget); // Edit text button in Account Details header
      expect(find.text('EMP-CS-402'), findsOneWidget); // Employee ID
      expect(find.text('rajesh.kumar@go-on.edu'), findsOneWidget); // Email
      expect(find.text('+91 98765 43210'), findsOneWidget); // Contact Phone
      expect(find.text('Computer Science and Engineering'), findsOneWidget); // Department
      expect(find.text('Class Advisor (CSE-3A)'), findsOneWidget); // Class advisor assignment

      // Scroll down to check Account Actions
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Account Actions'), findsOneWidget);
      expect(find.text('Edit Profile Details'), findsOneWidget); // Full width button in Account Actions
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('2. Tapping Edit Profile opens FacultyEditProfileSheet with pre-filled and locked fields', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(() => tester.view.resetPhysicalSize());

      final auth = MockAuthForFacultyProfile(user: sampleFaculty);
      await tester.pumpWidget(createTestApp(authService: auth));
      await tester.pumpAndSettle();

      // Tap the "Edit Profile" pill button in the hero card
      final editPill = find.text('Edit Profile');
      expect(editPill, findsOneWidget);
      await tester.tap(editPill);
      await tester.pumpAndSettle();

      // Verify bottom sheet is open
      expect(find.byType(FacultyEditProfileSheet), findsOneWidget);
      expect(find.text('Edit Faculty Profile'), findsOneWidget);
      expect(find.text('Update personal contact details & avatar'), findsOneWidget);
      expect(find.text('Change Avatar'), findsOneWidget);

      // Verify pre-filled personal text fields
      expect(find.widgetWithText(TextFormField, 'Prof. Rajesh Kumar'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'rajesh.kumar@go-on.edu'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '+91 98765 43210'), findsOneWidget);

      // Verify locked institutional records section inside bottom sheet
      expect(find.descendant(of: find.byType(FacultyEditProfileSheet), matching: find.text('Institutional Records (Locked)')), findsOneWidget);
      expect(find.descendant(of: find.byType(FacultyEditProfileSheet), matching: find.text('Admin Only')), findsOneWidget);
      expect(find.descendant(of: find.byType(FacultyEditProfileSheet), matching: find.text('EMP-CS-402')), findsOneWidget);
      expect(find.descendant(of: find.byType(FacultyEditProfileSheet), matching: find.text('Computer Science and Engineering')), findsOneWidget);
      expect(find.descendant(of: find.byType(FacultyEditProfileSheet), matching: find.text('Class Advisor (CSE-3A)')), findsOneWidget);
      expect(find.descendant(of: find.byType(FacultyEditProfileSheet), matching: find.text('Active')), findsOneWidget);

      // Verify action buttons
      expect(find.descendant(of: find.byType(FacultyEditProfileSheet), matching: find.text('Cancel')), findsOneWidget);
      expect(find.descendant(of: find.byType(FacultyEditProfileSheet), matching: find.text('Save Changes')), findsOneWidget);
    });

    testWidgets('3. Form validation triggers correctly on invalid input', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(() => tester.view.resetPhysicalSize());

      final auth = MockAuthForFacultyProfile(user: sampleFaculty);
      await tester.pumpWidget(createTestApp(authService: auth));
      await tester.pumpAndSettle();

      // Tap Edit button in Account Details header
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      // Clear the name field
      final nameField = find.widgetWithText(TextFormField, 'Prof. Rajesh Kumar');
      await tester.enterText(nameField, '');

      // Enter an invalid email
      final emailField = find.widgetWithText(TextFormField, 'rajesh.kumar@go-on.edu');
      await tester.enterText(emailField, 'not-an-email');

      // Enter invalid phone
      final phoneField = find.widgetWithText(TextFormField, '+91 98765 43210');
      await tester.enterText(phoneField, '123');

      // Scroll to and tap Save Changes
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Validation errors should appear
      expect(find.text('Full name cannot be empty'), findsOneWidget);
      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(find.text('Please enter a valid phone number (7 to 15 digits)'), findsOneWidget);

      // Ensure service was NOT called
      expect(auth.updateFacultyProfileCalled, isFalse);
    });

    testWidgets('4. Successful profile update calls AuthService and displays confirmation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(() => tester.view.resetPhysicalSize());

      final auth = MockAuthForFacultyProfile(user: sampleFaculty);
      await tester.pumpWidget(createTestApp(authService: auth));
      await tester.pumpAndSettle();

      // Open sheet via "Edit" button
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      // Enter new name and phone
      final nameField = find.widgetWithText(TextFormField, 'Prof. Rajesh Kumar');
      await tester.enterText(nameField, 'Dr. Rajesh Kumar Ph.D.');

      final phoneField = find.widgetWithText(TextFormField, '+91 98765 43210');
      await tester.enterText(phoneField, '+91 99887 76655');

      // Scroll to and tap Save Changes
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Verify service was called with updated details
      expect(auth.updateFacultyProfileCalled, isTrue);
      expect(auth.lastUpdatedName, 'Dr. Rajesh Kumar Ph.D.');
      expect(auth.lastUpdatedPhone, '+91 99887 76655');

      // Verify sheet popped and snackbar confirmation showed
      expect(find.byType(FacultyEditProfileSheet), findsNothing);
      expect(find.text('Profile details updated successfully!'), findsOneWidget);

      // Verify dashboard hero card updated with new name
      expect(find.text('Dr. Rajesh Kumar Ph.D.'), findsNWidgets(2));
    });

    testWidgets('5. Renders cleanly in Obsidian Dark theme', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(() => tester.view.resetPhysicalSize());

      final auth = MockAuthForFacultyProfile(user: sampleFaculty);
      await tester.pumpWidget(createTestApp(authService: auth, mode: ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(find.text('Prof. Rajesh Kumar'), findsNWidgets(2));
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Account Details'), findsOneWidget);
    });
  });
}
